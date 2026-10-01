"""Local fixture launcher. No connection is made by prepare or self-test."""

from __future__ import annotations

import argparse
import base64
from datetime import date
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
from urllib.parse import urlsplit

from .blueprint import FIXTURE_ID, build_blueprint

WORKSPACE = Path(__file__).resolve().parents[2]
KIT = Path(__file__).resolve().parent
RUNTIME = WORKSPACE / "build" / "clinic-fixture"
DATABASE = "steriqore_mobile_fixture"
OWNER = "clinic_fixture_owner"
APP_ROLE = "clinic_fixture_app"
API_URL = "http://127.0.0.1:18010/api"
RESET_CONFIRMATION = f"{FIXTURE_ID}:{DATABASE}"


class GuardError(ValueError):
    pass


def validate_settings(settings: dict, expected_runtime: Path = RUNTIME) -> None:
    if not expected_runtime.resolve().is_relative_to(WORKSPACE.resolve()):
        raise GuardError("Fixture runtime must remain inside the mobile workspace.")
    if settings.get("fixture_id") != FIXTURE_ID or settings.get("purpose") != "disposable-synthetic-clinic":
        raise GuardError("Fixture identity/purpose does not match this kit.")
    expected = {"host": "127.0.0.1", "port": 5466, "database": DATABASE, "owner": OWNER, "username": APP_ROLE}
    if any(settings.get("database", {}).get(key) != value for key, value in expected.items()):
        raise GuardError("Database target must be the dedicated loopback fixture database and roles.")
    url = urlsplit(settings.get("api_url", ""))
    if (url.scheme, url.hostname, url.port, url.path, url.query, url.fragment, url.username, url.password) != (
        "http", "127.0.0.1", 18010, "/api", "", "", None, None
    ):
        raise GuardError("API server must be http://127.0.0.1:18010/api.")
    if Path(settings.get("runtime", "")).resolve() != expected_runtime.resolve():
        raise GuardError("Runtime path does not match this workspace's dedicated fixture directory.")
    if Path(settings.get("backend", "")).resolve() != (expected_runtime / "backend").resolve():
        raise GuardError("Backend must be the isolated fixture copy.")
    for key in ("owner_token", "fixture_password", "app_key"):
        if not isinstance(settings.get(key), str) or len(settings[key]) < 24:
            raise GuardError(f"Missing generated fixture secret: {key}.")
    for key in ("owner_password", "password"):
        if len(settings["database"].get(key, "")) < 24:
            raise GuardError("Missing generated database credentials.")


def check_reset_confirmation(value: str | None) -> None:
    if value != RESET_CONFIRMATION:
        raise GuardError(f"Reset requires --confirm {RESET_CONFIRMATION}")


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    # chmod is best effort on Windows; runtime is ignored by git. Credentials
    # stay in this user's workspace and are never printed by this launcher.
    path.chmod(0o600)


def isolated_environment(settings: dict) -> dict[str, str]:
    # Do not forward DB_URL, APP_ENV, AWS, mail, Sentry or Laravel cache paths.
    allowed = ("PATH", "PATHEXT", "SYSTEMROOT", "WINDIR", "TEMP", "TMP", "HOME", "USERPROFILE",
               "COMSPEC", "SystemDrive", "LANG", "SSL_CERT_FILE", "SSL_CERT_DIR")
    env = {key: value for key, value in os.environ.items() if key.upper() in {entry.upper() for entry in allowed}}
    env.update({"CLINIC_FIXTURE_SETTINGS": str(RUNTIME / "settings.json"), "APP_ENV": "testing"})
    return env


def prepare(source: Path, as_of: date) -> None:
    source = source.resolve()
    if not (source / "artisan").is_file() or not (source / "composer.lock").is_file():
        raise GuardError("Backend source must contain artisan and composer.lock.")
    if source == RUNTIME.resolve() or RUNTIME.resolve() in source.parents:
        raise GuardError("Source cannot be inside the fixture runtime.")
    if (RUNTIME / "settings.json").exists():
        raise GuardError("Fixture already prepared. Use seed/serve/reset; preparation never overwrites an existing runtime.")
    if not RUNTIME.resolve().is_relative_to(WORKSPACE.resolve()) or (RUNTIME.exists() and any(RUNTIME.iterdir())):
        raise GuardError("Preparation requires an empty dedicated runtime directory inside the mobile workspace.")
    RUNTIME.mkdir(parents=True, exist_ok=True)
    blueprint = build_blueprint(as_of)
    write_json(RUNTIME / "blueprint.json", blueprint)
    settings = {"fixture_id": FIXTURE_ID, "purpose": "disposable-synthetic-clinic", "runtime": str(RUNTIME.resolve()),
                "backend": str((RUNTIME / "backend").resolve()), "source": str(source), "api_url": API_URL,
                "owner_token": secrets.token_hex(32), "fixture_password": secrets.token_urlsafe(30),
                "app_key": "base64:" + base64.b64encode(secrets.token_bytes(32)).decode(),
                "blueprint_sha256": hashlib.sha256((RUNTIME / "blueprint.json").read_bytes()).hexdigest(),
                "database": {"host": "127.0.0.1", "port": 5466, "database": DATABASE,
                             "owner": OWNER, "username": APP_ROLE, "owner_password": secrets.token_urlsafe(30),
                             "password": secrets.token_urlsafe(30)}}
    validate_settings(settings)
    backend = RUNTIME / "backend"
    backend.mkdir(exist_ok=True)
    copied = []
    # Explicit source allowlist excludes original .env, caches, credentials,
    # dependencies, logs, uploads and deployment data. Never write to source.
    for relative in ("app", "bootstrap", "config", "database", "routes", "resources/views", "lang"):
        directory = source / relative
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*")):
            if not path.is_file() or path.is_symlink() or "cache" in path.relative_to(source).parts:
                continue
            target = backend / path.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(path.read_bytes())
            copied.append({"path": path.relative_to(source).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    for relative in ("artisan", "composer.json", "composer.lock"):
        shutil.copyfile(source / relative, backend / relative)
        copied.append({"path": relative, "sha256": hashlib.sha256((source / relative).read_bytes()).hexdigest()})
    for directory in ("bootstrap/cache", "public"):
        (backend / directory).mkdir(parents=True, exist_ok=True)
    for directory in ("storage/framework/cache/data", "storage/framework/sessions", "storage/framework/views", "storage/logs", "media"):
        (RUNTIME / directory).mkdir(parents=True, exist_ok=True)
    (RUNTIME / ".env.fixture").write_text("# Intentionally empty. Fixture bootstrap sets all runtime configuration.\n", encoding="utf-8")
    write_json(RUNTIME / "source_manifest.json", {"source": str(source), "files": copied})
    write_json(RUNTIME / "settings.json", settings)
    # Compose .env interpolation only receives generated URL-safe values.
    (RUNTIME / "compose.env").write_text(f"FIXTURE_OWNER_PASSWORD={settings['database']['owner_password']}\n"
                                        f"FIXTURE_APP_PASSWORD={settings['database']['password']}\n", encoding="utf-8")
    init_sql = (f"CREATE ROLE {APP_ROLE} LOGIN PASSWORD '{settings['database']['password']}' NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;\n"
                f"GRANT CONNECT ON DATABASE {DATABASE} TO {APP_ROLE};\n")
    (RUNTIME / "init.sql").write_text(init_sql, encoding="utf-8")
    print(f"Prepared {len(blueprint['rows'])} synthetic records and {len(copied)} source files under build/clinic-fixture.")
    print("No database connection made. Credentials remain in ignored local files. Follow the fixture README to provision PHP/PostgreSQL.")


def load_settings() -> dict:
    path = RUNTIME / "settings.json"
    if not path.exists():
        raise GuardError("Run prepare first.")
    settings = json.loads(path.read_text(encoding="utf-8"))
    validate_settings(settings)
    if hashlib.sha256((RUNTIME / "blueprint.json").read_bytes()).hexdigest() != settings["blueprint_sha256"]:
        raise GuardError("Blueprint changed after preparation; refusing this runtime.")
    return settings


def export_defines(settings: dict) -> None:
    # Called only after real seed + persisted validation succeeded.
    blueprint = json.loads((RUNTIME / "blueprint.json").read_text(encoding="utf-8"))
    scenarios = blueprint["scenarios"]
    values = {"RUN_LIVE_INTEGRATION_TESTS": "true", "ENV": "dev", "API_BASE_URL": settings["api_url"],
              "TEST_FIXTURE_ID": FIXTURE_ID, "TEST_TENANT_SLUG": "fixture-populated",
              "TEST_ADMIN_EMAIL": "admin@populated.example.invalid", "TEST_ADMIN_PASSWORD": settings["fixture_password"],
              "TEST_DEVICE_NAME": "Fixture autoclave", "TEST_DEVICE_ID": scenarios["populated.device"],
              "TEST_PROGRAM_ID": scenarios["populated.program"], "TEST_TENANT_ID": scenarios["populated.tenant"]}
    write_json(RUNTIME / "flutter_defines.json", values)
    # Android emulator requires host alias; server still binds loopback.
    write_json(RUNTIME / "flutter_defines.android_emulator.json", {**values, "API_BASE_URL": "http://10.0.2.2:18010/api"})
    write_json(RUNTIME / "manifest.json", {"fixture_id": FIXTURE_ID, "as_of": blueprint["as_of"], "seed_executed": True,
                                          "scenarios": scenarios, "accounts": blueprint["accounts"],
                                          "limitations": blueprint["limitations"]})


def run_php(command: str, settings: dict, php: str, confirm: str | None = None) -> int:
    if command == "reset":
        check_reset_confirmation(confirm)
    executable = shutil.which(php)
    if executable is None:
        raise GuardError("PHP executable unavailable. Install PHP 8.4+ with pdo_pgsql; seed has not run.")
    if not (Path(settings["backend"]) / "vendor/autoload.php").is_file():
        raise GuardError("Isolated backend vendor/autoload.php missing. Install locked Composer dependencies in build/clinic-fixture/backend.")
    environment = isolated_environment(settings)
    if command == "serve":
        # Guard once before starting, then again inside every HTTP bootstrap.
        checked = subprocess.run([executable, str(KIT / "seed.php"), "verify"], env=environment, check=False)
        if checked.returncode:
            return checked.returncode
        print("Serving synthetic fixture on 127.0.0.1:18010. Use a fresh test app install; Ctrl+C stops the server.")
        return subprocess.call([executable, "-S", "127.0.0.1:18010", str(KIT / "router.php")], env=environment, cwd=RUNTIME)
    argv = [executable, str(KIT / "seed.php"), command]
    if confirm is not None:
        argv.append(confirm)
    result = subprocess.run(argv, env=environment, check=False)
    if result.returncode == 0 and command in ("seed", "reset"):
        export_defines(settings)
    return result.returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "seed", "verify", "reset", "serve", "self-test"))
    parser.add_argument("--backend", type=Path, default=WORKSPACE.parent / "steriqore", help="Read-only source, used by prepare only")
    parser.add_argument("--as-of", type=date.fromisoformat, default=date.today(), help="Fixture reference date (prepare only)")
    parser.add_argument("--php", default="php")
    parser.add_argument("--confirm", help="Exact reset identity; never accepts a database name override")
    args = parser.parse_args(argv)
    try:
        if args.command == "self-test":
            return subprocess.call([sys.executable, "-m", "unittest", "testing.clinic_fixture.test_fixture", "-v"], cwd=WORKSPACE)
        if args.command == "prepare":
            prepare(args.backend, args.as_of)
            return 0
        return run_php(args.command, load_settings(), args.php, args.confirm)
    except (GuardError, OSError, ValueError) as error:
        print(f"Fixture refused: {error}", file=sys.stderr)
        return 2

