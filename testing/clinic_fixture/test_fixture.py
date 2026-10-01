"""Offline tests. These do not claim that Laravel/PostgreSQL ran."""

from collections import Counter, defaultdict
from copy import deepcopy
from datetime import date
import hashlib
import json
from pathlib import Path
import re
import unittest
from unittest.mock import patch

from .blueprint import (CASE_STATES, CYCLE_STATES, FIXTURE_ID, LABEL_STATES, ORDER_STATES,
                        ROLES, build_blueprint, model_class)
from .launcher import (API_URL, APP_ROLE, DATABASE, OWNER, RESET_CONFIRMATION, RUNTIME, WORKSPACE,
                       GuardError, check_reset_confirmation, isolated_environment, validate_settings)


class FixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.blueprint = build_blueprint(date(2026, 10, 1))
        cls.rows = cls.blueprint["rows"]
        cls.by_id = {row["attributes"]["id"]: row for row in cls.rows}

    def rows_of(self, model):
        return [row["attributes"] for row in self.rows if row["model"] == model]

    def settings(self):
        return {"fixture_id": FIXTURE_ID, "purpose": "disposable-synthetic-clinic", "runtime": str(RUNTIME),
                "backend": str(RUNTIME / "backend"), "api_url": API_URL, "owner_token": "x" * 64,
                "fixture_password": "x" * 40, "app_key": "x" * 40,
                "database": {"host": "127.0.0.1", "port": 5466, "database": DATABASE, "owner": OWNER,
                             "username": APP_ROLE, "password": "a" * 40, "owner_password": "b" * 40}}

    def test_repeatable_graph_and_unique_ids(self):
        self.assertEqual(self.blueprint, build_blueprint(date(2026, 10, 1)))
        self.assertEqual(len(self.by_id), len(self.rows))
        next_day = build_blueprint(date(2026, 10, 2))
        self.assertEqual(self.blueprint["scenarios"], next_day["scenarios"])

    def test_all_references_exist_and_stay_in_tenant(self):
        for row in self.rows:
            fields = row["attributes"]
            for field, value in fields.items():
                if not field.endswith("_id") or value is None:
                    continue
                self.assertIn(value, self.by_id, f"{row['key']}.{field}")
                linked_tenant = self.by_id[value]["attributes"].get("tenant_id")
                if linked_tenant is not None:
                    self.assertEqual(fields.get("tenant_id"), linked_tenant, f"cross tenant: {row['key']}.{field}")

    def test_role_and_membership_cases(self):
        for tenant in self.rows_of("Tenant"):
            roles = {role["role"] for role in self.blueprint["roles"] if role["tenant_id"] == tenant["id"]}
            self.assertEqual(roles, set(ROLES))
            statuses = {row["status"] for row in self.rows_of("TenantUser") if row["tenant_id"] == tenant["id"]}
            self.assertEqual(statuses, {"active", "invited", "disabled"})
        self.assertEqual(sum(bool(row["disabled_at"]) for row in self.rows_of("User") if "disabled_at" in row), 2)

    def test_shared_user_has_distinct_tenant_roles(self):
        grouped = defaultdict(list)
        for membership in self.blueprint["roles"]:
            grouped[membership["user_id"]].append(membership["role"])
        self.assertIn(["admin", "viewer"], list(grouped.values()))

    def test_state_coverage(self):
        for model, states in (("Cycle", CYCLE_STATES), ("Label", LABEL_STATES),
                              ("ProstheticCase", CASE_STATES), ("PurchaseOrder", ORDER_STATES)):
            self.assertEqual({row["status"] for row in self.rows_of(model)}, set(states))

    def test_pagination_exceeds_hundred_record_clients(self):
        for model in ("Patient", "Supplier", "Product", "Batch", "Cycle", "PurchaseOrder", "ProstheticCase", "Laboratory"):
            self.assertGreater(len(self.rows_of(model)), 100, model)

    def test_empty_clinic_has_no_stock_or_clinical_records(self):
        tenant = self.blueprint["scenarios"]["empty.tenant"]
        for model in ("Batch", "StockLevel", "StockMovement", "Cycle", "Label", "Patient", "ProstheticCase"):
            self.assertFalse([row for row in self.rows_of(model) if row["tenant_id"] == tenant], model)
        self.assertIn("empty.first_order_line", self.blueprint["scenarios"])
        unused = self.blueprint["scenarios"]["populated.unused_location"]
        self.assertFalse([row for row in self.rows_of("StockLevel") if row["location_id"] == unused])

    def test_single_eligible_device_and_program_per_tenant(self):
        for tenant in self.rows_of("Tenant"):
            active = [row for row in self.rows_of("Device") if row["tenant_id"] == tenant["id"] and row["status"] == "active"]
            self.assertEqual(len(active), 1)
            self.assertEqual(sum(row["device_id"] == active[0]["id"] and row["is_active"] for row in self.rows_of("DeviceProgram")), 1)

    def test_stock_projection_equals_signed_ledger(self):
        ledger = defaultdict(int)
        for row in self.rows_of("StockMovement"):
            ledger[(row["tenant_id"], row["batch_id"], row["location_id"])] += row["qty"]
        levels = {(row["tenant_id"], row["batch_id"], row["location_id"]): row["quantity"] for row in self.rows_of("StockLevel")}
        self.assertEqual(ledger, levels)

    def test_receipts_match_order_line_quantities(self):
        received = Counter()
        for row in self.rows_of("GoodsReceiptLine"):
            received[row["purchase_order_line_id"]] += row["qty"]
        for row in self.rows_of("PurchaseOrderLine"):
            self.assertEqual(row["qty_received"], received[row["id"]])
            self.assertLessEqual(row["qty_received"], row["qty_ordered"])

    def test_labels_have_compliant_release_and_consistent_dlu(self):
        releases = {row["cycle_id"]: row for row in self.rows_of("CycleRelease")}
        print_counts = Counter(row["label_id"] for row in self.rows_of("LabelPrint"))
        for label in self.rows_of("Label"):
            item = self.by_id[label["cycle_item_id"]]["attributes"]
            cycle = self.by_id[item["cycle_id"]]["attributes"]
            self.assertEqual(cycle["status"], "released")
            self.assertEqual(releases[cycle["id"]]["decision"], "compliant")
            self.assertEqual(label["sterilized_at"], cycle["completed_at"])
            self.assertEqual((date.fromisoformat(label["use_by_date"]) - date.fromisoformat(label["sterilized_at"][:10])).days, label["shelf_life_days"])
            self.assertEqual(label["print_counter"], print_counts[label["id"]])

    def test_used_pending_usage_and_used_with_usage_are_distinct(self):
        used = {row["label_id"] for row in self.rows_of("LabelUsage")}
        self.assertIn(self.blueprint["scenarios"]["label.used"], used)
        self.assertNotIn(self.blueprint["scenarios"]["label.used_pending_usage"], used)

    def test_prosthetic_restart_and_date_filter_cases(self):
        restarted = self.blueprint["scenarios"]["case.restarted"]
        history = [row["to_status"] for row in self.rows_of("ProstheticCaseStatusHistory") if row["prosthetic_case_id"] == restarted]
        self.assertEqual(history, ["impression_completed", "cancelled", "impression_completed"])
        planned = {row["planned_placement_date"] for row in self.rows_of("ProstheticCase") if row["status"] == "placement_scheduled"}
        self.assertEqual(planned, {"2026-09-30", "2026-10-01", "2026-10-02"})

    def test_duplicate_attachment_names_have_distinct_storage_and_content(self):
        evidence = [row for row in self.rows_of("Media") if row["file_name"] == "evidence.png"]
        self.assertEqual(len(evidence), 3)
        attachments = self.blueprint["attachments"]
        self.assertEqual(len({item["path"] for item in attachments}), len(attachments))
        self.assertEqual(len({item["sha256"] for item in attachments}), len(attachments))
        self.assertTrue(any(item["path"].endswith(".pdf") for item in attachments))

    def test_synthetic_accounts_only(self):
        for row in self.rows_of("User"):
            self.assertTrue(row["email"].endswith(".example.invalid"))
            self.assertEqual(row["password"], "@fixture_password")

    def test_fixture_settings_accept_only_dedicated_endpoint(self):
        validate_settings(self.settings())
        for field, value in (("host", "clinic.example.com"), ("host", "localhost"), ("port", 5432),
                             ("database", "steriqore"), ("database", "steriqore_test"), ("owner", "postgres"), ("username", OWNER)):
            settings = self.settings()
            settings["database"][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(GuardError):
                validate_settings(settings)

    def test_reject_api_wrong_port_path_and_credentials(self):
        for url in ("https://clinic.example/api", "http://127.0.0.1:8000/api", "http://127.0.0.1:18010/api/v1",
                    "http://user@127.0.0.1:18010/api", "http://127.0.0.1:18010/api?db=production"):
            settings = self.settings()
            settings["api_url"] = url
            with self.subTest(url=url), self.assertRaises(GuardError):
                validate_settings(settings)

    def test_reject_wrong_identity_runtime_and_missing_secrets(self):
        for field, value in (("fixture_id", "production"), ("runtime", str(WORKSPACE)),
                             ("backend", str(WORKSPACE.parent / "steriqore")), ("owner_token", "")):
            settings = self.settings()
            settings[field] = value
            with self.subTest(field=field), self.assertRaises(GuardError):
                validate_settings(settings)

    def test_reset_requires_exact_identity(self):
        check_reset_confirmation(RESET_CONFIRMATION)
        for value in (None, "yes", DATABASE, "steriqore", FIXTURE_ID):
            with self.subTest(value=value), self.assertRaises(GuardError):
                check_reset_confirmation(value)

    def test_process_environment_does_not_inherit_clinic_configuration(self):
        with patch.dict("os.environ", {"DB_URL": "postgres://clinic", "APP_ENV": "production", "AWS_SECRET_ACCESS_KEY": "secret", "SENTRY_DSN": "https://private"}):
            env = isolated_environment(self.settings())
        self.assertNotIn("DB_URL", env)
        self.assertNotIn("AWS_SECRET_ACCESS_KEY", env)
        self.assertNotIn("SENTRY_DSN", env)
        self.assertEqual(env["APP_ENV"], "testing")

    def test_model_fields_and_enums_match_reviewed_backend(self):
        source = WORKSPACE.parent / "steriqore"
        if not (source / "artisan").exists():
            self.skipTest("Backend checkout absent; run source-contract test with the reviewed sibling checkout.")
        checked = {}
        errors = set()
        for row in self.rows:
            name = row["model"]
            if name not in checked:
                path = source / (model_class(name).replace("App\\", "app\\", 1).replace("\\", "/") + ".php")
                self.assertTrue(path.is_file(), name)
                code = path.read_text(encoding="utf-8")
                fillable = re.search(r"protected \$fillable\s*=\s*\[(.*?)\];", code, re.S)
                fields = set(re.findall(r"'([^']+)'", fillable[1])) if fillable else None
                enums = {}
                for field, enum in re.findall(r"'([^']+)'\s*=>\s*([A-Z]\w+)::class", code):
                    imported = re.search(r"use ([^;]+\\" + enum + r");", code)
                    if imported:
                        enum_path = source / (imported[1].replace("App\\", "app\\", 1).replace("\\", "/") + ".php")
                        enums[field] = set(re.findall(r"case \w+ = '([^']+)'", enum_path.read_text(encoding="utf-8")))
                checked[name] = fields, enums
            fields, enums = checked[name]
            if fields is not None:
                unknown = set(row["attributes"]) - fields - {"id", "created_at", "updated_at", "deleted_at", "email_verified_at"}
                if unknown:
                    errors.add(f"{name} fields absent from actual model: {sorted(unknown)}")
            for field, values in enums.items():
                if row["attributes"].get(field) is not None:
                    if row["attributes"][field] not in values:
                        errors.add(f"{name}.{field}={row['attributes'][field]} is outside {sorted(values)}")
        self.assertFalse(errors, "\n".join(sorted(errors)))


if __name__ == "__main__":
    unittest.main()
