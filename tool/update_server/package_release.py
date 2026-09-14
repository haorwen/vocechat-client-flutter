"""Build a source distribution ZIP using an explicit list, excluding secrets."""
import argparse
import hashlib
from pathlib import Path
import tomllib
import zipfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("../../artifacts"))
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    version = tomllib.loads((source / "pyproject.toml").read_text())["project"]["version"]
    folder = "vocechat-update-server"
    names = [
        "README.md", "pyproject.toml", "uv.lock", ".python-version", ".gitignore",
        ".dockerignore", "Dockerfile", "compose.yaml", "config.example.toml",
        "Caddyfile.example", "vocechat-update.service.example", "server.py",
        "test_server.py", "package_release.py", "vocechat_update/__init__.py",
        "vocechat_update/server.py", "vocechat_update/static/index.html",
        "vocechat_update/static/app.css", "vocechat_update/static/app.js",
    ]
    args.output.mkdir(parents=True, exist_ok=True)
    archive_path = args.output / f"{folder}-{version}.zip"
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name in names:
            archive.write(source / name, f"{folder}/{name}")
        docs = source / "android-updates.md"
        if not docs.exists():
            docs = source.parent.parent / "docs/android-updates.md"
        archive.write(docs, f"{folder}/android-updates.md")
    checksum = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    archive_path.with_suffix(".zip.sha256").write_text(f"{checksum}  {archive_path.name}\n")
    print(f"{archive_path.resolve()} ({archive_path.stat().st_size} bytes)")
    print(f"SHA256: {checksum}")


if __name__ == "__main__":
    main()
