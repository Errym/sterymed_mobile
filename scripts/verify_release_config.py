"""Read-only build preflight; never invokes Flutter, Gradle, a network or a key tool."""

from __future__ import annotations

import argparse
import ipaddress
import json
import re
import shutil
import sys
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]


def version(value: str) -> tuple[int, int, int]:
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", value)
    if not match:
        raise ValueError("No numeric SDK version found")
    return tuple(int(part) for part in match.groups())


def sdk_minimums(text: str, section: str) -> dict[str, tuple[int, int, int]]:
    # These two repository files use simple indented scalar SDK constraints.
    match = re.search(rf"(?m)^{section}:\n((?:[ \t].*\n|\n)+)", text + "\n")
    if not match:
        raise ValueError(f"Missing {section} SDK section")
    found = dict(re.findall(r"(?m)^  (sdk|dart|flutter):\s*[\"']?([^\n]+)", match[1]))
    return {"dart" if key == "sdk" else key: version(value) for key, value in found.items()}


def baseline_issues(root: Path, flutter_sdk: Path | None) -> list[str]:
    issues = []
    declared = sdk_minimums((root / "pubspec.yaml").read_text(encoding="utf-8"), "environment")
    locked = sdk_minimums((root / "pubspec.lock").read_text(encoding="utf-8"), "sdks")
    for sdk in ("dart", "flutter"):
        if sdk not in declared or sdk not in locked:
            issues.append(f"Missing {sdk} SDK constraint")
        elif declared[sdk] < locked[sdk]:
            issues.append(f"pubspec.yaml {sdk} minimum is below pubspec.lock")

    pins = []
    for name in ("mobile-analyze.yml", "mobile-test.yml", "mobile-build-android.yml", "mobile-build-ios.yml"):
        text = (root / ".github/workflows" / name).read_text(encoding="utf-8")
        match = re.search(r"flutter-version:\s*[\"']([\d.]+)[\"']", text)
        if not match:
            issues.append(f"{name} has no explicit Flutter pin")
        else:
            pins.append(version(match[1]))
    if len(set(pins)) > 1:
        issues.append("CI Flutter pins disagree")
    if pins and "flutter" in declared and min(pins) < declared["flutter"]:
        issues.append("CI Flutter pin is below the declared minimum")
    if flutter_sdk:
        metadata = json.loads((flutter_sdk / "bin/cache/flutter.version.json").read_text(encoding="utf-8"))
        installed = {"flutter": version(metadata["frameworkVersion"]), "dart": version(metadata["dartSdkVersion"])}
        for sdk, minimum in declared.items():
            if sdk in installed and installed[sdk] < minimum:
                issues.append(f"Installed {sdk} SDK is below the declared minimum")
        if pins and installed["flutter"] != pins[0]:
            issues.append("Installed Flutter differs from the CI pin; use the pinned SDK for baseline checks")
    return issues


def signing_issues(root: Path) -> list[str]:
    path = root / "android/key.properties"
    if not path.is_file():
        return ["Android signing: android/key.properties is missing (see its .example)"]
    # Check presence without exposing credentials. The template uses simple key=value lines.
    values = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if line.strip() and not line.lstrip().startswith(("#", "!")) and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    required = ("storeFile", "storePassword", "keyAlias", "keyPassword")
    issues = [f"Android signing: {key} is blank or missing" for key in required if not values.get(key)]
    store = values.get("storeFile", "")
    if store:
        if "\\" in store:
            issues.append("Android signing: use forward slashes in storeFile, as shown in the template")
        else:
            keystore = Path(store)
            if not keystore.is_absolute():
                keystore = root / "android" / keystore
            if not keystore.is_file():
                issues.append("Android signing: storeFile does not identify an existing file")
    if values.get("keyAlias", "").casefold() == "androiddebugkey":
        issues.append("Android signing: the debug key alias cannot be used for a release candidate")
    return issues


def defines_issues(defines: dict) -> list[str]:
    issues = []
    if defines.get("ENV") != "production":
        issues.append("Release defines must explicitly set ENV=production")
    url = defines.get("API_BASE_URL", "")
    if not isinstance(url, str):
        return issues + ["API_BASE_URL must be a string"]
    try:
        parsed = urlsplit(url)
        host = parsed.hostname or ""
        if parsed.scheme != "https" or not host or parsed.username or parsed.password or parsed.query or parsed.fragment:
            issues.append("API_BASE_URL must be HTTPS without credentials, query or fragment")
        if host in {"localhost", "minio"} or "." not in host or host.endswith((".localhost", ".local", ".invalid", ".test", ".example", ".example.com", ".example.org", ".example.net")) or host in {"example.com", "example.org", "example.net"}:
            issues.append("API_BASE_URL is a local or placeholder host")
        try:
            address = ipaddress.ip_address(host)
            if address.is_loopback or address.is_unspecified or address.is_link_local or host == "10.0.2.2":
                issues.append("API_BASE_URL is a loopback, link-local or emulator address")
        except ValueError:
            pass
        if parsed.port is not None and not 1 <= parsed.port <= 65535:
            issues.append("API_BASE_URL has an invalid port")
        if parsed.path.rstrip("/") != "/api":
            issues.append("API_BASE_URL must end at /api; repositories append /v1 routes")
    except ValueError:
        issues.append("API_BASE_URL is malformed")
    return issues


def release_issues(root: Path, defines: dict) -> list[str]:
    gradle = (root / "android/app/build.gradle.kts").read_text(encoding="utf-8")
    match = re.search(r'applicationId\s*=\s*"([^"]+)"', gradle)
    issues = []
    if not match or match[1].startswith("com.example."):
        issues.append("Android applicationId still needs an owner-approved identifier")
    if 'signingConfigs.getByName("debug")' in gradle:
        issues.append("Android release configuration still references debug signing")
    return issues + signing_issues(root) + defines_issues(defines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("baseline", "android-release"), default="baseline")
    parser.add_argument("--flutter-sdk", type=Path, help="SDK root; otherwise discovered from PATH metadata")
    parser.add_argument("--defines", type=Path, help="Same JSON file passed to Flutter --dart-define-from-file")
    args = parser.parse_args(argv)
    flutter_sdk = args.flutter_sdk
    if not flutter_sdk:
        executable = shutil.which("flutter") or shutil.which("flutter.bat")
        if executable:
            flutter_sdk = Path(executable).resolve().parents[1]
    try:
        issues = baseline_issues(ROOT, flutter_sdk)
        if args.mode == "android-release":
            if not args.defines:
                issues.append("Android release mode requires --defines with explicit build values")
                defines = {}
            else:
                defines = json.loads(args.defines.read_text(encoding="utf-8"))
                if not isinstance(defines, dict):
                    raise ValueError("Release defines must be a JSON object")
            issues.extend(release_issues(ROOT, defines))
    except (OSError, ValueError, KeyError):
        # Never echo malformed configuration or signing-file contents.
        print("FAIL: Required metadata is missing or malformed; check input paths and JSON/SDK sections.")
        return 2
    for issue in issues:
        print(f"FAIL: {issue}")
    if issues:
        return 1
    print(f"PASS: {args.mode} configuration checks")
    if not flutter_sdk:
        print("UNVERIFIED: Local Flutter SDK not found; pass --flutter-sdk to check it")
    print("UNVERIFIED: compilation, signing-key validity/ownership, network reachability and store acceptance")
    return 0


if __name__ == "__main__":
    sys.exit(main())
