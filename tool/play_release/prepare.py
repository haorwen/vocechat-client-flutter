"""Prepare CI-only signing/config files without printing secret values."""
import base64
import json
import os
from pathlib import Path
import re

PACKAGE = "com.vocechat.vocechat_client"
REQUIRED = (
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
    "GOOGLE_SERVICES_JSON_BASE64",
    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
)


def decode(name, value):
    try:
        return base64.b64decode("".join(value.split()), validate=True)
    except (ValueError, TypeError):
        raise ValueError(f"{name} must contain valid base64") from None


def properties_value(value):
    # Java Properties.load(Reader) still interprets escapes and whitespace.
    return "".join(
        "\\" + char if char in "\\ =:#!" else
        "\\n" if char == "\n" else "\\r" if char == "\r" else
        "\\t" if char == "\t" else char
        for char in value
    )


def version_code(base, run, attempt):
    try:
        base, run, attempt = int(base), int(run), int(attempt)
    except ValueError:
        raise ValueError("Version base, run number and attempt must be integers") from None
    if base < 0 or run < 1 or not 1 <= attempt <= 99:
        raise ValueError("Invalid version base/run; run attempt must be 1..99")
    code = base + run * 100 + attempt
    if code > 2_100_000_000:
        raise ValueError("Generated versionCode exceeds Google Play's limit")
    return code


def prepare(root, temp, env):
    missing = [name for name in REQUIRED if not env.get(name, "").strip()]
    if missing:
        raise ValueError("Missing GitHub Actions secrets: " + ", ".join(missing))
    firebase_bytes = decode("GOOGLE_SERVICES_JSON_BASE64", env["GOOGLE_SERVICES_JSON_BASE64"])
    try:
        firebase = json.loads(firebase_bytes)
        account = json.loads(env["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"])
    except (ValueError, UnicodeError):
        raise ValueError("Firebase config or Play service account is not valid JSON") from None
    if not isinstance(firebase, dict) or not isinstance(account, dict):
        raise ValueError("Firebase config and Play service account must be JSON objects")
    packages = [
        client.get("client_info", {}).get("android_client_info", {}).get("package_name")
        for client in firebase.get("client", [])
    ]
    if PACKAGE not in packages:
        raise ValueError(f"Firebase config must include Android package {PACKAGE}")
    if account.get("type") != "service_account" or not account.get("client_email") or not account.get("private_key"):
        raise ValueError("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON must be a service account key JSON")
    match = re.search(r"^version:\s*([^\s+]+)\+\d+\s*$", (root / "pubspec.yaml").read_text(), re.M)
    if not match:
        raise ValueError("pubspec.yaml needs version: name+number")
    code = version_code(env.get("PLAY_VERSION_CODE_BASE") or "100000", env["GITHUB_RUN_NUMBER"], env["GITHUB_RUN_ATTEMPT"])
    keystore = decode("ANDROID_KEYSTORE_BASE64", env["ANDROID_KEYSTORE_BASE64"])
    if not keystore:
        raise ValueError("Android upload keystore is empty")
    files = {
        temp / "play-upload.keystore": keystore,
        root / "android/app/google-services.json": firebase_bytes,
        root / "android/key.properties": "\n".join(
            f"{key}={properties_value(value)}" for key, value in {
                "storeFile": str(temp / "play-upload.keystore"),
                "storePassword": env["ANDROID_KEYSTORE_PASSWORD"],
                "keyAlias": env["ANDROID_KEY_ALIAS"],
                "keyPassword": env["ANDROID_KEY_PASSWORD"],
            }.items()
        ).encode("utf-8") + b"\n",
    }
    if any(path.exists() for path in files):
        raise ValueError("Refusing to overwrite existing signing/Firebase files; run on a clean CI checkout")
    for path, content in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("xb") as stream:
            stream.write(content)
        path.chmod(0o600)
    return match[1], code


if __name__ == "__main__":
    try:
        version, code = prepare(Path.cwd(), Path(os.environ["RUNNER_TEMP"]), os.environ)
    except (ValueError, KeyError) as error:
        raise SystemExit(str(error)) from None
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write(f"version_name={version}\nversion_code={code}\n")
    print(f"Prepared Play internal release {version} ({code})")
