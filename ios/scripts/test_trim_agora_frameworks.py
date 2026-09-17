import contextlib
import io
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import trim_agora_frameworks as trim


class TrimAgoraTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / "Runner.app"
        self.bundle(self.app, "Runner")
        for name in trim.REQUIRED:
            self.bundle(self.app / "Frameworks" / f"{name}.framework", name)
        self.optional = self.app / "Frameworks/AgoraLipSyncExtension.framework"
        self.bundle(self.optional, "AgoraLipSyncExtension")

    @staticmethod
    def bundle(path, name):
        path.mkdir(parents=True)
        (path / name).write_bytes(b"binary fixture")
        with (path / "Info.plist").open("wb") as stream:
            plistlib.dump({"CFBundleExecutable": name}, stream)

    def run_inspection(self, output="", **kwargs):
        result = subprocess.CompletedProcess([], 0, stdout=output)
        with patch.object(trim.subprocess, "run", return_value=result), contextlib.redirect_stdout(io.StringIO()):
            trim.inspect_app(self.app, **kwargs)

    def test_weak_dependency_can_be_trimmed_and_verified(self):
        self.run_inspection(
            " cmd LC_LOAD_WEAK_DYLIB\n name @rpath/AgoraLipSyncExtension.framework/AgoraLipSyncExtension (offset 24)\n",
            trim=True,
        )
        self.assertFalse(self.optional.exists())
        for name in trim.REQUIRED:
            self.assertTrue((self.app / f"Frameworks/{name}.framework/{name}").exists())
        self.run_inspection(verify=True)

    def test_strong_dependency_stops_before_any_deletion(self):
        for command in trim.STRONG_LOAD_COMMANDS:
            with self.subTest(command=command), self.assertRaisesRegex(ValueError, "strongly depends"):
                self.run_inspection(
                    f" cmd {command}\n name @rpath/AgoraLipSyncExtension.framework/AgoraLipSyncExtension (offset 24)\n",
                    trim=True,
                )
            self.assertTrue(self.optional.exists())

    def test_verify_never_deletes_remaining_optional_framework(self):
        with self.assertRaisesRegex(ValueError, "still embedded"):
            self.run_inspection(verify=True)
        self.assertTrue(self.optional.exists())

    def test_missing_audio_processing_stops_trim(self):
        import shutil
        shutil.rmtree(self.app / "Frameworks/AgoraAiEchoCancellationExtension.framework")
        with self.assertRaisesRegex(ValueError, "Required Agora frameworks missing"):
            self.run_inspection(trim=True)
        self.assertTrue(self.optional.exists())

    def test_otool_failure_does_not_delete_frameworks(self):
        with patch.object(trim.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "otool")):
            with self.assertRaises(subprocess.CalledProcessError), contextlib.redirect_stdout(io.StringIO()):
                trim.inspect_app(self.app, trim=True)
        self.assertTrue(self.optional.exists())

    def test_app_extension_requires_further_audit(self):
        (self.app / "PlugIns/Capture.appex").mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, "App extensions found"):
            self.run_inspection(trim=True)
        self.assertTrue(self.optional.exists())


if __name__ == "__main__":
    unittest.main()
