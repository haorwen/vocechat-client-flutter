"""Validate bundletool's manifest dump from the actual release AAB."""
import sys
import xml.etree.ElementTree as ET

ANDROID = "{http://schemas.android.com/apk/res/android}"
PACKAGE = "com.vocechat.vocechat_client"
FORBIDDEN_PERMISSIONS = {
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
    "android.permission.FOREGROUND_SERVICE_MICROPHONE",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
    "android.permission.REQUEST_INSTALL_PACKAGES",
}


def verify(xml, expected_version_code):
    root = ET.fromstring(xml)
    if root.get("package") != PACKAGE:
        raise ValueError("Unexpected AAB package name")
    if root.get(ANDROID + "versionCode") != str(expected_version_code):
        raise ValueError("AAB versionCode does not match this CI release")
    permissions = {node.get(ANDROID + "name") for node in root if node.tag.startswith("uses-permission")}
    forbidden = permissions & FORBIDDEN_PERMISSIONS
    if forbidden:
        raise ValueError("Play AAB contains excluded permissions: " + ", ".join(sorted(forbidden)))
    if "android.permission.POST_NOTIFICATIONS" not in permissions:
        raise ValueError("Play AAB is missing notification permission")
    app = root.find("application")
    if app is None:
        raise ValueError("AAB manifest is missing application")
    if app.get(ANDROID + "debuggable") == "true":
        raise ValueError("Play AAB must not be debuggable")
    services = {node.get(ANDROID + "name", "") for node in app.findall("service")}
    if any(name.endswith((".BackgroundMessageService", ".VoceFirebaseMessagingService")) for name in services):
        raise ValueError("Play AAB contains a removed background messaging service")
    if "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService" not in services:
        raise ValueError("Play AAB is missing the FlutterFire messaging service")
    for provider in app.findall("provider"):
        if f"{PACKAGE}.update-files" in provider.get(ANDROID + "authorities", "").split(";"):
            raise ValueError("Play AAB contains the APK update FileProvider")
    metadata = {node.get(ANDROID + "name"): node.get(ANDROID + "value") for node in app.findall("meta-data")}
    if metadata.get("chat.voce.distribution") != "play":
        raise ValueError("AAB was not built with the play flavor")


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8") as source:
        verify(source.read(), sys.argv[2])
    print("Verified Play AAB: FCM present; background messaging and APK installation excluded")
