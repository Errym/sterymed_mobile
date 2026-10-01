"""Configuration and process-exit regressions; no Flutter/backend is invoked."""

import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("preflight", SCRIPTS / "verify_release_config.py")
preflight = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preflight)


class ReleaseConfigTests(unittest.TestCase):
    def test_rejects_unsafe_or_ambiguous_production_urls(self):
        for url in ("http://clinic.invalid/api", "https://10.0.2.2/api", "https://localhost/api", "https://api.invalid/api", "https://api.example.com/api", "https://user:password@api.clinic.fr/api", "https://api.clinic.fr/api?token=secret", "https://api.clinic.fr/api/v1", "https://api.clinic.fr:wrong/api"):
            with self.subTest(url=url):
                self.assertTrue(preflight.defines_issues({"ENV": "production", "API_BASE_URL": url}))

    def test_requires_explicit_environment_and_api_base(self):
        self.assertTrue(preflight.defines_issues({}))
        self.assertTrue(preflight.defines_issues({"ENV": "dev", "API_BASE_URL": "https://api.clinic.fr/api"}))
        self.assertEqual([], preflight.defines_issues({"ENV": "production", "API_BASE_URL": "https://api.clinic.fr/api/"}))
        # An explicitly configured clinic VPN can use a private address; reachability is separate.
        self.assertEqual([], preflight.defines_issues({"ENV": "production", "API_BASE_URL": "https://10.42.0.8/api"}))

    def test_signing_checks_do_not_disclose_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "android").mkdir()
            (root / "android/key.properties").write_text("storeFile=missing.jks\nstorePassword=secret-one\nkeyAlias=androiddebugkey\nkeyPassword=secret-two\n", encoding="utf-8")
            issues = preflight.signing_issues(root)
            self.assertTrue(any("existing file" in issue for issue in issues))
            self.assertTrue(any("debug key" in issue for issue in issues))
            self.assertNotIn("secret-one", str(issues))
            self.assertNotIn("secret-two", str(issues))

    def test_relative_keystore_is_resolved_from_android_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "android").mkdir()
            (root / "android/upload.jks").touch()
            (root / "android/key.properties").write_text("storeFile=upload.jks\nstorePassword=fixture\nkeyAlias=upload\nkeyPassword=fixture\n", encoding="utf-8")
            self.assertEqual([], preflight.signing_issues(root))

    def test_sdk_baseline_catches_stale_minimum_and_ci_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".github/workflows").mkdir(parents=True)
            pubspec = root / "pubspec.yaml"
            pubspec.write_text('environment:\n  sdk: ">=3.12.0 <4.0.0"\n  flutter: ">=3.44.0"\n', encoding="utf-8")
            (root / "pubspec.lock").write_text('sdks:\n  dart: ">=3.12.0 <4.0.0"\n  flutter: ">=3.44.0"\n', encoding="utf-8")
            for name in ("mobile-analyze.yml", "mobile-test.yml", "mobile-build-android.yml", "mobile-build-ios.yml"):
                (root / ".github/workflows" / name).write_text('flutter-version: "3.47.2"\n', encoding="utf-8")
            self.assertEqual([], preflight.baseline_issues(root, None))
            pubspec.write_text('environment:\n  sdk: ">=3.4.0 <4.0.0"\n  flutter: ">=3.22.0"\n', encoding="utf-8")
            (root / ".github/workflows/mobile-test.yml").write_text('flutter-version: "3.44.0"\n', encoding="utf-8")
            issues = preflight.baseline_issues(root, None)
            self.assertEqual(2, sum("below pubspec.lock" in issue for issue in issues))
            self.assertIn("CI Flutter pins disagree", issues)


def available_bash():
    if os.name == "nt":
        path = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe"
        return str(path) if path.is_file() else None
    return shutil.which("bash")


@unittest.skipUnless(available_bash(), "Git Bash/Bash is needed for the runner process regressions")
class GroupedRunnerTests(unittest.TestCase):
    def run_runner(self, group_code="0", timeout_version="timeout (GNU coreutils) fixture", timeout_seconds="180"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "bin").mkdir()
            shutil.copyfile(SCRIPTS / "run_tests_win.sh", root / "scripts/run_tests_win.sh")
            # Stubs execute no Flutter or real timeout, and record every group.
            flutter = root / "bin/flutter"
            flutter.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$2" >> calls.txt\nif [[ "$2" == "test/unit/" ]]; then exit "${FIXTURE_GROUP_CODE}"; fi\nexit 0\n', encoding="utf-8", newline="\n")
            timeout = root / "bin/timeout"
            timeout.write_text('#!/usr/bin/env bash\nif [[ "$1" == "--version" ]]; then printf "%s\\n" "$FIXTURE_TIMEOUT_VERSION"; exit 0; fi\nshift 2\nexec "$@"\n', encoding="utf-8", newline="\n")
            flutter.chmod(0o755)
            timeout.chmod(0o755)
            # Set PATH inside Bash: Windows PATH separators do not match POSIX PATH.
            environment = os.environ.copy()
            environment.update(FIXTURE_GROUP_CODE=group_code, FIXTURE_TIMEOUT_VERSION=timeout_version, TEST_TIMEOUT_SECONDS=timeout_seconds, TEST_OUTPUT_LOG="build/test_output.log")
            result = subprocess.run([available_bash(), "--noprofile", "--norc", "-c", 'export PATH="$PWD/bin:$PATH"; bash scripts/run_tests_win.sh'], cwd=root, env=environment, capture_output=True, text=True, timeout=30)
            calls = (root / "calls.txt").read_text().splitlines() if (root / "calls.txt").exists() else []
            return result, calls

    def test_success_without_matching_summary_text_stays_successful(self):
        result, calls = self.run_runner()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(["test/unit/", "test/bloc/", "test/widget/", "test/golden/"], calls)

    def test_early_failure_survives_later_success(self):
        result, calls = self.run_runner(group_code="7")
        self.assertEqual(7, result.returncode, result.stderr)
        self.assertEqual(4, len(calls))
        self.assertIn("unit: FAILED (exit 7)", result.stdout)
        self.assertIn("golden: PASSED", result.stdout)

    def test_timeout_status_survives_later_success(self):
        result, calls = self.run_runner(group_code="124")
        self.assertEqual(124, result.returncode, result.stderr)
        self.assertEqual(4, len(calls))
        self.assertIn("unit: TIMED OUT", result.stdout)

    def test_rejects_windows_timeout_and_invalid_duration_before_tests(self):
        for options in ({"timeout_version": "Windows timeout"}, {"timeout_seconds": "0"}):
            with self.subTest(options=options):
                result, calls = self.run_runner(**options)
                self.assertEqual(2, result.returncode, result.stderr)
                self.assertEqual([], calls)


if __name__ == "__main__":
    unittest.main()
