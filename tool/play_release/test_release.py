import base64
import json
from pathlib import Path
import tempfile
import unittest

from prepare import prepare, properties_value, version_code
from verify_manifest import verify, FORBIDDEN_PERMISSIONS


class PreparationTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name) / 'repo'
        self.root.mkdir()
        self.temp = Path(self.directory.name) / 'runner'
        self.temp.mkdir()
        (self.root / 'pubspec.yaml').write_text('version: 0.3.25+25\n')
        self.env = {
            'ANDROID_KEYSTORE_BASE64': base64.b64encode(b'fake-keystore').decode(),
            'ANDROID_KEYSTORE_PASSWORD': ' leading\\password:=#!',
            'ANDROID_KEY_ALIAS': 'upload',
            'ANDROID_KEY_PASSWORD': 'secret',
            'GOOGLE_SERVICES_JSON_BASE64': base64.b64encode(json.dumps({
                'client': [{'client_info': {'android_client_info': {
                    'package_name': 'com.vocechat.vocechat_client'}}}]
            }).encode()).decode(),
            'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON': json.dumps({
                'type': 'service_account', 'client_email': 'ci@example.invalid',
                'private_key': 'fake-private-key'}),
            'GITHUB_RUN_NUMBER': '7', 'GITHUB_RUN_ATTEMPT': '1',
        }

    def test_writes_private_files_and_does_not_change_pubspec(self):
        self.assertEqual(prepare(self.root, self.temp, self.env), ('0.3.25', 100701))
        properties = self.root / 'android/key.properties'
        self.assertEqual(properties.stat().st_mode & 0o777, 0o600)
        self.assertIn('storePassword=\\ leading\\\\password\\:\\=\\#\\!', properties.read_text())
        self.assertEqual((self.temp / 'play-upload.keystore').read_bytes(), b'fake-keystore')
        self.assertEqual((self.root / 'pubspec.yaml').read_text(), 'version: 0.3.25+25\n')
        with self.assertRaisesRegex(ValueError, 'overwrite'):
            prepare(self.root, self.temp, self.env)

    def test_missing_secrets_fail_without_writing_credentials(self):
        self.env.pop('ANDROID_KEY_PASSWORD')
        with self.assertRaisesRegex(ValueError, 'ANDROID_KEY_PASSWORD'):
            prepare(self.root, self.temp, self.env)
        self.assertFalse((self.root / 'android/key.properties').exists())

    def test_invalid_base64_does_not_expose_secret(self):
        self.env['ANDROID_KEYSTORE_BASE64'] = 'not-valid!secret'
        with self.assertRaisesRegex(ValueError, '^ANDROID_KEYSTORE_BASE64 must contain valid base64$'):
            prepare(self.root, self.temp, self.env)

    def test_rejects_wrong_firebase_app(self):
        self.env['GOOGLE_SERVICES_JSON_BASE64'] = base64.b64encode(b'{"client": []}').decode()
        with self.assertRaisesRegex(ValueError, 'Firebase config must include'):
            prepare(self.root, self.temp, self.env)

    def test_rejects_non_service_account_json(self):
        self.env['GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'] = '{}'
        with self.assertRaisesRegex(ValueError, 'service account key'):
            prepare(self.root, self.temp, self.env)

    def test_version_codes_increase_for_new_runs_and_retries(self):
        self.assertLess(version_code(100000, 7, 1), version_code(100000, 7, 2))
        self.assertLess(version_code(100000, 7, 99), version_code(100000, 8, 1))
        for values in [(-1, 1, 1), (0, 0, 1), (0, 1, 100), (2100000000, 1, 1)]:
            with self.subTest(values=values), self.assertRaises(ValueError):
                version_code(*values)

    def test_properties_escape_newlines_and_backslashes(self):
        self.assertEqual(properties_value('a\\b\nc\rd\te'), 'a\\\\b\\nc\\rd\\te')


MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.vocechat.vocechat_client" android:versionCode="100701">
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <application>
        <meta-data android:name="chat.voce.distribution" android:value="play" />
        <service android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService" />
    </application>
</manifest>'''


class ManifestTest(unittest.TestCase):
    def test_accepts_play_with_fcm(self):
        verify(MANIFEST, 100701)

    def test_rejects_every_excluded_permission(self):
        for permission in FORBIDDEN_PERMISSIONS:
            with self.subTest(permission=permission), self.assertRaisesRegex(ValueError, 'excluded permissions'):
                verify(MANIFEST.replace('<application>', f'<uses-permission android:name="{permission}"/><application>'), 100701)

    def test_rejects_background_service_and_updater_provider(self):
        for element in [
            '<service android:name=".BackgroundMessageService"/>',
            '<service android:name="com.vocechat.vocechat_client.VoceFirebaseMessagingService"/>',
            '<provider android:name="androidx.core.content.FileProvider" android:authorities="com.vocechat.vocechat_client.update-files"/>',
        ]:
            with self.subTest(element=element), self.assertRaises(ValueError):
                verify(MANIFEST.replace('</application>', element + '</application>'), 100701)

    def test_rejects_missing_fcm_or_play_marker(self):
        for original, replacement in [('FlutterFirebaseMessagingService', 'OtherService'),
                                      ('android:value="play"', 'android:value="standalone"'),
                                      ('POST_NOTIFICATIONS', 'OTHER_PERMISSION')]:
            with self.subTest(original=original), self.assertRaises(ValueError):
                verify(MANIFEST.replace(original, replacement), 100701)

    def test_rejects_wrong_package_version_or_debug_build(self):
        for xml in [MANIFEST.replace('package="com.vocechat.vocechat_client"', 'package="other"'),
                    MANIFEST.replace('100701', '25'),
                    MANIFEST.replace('<application>', '<application android:debuggable="true">')]:
            with self.subTest(xml=xml), self.assertRaises(ValueError):
                verify(xml, 100701)


if __name__ == '__main__':
    unittest.main()
