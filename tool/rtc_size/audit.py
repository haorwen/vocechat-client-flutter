#!/usr/bin/env python3
"""Report native library sizes in an APK/AAB; optionally verify Agora trimming.

Reads ZIP metadata only. Does not modify or re-sign the input artifact.
Sizes describe packaged entries, not installed size or Play download size.
"""

import argparse
from collections import defaultdict
from pathlib import Path
import sys
import zipfile


PROJECT = Path(__file__).resolve().parents[2]
EXCLUSIONS = PROJECT / "android/agora-excluded-libraries.txt"
# Minimum runtime libraries for the pinned Agora 6.5.4 Android integration.
# This is an artifact sanity check, not a replacement for device testing.
REQUIRED = {
    "libagora-rtc-sdk.so",
    "libagora_screen_capture_extension.so",
    "libAgoraRtcWrapper.so",
    "libiris_method_channel.so",
    "libiris_rendering_android.so",
    "libagora_ai_noise_suppression_extension.so",
    "libagora_ai_echo_cancellation_extension.so",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path, help="An APK or AAB file")
    parser.add_argument(
        "--verify", action="store_true",
        help="Fail if excluded libraries remain or required libraries are missing",
    )
    parser.add_argument(
        "--verify-compressed", action="store_true",
        help="For APKs, fail if any native library is not ZIP DEFLATE compressed",
    )
    args = parser.parse_args()
    if args.verify_compressed and args.artifact.suffix.lower() != ".apk":
        parser.error("--verify-compressed applies to APKs, not AAB delivery")
    excluded = {
        line.strip() for line in EXCLUSIONS.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }
    entries = defaultdict(list)
    try:
        with zipfile.ZipFile(args.artifact) as archive:
            for info in archive.infolist():
                parts = info.filename.split("/")
                # APK: lib/ABI/name.so; AAB: module/lib/ABI/name.so.
                if (len(parts) == 3 and parts[0] == "lib") or (
                    len(parts) == 4 and parts[1] == "lib"
                ):
                    if parts[-1].endswith(".so"):
                        entries[parts[-2]].append(info)
    except (OSError, zipfile.BadZipFile) as error:
        parser.exit(2, f"Cannot read artifact: {error}\n")
    if not entries:
        parser.exit(2, "No native libraries found in artifact\n")

    mib = 1024 * 1024
    print(f"Artifact: {args.artifact} ({args.artifact.stat().st_size / mib:.2f} MiB)")
    print("ABI                 Native MiB  Agora/Iris MiB  Excluded MiB  Excluded ZIP MiB")
    removable = 0
    errors = []
    for abi, libraries in sorted(entries.items()):
        names = {Path(info.filename).name for info in libraries}
        unused = [info for info in libraries if Path(info.filename).name in excluded]
        total = sum(info.file_size for info in libraries)
        agora = sum(
            info.file_size for info in libraries
            if any(word in Path(info.filename).name.lower() for word in ("agora", "iris"))
        )
        unused_size = sum(info.file_size for info in unused)
        unused_zip = sum(info.compress_size for info in unused)
        removable += unused_zip
        print(f"{abi:19} {total / mib:10.2f} {agora / mib:15.2f} "
              f"{unused_size / mib:13.2f} {unused_zip / mib:17.2f}")
        for name in sorted(names & excluded):
            errors.append(f"{abi}: excluded library remains: {name}")
        for name in sorted(REQUIRED - names):
            errors.append(f"{abi}: required library missing: {name}")
    print(f"Removable ZIP payload: {removable / mib:.2f} MiB (excluding ZIP headers/alignment)")
    if args.verify:
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print("PASS: excluded extensions absent; required RTC/screen/Iris/audio libraries present per ABI.")
    if args.verify_compressed:
        uncompressed = [
            info.filename for libraries in entries.values() for info in libraries
            if info.compress_type != zipfile.ZIP_DEFLATED
        ]
        if uncompressed:
            print("Native libraries not DEFLATE compressed:\n" + "\n".join(uncompressed), file=sys.stderr)
            return 1
        print("PASS: all packaged native libraries are DEFLATE compressed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
