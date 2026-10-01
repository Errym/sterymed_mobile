"""Deterministic fixture graph for the reviewed Steriqore Laravel schema.

This describes persisted starting states, not evidence that the corresponding
clinical transitions work. Real acceptance tests must perform those transitions.
"""

from __future__ import annotations

import base64
from datetime import date, timedelta
import hashlib
import struct
import uuid
import zlib

FIXTURE_ID = "sterymed-clinic-fixture-v1"
ROLES = ("owner", "admin", "stock_manager", "releaser", "practitioner", "viewer")
CYCLE_STATES = ("draft", "running", "completed", "awaiting_release", "released", "rejected")
LABEL_STATES = ("created", "printed", "used", "expired", "recalled", "voided")
CASE_STATES = ("impression_completed", "sent_to_laboratory", "received_at_practice",
               "placement_scheduled", "placed", "cancelled")
ORDER_STATES = ("draft", "ordered", "partially_received", "received", "closed", "cancelled")
NAMESPACE = uuid.UUID("4fbe8e11-2296-4aae-81b6-d8d837283c59")
MODEL_PATHS = {
    "Tenant": "Tenancy", "Site": "Tenancy", "Room": "Tenancy", "StorageLocation": "Tenancy",
    "TenantUser": "Identity", "Product": "Catalog", "Device": "Equipment",
    "DeviceProgram": "Equipment", "Supplier": "Purchasing", "SupplierProduct": "Purchasing",
    "PurchaseOrder": "Purchasing", "PurchaseOrderLine": "Purchasing", "GoodsReceipt": "Purchasing",
    "GoodsReceiptLine": "Purchasing", "Batch": "Inventory", "StockMovement": "Inventory",
    "StockLevel": "Inventory", "Alert": "Inventory", "Cycle": "Sterilization",
    "CycleItem": "Sterilization", "ControlTest": "Sterilization", "CycleRelease": "Sterilization",
    "DluRule": "Labeling", "DluRuleVersion": "Labeling", "LabelFormatVersion": "Labeling", "Label": "Labeling", "LabelPrint": "Labeling",
    "Patient": "Traceability", "LabelUsage": "Traceability", "Laboratory": "Prosthetic",
    "ProstheticCase": "Prosthetic", "ProstheticCaseStatusHistory": "Prosthetic",
    "NonConformity": "Compliance", "AuditEvent": "Compliance",
}


def model_class(name: str) -> str:
    if name == "User":
        return "App\\Models\\User"
    if name == "Media":
        return "App\\Support\\Media\\Media"
    return f"App\\Domain\\{MODEL_PATHS[name]}\\Models\\{name}"


def stable_id(key: str) -> str:
    # IDs are UUIDv5 intentionally: Laravel accepts supplied UUIDs, avoiding
    # clock-dependent IDs. Production continues to generate UUIDv7 normally.
    return str(uuid.uuid5(NAMESPACE, f"{FIXTURE_ID}/{key}"))


def png(red: int, green: int, blue: int) -> bytes:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes([0, red, green, blue]))) + chunk(b"IEND", b""))


def pdf() -> bytes:
    stream = b"BT /F1 12 Tf 30 70 Td (SYNTHETIC FIXTURE - no patient data) Tj ET"
    objects = [b"<< /Type /Catalog /Pages 2 0 R >>", b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
               b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 100] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
               b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream",
               b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
    result = b"%PDF-1.4\n"
    offsets = [0]
    for index, obj in enumerate(objects, 1):
        offsets.append(len(result))
        result += str(index).encode() + b" 0 obj\n" + obj + b"\nendobj\n"
    xref = len(result)
    result += b"xref\n0 6\n0000000000 65535 f \n"
    result += b"".join(f"{offset:010d} 00000 n \n".encode() for offset in offsets[1:])
    return result + f"trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()


def build_blueprint(as_of: date) -> dict:
    day = lambda delta=0: (as_of + timedelta(days=delta)).isoformat()
    instant = lambda delta=0: day(delta) + "T10:00:00+00:00"
    rows: list[dict] = []
    memberships: list[dict] = []
    scenarios: dict[str, str] = {}
    attachments: list[dict] = []

    def add(model: str, key: str, **fields) -> str:
        record_id = stable_id(key)
        rows.append({"model": model, "key": key, "attributes": {"id": record_id, **fields}})
        return record_id

    def attachment(tenant: str, model: str, subject: str, key: str, content: bytes, filename: str, mime: str) -> None:
        media_id = add("Media", key, tenant_id=tenant, model_type=model_class(model), model_id=subject,
                       collection_name="attachments", name=filename.rsplit(".", 1)[0], file_name=filename,
                       mime_type=mime, disk="media", conversions_disk="media", size=len(content),
                       manipulations=[], custom_properties={"synthetic": True}, generated_conversions=[],
                       responsive_images=[], order_column=len(attachments) + 1)
        attachments.append({"id": media_id, "path": f"{media_id}/{filename}",
                            "base64": base64.b64encode(content).decode(), "sha256": hashlib.sha256(content).hexdigest()})

    shared = add("User", "shared-user", name="Fixture tenant switch", email="switch@clinic.example.invalid",
                 password="@fixture_password", email_verified_at=instant(-60))
    for clinic in ("populated", "empty"):
        tenant = add("Tenant", clinic, name=f"SYNTHETIC {clinic.title()} Clinic", slug=f"fixture-{clinic}",
                     plan="pro", status="active", timezone="Europe/Paris", locale="fr", country_code="FR")
        scenarios[f"{clinic}.tenant"] = tenant
        users = {}
        for role in (*ROLES, "disabled_membership", "disabled_user", "invited"):
            user = add("User", f"{clinic}/user/{role}", name=f"Fixture {clinic} {role}",
                       email=f"{role}@{clinic}.example.invalid", password="@fixture_password",
                       email_verified_at=instant(-60), disabled_at=instant(-1) if role == "disabled_user" else None)
            users[role] = user
            add("TenantUser", f"{clinic}/membership/{role}", tenant_id=tenant, user_id=user,
                status="disabled" if role == "disabled_membership" else "invited" if role == "invited" else "active",
                invited_at=instant(-60), joined_at=None if role == "invited" else instant(-59),
                disabled_at=instant(-1) if role == "disabled_membership" else None)
            memberships.append({"tenant_id": tenant, "user_id": user, "role": role if role in ROLES else "viewer"})
            scenarios[f"{clinic}.user.{role}"] = user
        add("TenantUser", f"{clinic}/membership/shared", tenant_id=tenant, user_id=shared,
            status="active", joined_at=instant(-59))
        memberships.append({"tenant_id": tenant, "user_id": shared, "role": "admin" if clinic == "populated" else "viewer"})
        site = add("Site", f"{clinic}/site", tenant_id=tenant, name="Fixture main site", country_code="FR",
                   timezone="Europe/Paris", is_primary=True)
        room = add("Room", f"{clinic}/room", tenant_id=tenant, site_id=site, name="Fixture preparation", kind="sterilization")
        location = add("StorageLocation", f"{clinic}/location", tenant_id=tenant, site_id=site, room_id=room,
                       name="Fixture sterile store", kind="cabinet")
        unused_location = add("StorageLocation", f"{clinic}/unused-location", tenant_id=tenant, site_id=site,
                              room_id=room, name="Fixture empty store", kind="cabinet")
        device = add("Device", f"{clinic}/device", tenant_id=tenant, site_id=site, name="Fixture autoclave",
                     serial_number=f"SYNTHETIC-{clinic}", kind="autoclave", status="active")
        program = add("DeviceProgram", f"{clinic}/program", tenant_id=tenant, device_id=device,
                      name="Fixture 134 C", target_temperature_celsius=134, plateau_minutes=18, is_active=True)
        scenarios.update({f"{clinic}.site": site, f"{clinic}.location": location,
                          f"{clinic}.unused_location": unused_location, f"{clinic}.device": device,
                          f"{clinic}.program": program})
        product_ids, supplier_ids, batches, patients, labs = [], [], [], [], []
        count = 121 if clinic == "populated" else 1
        for index in range(count):
            product_ids.append(add("Product", f"{clinic}/product/{index}", tenant_id=tenant,
                                   name=f"Fixture product {index:03}", reference=f"SYN-{index:03}", unit="piece",
                                   min_threshold=5, is_sterilizable=True, default_location_id=location))
            supplier_ids.append(add("Supplier", f"{clinic}/supplier/{index}", tenant_id=tenant,
                                    name=f"Fixture supplier {index:03}", email=f"supplier{index}@{clinic}.example.invalid"))
            add("SupplierProduct", f"{clinic}/supplier-product/{index}", tenant_id=tenant,
                supplier_id=supplier_ids[-1], product_id=product_ids[-1], supplier_reference=f"SUP-{index:03}",
                pack_size=1, price="12.50")
        scenarios[f"{clinic}.product"] = product_ids[0]
        scenarios[f"{clinic}.supplier"] = supplier_ids[0]
        if clinic == "empty":
            # Minimal provisioning, but zero batches, stock, cycles, patients, or cases.
            order = add("PurchaseOrder", "empty/first-order", tenant_id=tenant, supplier_id=supplier_ids[0],
                        status="ordered", ordered_at=instant(-1), expected_at=instant(1))
            line = add("PurchaseOrderLine", "empty/first-order-line", tenant_id=tenant, purchase_order_id=order,
                       product_id=product_ids[0], qty_ordered=10, qty_received=0, unit_price="12.50")
            scenarios.update({"empty.first_order": order, "empty.first_order_line": line})
            continue
        for index in range(121):
            patients.append(add("Patient", f"populated/patient/{index}", tenant_id=tenant, reference=f"FIXTURE-{index:03}"))
            labs.append(add("Laboratory", f"populated/lab/{index}", tenant_id=tenant, name=f"Fixture laboratory {index:03}",
                            contact_email=f"lab{index}@clinic.example.invalid"))
            batch = add("Batch", f"populated/batch/{index}", tenant_id=tenant, product_id=product_ids[index],
                        supplier_id=supplier_ids[index], batch_number=f"FIXTURE-BATCH-{index:03}",
                        expiry_date=day(-1 if index == 1 else 7 if index == 2 else 180),
                        received_at=instant(-365 if index == 0 else -30), status="quarantined" if index == 3 else "active")
            batches.append(batch)
            quantity = 2 if index == 0 else 20
            add("StockMovement", f"populated/movement/{index}", tenant_id=tenant, batch_id=batch,
                location_id=location, type="receipt", qty=quantity, reason="Synthetic initial receipt",
                actor_id=users["stock_manager"], occurred_at=instant(-365 if index == 0 else -30))
            add("StockLevel", f"populated/level/{index}", tenant_id=tenant, batch_id=batch,
                location_id=location, quantity=quantity)
        archived_patient = add("Patient", "populated/archived-patient", tenant_id=tenant,
                               reference="FIXTURE-ARCHIVED", deleted_at=instant(-1))
        archived_lab = add("Laboratory", "populated/archived-lab", tenant_id=tenant,
                           name="Fixture archived laboratory", archived_at=instant(-1))
        add("Device", "populated/archived-device", tenant_id=tenant, site_id=site, name="Fixture archived autoclave",
            kind="autoclave", status="decommissioned", deleted_at=instant(-1))
        add("StorageLocation", "populated/archived-location", tenant_id=tenant, site_id=site, room_id=room,
            name="Fixture archived store", kind="cabinet", deleted_at=instant(-1))
        dlu_version = add("DluRuleVersion", "populated/dlu-version", tenant_id=tenant, packaging_type="pouch",
                          storage_condition="closed_cabinet", shelf_life_days=180, actor_id=users["owner"],
                          reason="Synthetic baseline", effective_from=instant(-365))
        add("DluRule", "populated/dlu", tenant_id=tenant, packaging_type="pouch", storage_condition="closed_cabinet",
            shelf_life_days=180, current_version_id=dlu_version)
        label_format = add("LabelFormatVersion", "populated/label-format", tenant_id=tenant, primary_code="qr",
                           sheet_layout="a4_24", show_batch_number=True, show_product_name=True,
                           actor_id=users["owner"], reason="Synthetic baseline", effective_from=instant(-365))
        scenarios.update({"populated.patient": patients[0], "populated.archived_patient": archived_patient,
                          "populated.archived_lab": archived_lab, "populated.batch": batches[0]})
        cycles = {}
        for index in range(121):
            state = CYCLE_STATES[index % len(CYCLE_STATES)]
            cycle = add("Cycle", f"populated/cycle/{index}", tenant_id=tenant, device_id=device,
                        device_program_id=program, operator_id=users["stock_manager"], cycle_number=index + 1,
                        status=state, started_at=None if state == "draft" else instant(-2),
                        completed_at=None if state in ("draft", "running") else instant(-1), notes="Synthetic cycle")
            cycles.setdefault(state, cycle)
            add("CycleItem", f"populated/cycle-item/{index}", tenant_id=tenant, cycle_id=cycle,
                batch_id=batches[index], description=f"Fixture instrument pack {index:03}", sequence_in_cycle=1)
            if state not in ("draft", "running"):
                add("ControlTest", f"populated/control/{index}", tenant_id=tenant, cycle_id=cycle,
                    type="helix", result="fail" if state == "rejected" else "pass", performed_at=instant(-1))
            if state in ("released", "rejected"):
                add("CycleRelease", f"populated/release/{index}", tenant_id=tenant, cycle_id=cycle,
                    decision="compliant" if state == "released" else "rejected", released_by_user_id=users["releaser"],
                    released_at=instant(-1), reason="Synthetic evidence decision")
        scenarios.update({f"cycle.{key}": value for key, value in cycles.items()})
        for index, state in enumerate((*LABEL_STATES, "used_pending_usage", "expires_today")):
            label_state = "used" if state == "used_pending_usage" else "printed" if state == "expires_today" else state
            printed = label_state != "created"
            sterilized_delta = -181 if label_state == "expired" else -180 if state == "expires_today" else -1
            label_cycle = add("Cycle", f"populated/label-cycle/{state}", tenant_id=tenant, device_id=device,
                              device_program_id=program, operator_id=users["stock_manager"], cycle_number=1000 + index,
                              status="released", started_at=day(sterilized_delta) + "T09:00:00+00:00",
                              completed_at=instant(sterilized_delta))
            add("ControlTest", f"populated/label-control/{state}", tenant_id=tenant, cycle_id=label_cycle,
                type="helix", result="pass", performed_at=instant(sterilized_delta))
            add("CycleRelease", f"populated/label-release/{state}", tenant_id=tenant, cycle_id=label_cycle,
                decision="compliant", released_by_user_id=users["releaser"], released_at=instant(sterilized_delta),
                reason="Synthetic label source cycle")
            item = add("CycleItem", f"populated/label-item/{state}", tenant_id=tenant, cycle_id=label_cycle,
                       batch_id=batches[0], description=f"Fixture label {state}", sequence_in_cycle=1)
            label = add("Label", f"populated/label/{state}", tenant_id=tenant, cycle_item_id=item, status=label_state,
                        packaging_type="pouch", storage_condition="closed_cabinet", shelf_life_days=180,
                        sterilized_at=instant(sterilized_delta), use_by_date=day(sterilized_delta + 180),
                        print_counter=1 if printed else 0, dlu_rule_version_id=dlu_version)
            scenarios[f"label.{state}"] = label
            if printed:
                add("LabelPrint", f"populated/label-print/{state}", tenant_id=tenant, label_id=label,
                    printed_by_user_id=users["stock_manager"], sequence=1, printed_at=instant(sterilized_delta),
                    label_format_version_id=label_format)
            if state == "used":
                add("LabelUsage", "populated/usage", tenant_id=tenant, label_id=label, patient_id=patients[0],
                    practitioner_id=users["practitioner"], procedure="Synthetic procedure", used_at=instant())
        for index in range(121):
            state = CASE_STATES[index % len(CASE_STATES)]
            progressed = CASE_STATES.index(state)
            case = add("ProstheticCase", f"populated/case/{index}", tenant_id=tenant,
                       patient_id=patients[index], practitioner_id=users["practitioner"],
                       laboratory_id=archived_lab if index == 120 else labs[index], status=state,
                       priority="urgent" if index % 5 == 0 else None, impression_type="digital" if index % 2 else "physical",
                       work_type=("crown", "bridge", "implant", "aligner", "veneer", "denture", "other")[index % 7],
                       impression_date=day(-40), sent_to_lab_date=day(-35) if 1 <= progressed <= 4 else None,
                       returned_from_lab_date=day(-(index % 31)) if 2 <= progressed <= 4 else None,
                       planned_placement_date=day(-1 if state == "placed" else (index // 6) % 3 - 1) if 3 <= progressed <= 4 else None,
                       actual_placement_date=day(-1) if state == "placed" else None,
                       deposit_requested=index % 3 != 0, deposit_received=index % 3 == 2,
                       deposit_amount="12.50" if index % 3 else None, final_payment_completed=state == "placed",
                       remaining_balance="0.00" if state == "placed" else "1234.56" if index % 3 else None,
                       created_by_user_id=users["admin"], notes="Synthetic prosthetic work")
            scenarios.setdefault(f"case.{state}", case)
            previous = None
            history_states = list(CASE_STATES[:min(progressed, 4) + 1]) if state != "cancelled" else [CASE_STATES[0], "cancelled"]
            if index == 120:
                history_states = [CASE_STATES[0], "cancelled", CASE_STATES[0]]
                scenarios["case.restarted"] = case
            for step, status in enumerate(history_states):
                add("ProstheticCaseStatusHistory", f"populated/case-history/{index}/{step}", tenant_id=tenant,
                    prosthetic_case_id=case, from_status=previous, to_status=status, changed_by_user_id=users["admin"],
                    created_at=instant(-40 + step), note="Synthetic starting-state history")
                previous = status
        for index in range(121):
            state = ORDER_STATES[index % len(ORDER_STATES)]
            received = 0 if state in ("draft", "ordered", "cancelled") else 4 if state == "partially_received" else 10
            order = add("PurchaseOrder", f"populated/order/{index}", tenant_id=tenant, supplier_id=supplier_ids[index],
                        status=state, ordered_at=None if state == "draft" else instant(-10), expected_at=instant(1))
            line = add("PurchaseOrderLine", f"populated/order-line/{index}", tenant_id=tenant, purchase_order_id=order,
                       product_id=product_ids[index], qty_ordered=10, qty_received=received, unit_price="12.50")
            scenarios.setdefault(f"order.{state}", order)
            if received:
                receipt = add("GoodsReceipt", f"populated/receipt/{index}", tenant_id=tenant, purchase_order_id=order,
                              received_by=users["stock_manager"], received_at=instant(-2))
                add("GoodsReceiptLine", f"populated/receipt-line/{index}", tenant_id=tenant, goods_receipt_id=receipt,
                    purchase_order_line_id=line, product_id=product_ids[index], batch_id=batches[index], qty=received,
                    discrepancy_reason="Synthetic partial receipt" if received < 10 else None)
                add("StockMovement", f"populated/receipt-movement/{index}", tenant_id=tenant, batch_id=batches[index],
                    location_id=location, type="receipt", qty=received, actor_id=users["stock_manager"], occurred_at=instant(-2))
                next(row for row in rows if row["key"] == f"populated/level/{index}")["attributes"]["quantity"] += received
        for index, (kind, subject_model, subject) in enumerate([
            ("low_stock", "Product", product_ids[0]), ("expired", "Batch", batches[1]),
            ("near_expiry", "Batch", batches[2]), ("failed_cycle", "Cycle", cycles["rejected"]) ]):
            add("Alert", f"populated/alert/{index}", tenant_id=tenant, type=kind, severity="critical" if index in (1, 3) else "warning",
                state="open", subject_type=model_class(subject_model), subject_id=subject, message="Synthetic fixture alert")
        for key, subject_model, subject in [("recalled_label", "Label", scenarios["label.recalled"]),
                                          ("quarantined_batch", "Batch", batches[3])]:
            add("NonConformity", f"populated/nc/{key}", tenant_id=tenant, subject_type=model_class(subject_model),
                subject_id=subject, description="Synthetic non-conformity", raised_by_user_id=users["releaser"], raised_at=instant())
        add("AuditEvent", "populated/audit", tenant_id=tenant, actor_id=users["owner"], actor_label_snapshot="Fixture owner",
            action="fixture.seeded", subject_type=model_class("Tenant"), subject_id=tenant,
            new_values={"fixture_id": FIXTURE_ID}, occurred_at=instant())
        attachment(tenant, "Cycle", cycles["awaiting_release"], "attachment/cycle-a", png(255, 0, 0), "evidence.png", "image/png")
        attachment(tenant, "Cycle", cycles["awaiting_release"], "attachment/cycle-b", png(0, 0, 255), "evidence.png", "image/png")
        attachment(tenant, "ProstheticCase", scenarios["case.impression_completed"], "attachment/case-a", png(0, 255, 0), "evidence.png", "image/png")
        attachment(tenant, "Cycle", cycles["awaiting_release"], "attachment/pdf", pdf(), "ticket.pdf", "application/pdf")
    return {"fixture_id": FIXTURE_ID, "as_of": as_of.isoformat(), "synthetic_only": True,
            "rows": rows, "roles": memberships, "scenarios": scenarios, "attachments": attachments,
            "accounts": {clinic: {role: f"{role}@{clinic}.example.invalid" for role in (*ROLES, "disabled_membership", "disabled_user", "invited")}
                         for clinic in ("populated", "empty")},
            "limitations": ["Membership has no archived_at field or supported archived lifecycle; disabled/invited memberships and archived domain records cover the real schema.",
                            "Empty clinic has minimal equipment/catalog provisioning and an ordered first purchase, but no stock or clinical records.",
                            "Seeded state coverage does not prove transitions, authorization, PDF printing, or device behavior."]}
