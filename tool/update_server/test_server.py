import concurrent.futures
import http.client
import json
import sqlite3
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from server import ReleaseStore, UpdateServer
from vocechat_update.server import load_admin_token


TOKEN = "test-only-administrator-token-32-characters"


def release(code=23, **extra):
    return {"version": "0.3.23", "version_code": code, "force_update": False,
            "update_url": "https://update.voce.chat/downloads/vocechat-0.3.23.apk",
            **extra}


class UpdateServerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "releases.sqlite3"
        self.store = ReleaseStore(self.path)
        self.server = UpdateServer(("127.0.0.1", 0), self.store, TOKEN)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temp.cleanup()

    def request(self, method="GET", body=None, token=TOKEN, raw=None):
        connection = http.client.HTTPConnection(*self.server.server_address, timeout=5)
        path = "/client/android" if method == "GET" else "/admin/client/android/releases"
        headers = {"Content-Type": "application/json", "Authorization": f"Bearer {token}"}
        try:
            connection.request(method, path,
                               body=raw if raw is not None else json.dumps(body) if body is not None else None,
                               headers=headers)
            response = connection.getresponse()
            return response.status, json.loads(response.read()), response.getheader("Cache-Control")
        finally:
            connection.close()

    def test_publish_and_read_persistent_metadata_with_fresh_time(self):
        self.assertEqual(self.request()[0], 503)
        payload = release(announcement={"zh": "新版公告\n修复问题", "en": "Release notes\nBug fixes"}, future_field={"enabled": True})
        self.assertEqual(self.request("POST", payload)[0], 201)
        expected = {**payload, "last_force_version_code": 0}
        self.assertEqual(ReleaseStore(self.path).latest(), expected)
        before = time.time_ns() // 1_000_000
        status, metadata, cache = self.request()
        self.assertEqual(status, 200)
        self.assertEqual(cache, "no-store")
        self.assertGreaterEqual(metadata.pop("timestamp"), before)
        self.assertEqual(metadata, expected)

    def test_admin_auth_and_idempotency_and_downgrade(self):
        self.assertEqual(self.request("POST", release(), token="wrong")[0], 401)
        self.assertIsNone(self.store.latest())
        self.assertEqual(self.request("POST", release())[0], 201)
        self.assertEqual(self.request("POST", release())[0], 200)
        self.assertEqual(self.request("POST", release(force_update=True))[0], 409)
        self.assertEqual(self.request("POST", release(22))[0], 409)
        self.assertEqual(self.request("POST", release(24, force_update=True))[0], 201)

    def test_invalid_input_never_changes_published_release(self):
        self.store.publish(release())
        for changes in [
            {"version_code": True}, {"version_code": "24"}, {"version_code": 0},
            {"version_code": 2100000001}, {"force_update": "false"},
            {"update_url": "http://example.com/app.apk"},
            {"update_url": "https://user:pass@example.com/app.apk"},
            {"update_url": "https://example.com:wrong/app.apk"},
            {"announcement": []}, {"timestamp": 1}, {"version": ""},
            {"announcement": {"zh": "缺少英文"}},
            {"announcement": {"zh": "中文", "en": 12}},
            {"last_force_version_code": 0},
            {"extra": float("nan")},
        ]:
            with self.subTest(changes=changes):
                self.assertEqual(self.request("POST", {**release(24), **changes})[0], 400)
        self.assertEqual(self.request("POST", raw="{")[0], 400)
        self.assertEqual(self.request("POST", raw="[]")[0], 400)
        self.assertEqual(self.request("POST", raw="x" * 65537)[0], 413)
        self.assertEqual(self.store.latest(), {**release(), "last_force_version_code": 0})

    def test_optional_release_preserves_last_forced_build(self):
        self.assertEqual(self.request("POST", release())[1]["last_force_version_code"], 0)
        forced = release(24, force_update=True)
        self.assertEqual(self.request("POST", forced)[1]["last_force_version_code"], 24)
        self.assertEqual(self.request("POST", forced)[0], 200)
        self.assertEqual(self.request("POST", release(25))[1]["last_force_version_code"], 24)
        self.assertEqual(self.request()[1]["last_force_version_code"], 24)
        self.assertEqual(ReleaseStore(self.path).latest()["last_force_version_code"], 24)
        self.assertEqual(self.request("POST", release(26, force_update=True))[1]["last_force_version_code"], 26)
        self.assertEqual(self.request("POST", release(27))[1]["last_force_version_code"], 26)

    def test_existing_database_recovers_historical_forced_builds(self):
        old_path = Path(self.temp.name) / "old.sqlite3"
        with sqlite3.connect(old_path) as db:
            db.execute("CREATE TABLE releases (version_code INTEGER PRIMARY KEY, payload TEXT NOT NULL)")
            for code in [22, 23, 24]:
                db.execute("INSERT INTO releases VALUES (?, ?)",
                           (code, json.dumps(release(code, force_update=code == 23))))
        upgraded = ReleaseStore(old_path)
        self.assertEqual(upgraded.latest()["last_force_version_code"], 23)
        self.assertEqual(upgraded.get(22)["last_force_version_code"], 0)
        self.assertEqual(upgraded.get(23)["last_force_version_code"], 23)
        upgraded.publish(release(25))
        self.assertEqual(ReleaseStore(old_path).latest()["last_force_version_code"], 23)

    def test_concurrent_publications_cannot_roll_back_latest(self):
        def publish(code):
            return self.request("POST", release(code))[0]
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            statuses = list(pool.map(publish, [24, 26, 25, 27]))
        self.assertTrue(all(status in (201, 409) for status in statuses))
        self.assertEqual(self.store.latest()["version_code"], 27)

    def test_console_assets_and_private_files(self):
        for path, content_type, marker in [
            ("/", "text/html", b"release-form"),
            ("/admin/", "text/html", b"release-form"),
            ("/admin/app.css", "text/css", b"@media"),
            ("/admin/app.js", "text/javascript", b"/admin/client/android/releases"),
        ]:
            with self.subTest(path=path):
                connection = http.client.HTTPConnection(*self.server.server_address)
                try:
                    connection.request("GET", path)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 200)
                    self.assertIn(content_type, response.getheader("Content-Type"))
                    self.assertIn("frame-ancestors 'none'", response.getheader("Content-Security-Policy"))
                    body = response.read()
                    self.assertIn(marker, body)
                    self.assertNotIn(TOKEN.encode(), body)
                finally:
                    connection.close()
        for path in ["/data/admin-token.txt", "/admin/../server.py", "/admin/%2e%2e/server.py", "/.env", "/config.toml"]:
            connection = http.client.HTTPConnection(*self.server.server_address)
            try:
                connection.request("GET", path)
                response = connection.getresponse()
                self.assertEqual(response.status, 404)
                response.read()
            finally:
                connection.close()

    def test_generated_admin_token_survives_restart_and_is_private(self):
        with patch.dict("os.environ", {}, clear=True):
            token = load_admin_token(self.temp.name)
            self.assertGreaterEqual(len(token), 32)
            self.assertEqual(load_admin_token(self.temp.name), token)
            path = Path(self.temp.name) / "admin-token.txt"
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        with patch.dict("os.environ", {"UPDATE_ADMIN_TOKEN": TOKEN}):
            self.assertEqual(load_admin_token(self.temp.name), TOKEN)
        self.assertEqual(path.read_text().strip(), token)


if __name__ == "__main__":
    unittest.main()
