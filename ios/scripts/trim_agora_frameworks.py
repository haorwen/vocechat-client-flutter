#!/usr/bin/env python3
"""Inspect or trim a built iOS .app before app signing (never edit a signed IPA).

CocoaPods installs the --trim build phase after all framework embed phases.
Strong Mach-O dependencies on excluded frameworks fail the build before deletion.
"""

import argparse
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys


EXCLUSIONS = Path(__file__).resolve().parents[1] / "agora-excluded-frameworks.txt"
REQUIRED = {
    "AgoraRtcKit", "AgoraRtcWrapper", "AgoraReplayKitExtension",
    "AgoraAiNoiseSuppressionExtension", "AgoraAiEchoCancellationExtension",
}
STRONG_LOAD_COMMANDS = {
    "LC_LOAD_DYLIB", "LC_REEXPORT_DYLIB", "LC_LOAD_UPWARD_DYLIB",
    "LC_LAZY_LOAD_DYLIB",
}


def excluded_frameworks():
    names = {
        line.strip() for line in EXCLUSIONS.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }
    if names & REQUIRED or any(not re.fullmatch(r"Agora\w+Extension", name) for name in names):
        raise ValueError("Invalid optional framework exclusion list")
    return names


def bundle_binary(bundle):
    with (bundle / "Info.plist").open("rb") as stream:
        name = plistlib.load(stream)["CFBundleExecutable"]
    if not isinstance(name, str) or Path(name).name != name:
        raise ValueError(f"Invalid executable name in {bundle}")
    binary = bundle / name
    if not binary.is_file():
        raise ValueError(f"Missing bundle executable: {binary}")
    return binary


def strong_dependencies(output):
    command = None
    for line in output.splitlines():
        fields = line.strip().split()
        if fields[:1] == ["cmd"] and len(fields) == 2:
            command = fields[1]
        elif command in STRONG_LOAD_COMMANDS and fields[:1] == ["name"]:
            # Preserve spaces in the install name; otool appends an offset.
            yield line.strip()[5:].rsplit(" (offset ", 1)[0]


def check_dependencies(app, frameworks, excluded):
    binaries = [bundle_binary(app)]
    for framework in frameworks:
        if framework.stem not in excluded:
            binaries.append(bundle_binary(framework))
    errors = []
    for binary in binaries:
        result = subprocess.run(
            ["xcrun", "otool", "-l", str(binary)],
            check=True, text=True, capture_output=True,
        )
        for dependency in strong_dependencies(result.stdout):
            if any(f"{name}.framework" in Path(dependency).parts for name in excluded):
                errors.append(f"{binary.name} strongly depends on {dependency}")
    if errors:
        raise ValueError("Refusing to trim required frameworks:\n" + "\n".join(errors))


def inspect_app(app, *, trim=False, verify=False):
    if app.suffix != ".app" or not app.is_dir():
        raise ValueError(f"Expected an existing .app bundle: {app}")
    root = app / "Frameworks"
    if root.is_symlink() or not root.is_dir():
        raise ValueError(f"Expected a real Frameworks directory: {root}")
    excluded = excluded_frameworks()
    frameworks = sorted(root.glob("*.framework"))
    candidates = [path for path in frameworks if path.stem in excluded]
    size = sum(
        path.stat().st_size for framework in candidates
        for path in framework.rglob("*") if path.is_file()
    )
    print(f"Optional Agora frameworks: {len(candidates)}; unpacked size: {size / 2**20:.2f} MiB")
    if not trim and not verify:
        for path in candidates:
            print(path.name)
        return
    missing = REQUIRED - {path.stem for path in frameworks}
    if missing:
        raise ValueError("Required Agora frameworks missing: " + ", ".join(sorted(missing)))
    # This pipeline currently has no app extensions. Fail closed if that
    # changes: their executables and embedding need a separate dependency audit.
    if list(app.rglob("*.appex")):
        raise ValueError("App extensions found; extend the dependency audit before trimming")
    if any(path.is_symlink() for path in frameworks):
        raise ValueError("Framework symlinks are not supported by the iOS trim step")
    check_dependencies(app, frameworks, excluded)
    if verify and candidates:
        raise ValueError("Excluded frameworks still embedded: " + ", ".join(p.name for p in candidates))
    if trim:
        for path in candidates:
            shutil.rmtree(path)
            print(f"Removed {path.name}")
    print("PASS: optional frameworks absent; core, ReplayKit, Iris and regular audio processing retained.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--trim", action="store_true", help="Remove optional frameworks BEFORE app signing")
    mode.add_argument("--verify", action="store_true", help="Verify the built app without changing it")
    args = parser.parse_args()
    try:
        inspect_app(args.app, trim=args.trim, verify=args.verify)
    except (OSError, ValueError, KeyError, plistlib.InvalidFileException, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Agora framework check failed: {error}\n")


if __name__ == "__main__":
    main()
