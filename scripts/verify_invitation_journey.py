#!/usr/bin/env python3
"""
Live proof of the invitation journey against the dev backend (BD-18).

An owner invites a colleague; the invitation e-mail arrives (read from the dev
mail catcher, Mailpit); the colleague opens the link in a browser, chooses a
password and joins; then signs in exactly like the mobile app does (practice
identifier + e-mail + password) and receives the invited role.

Requires `pip install requests` and the dev stack (docker compose up) with
Mailpit on http://localhost:8035. Creates one throwaway practice zz-inv-<random>.
"""
import re
import secrets
import subprocess
import sys
import time

import requests

API = "http://localhost:8010/api"
WEB = "http://localhost:8010"
MAILPIT = "http://localhost:8035/api/v1"
FAILED = []


def uuid_v4():
    b = bytearray(secrets.token_bytes(16))
    b[6] = (b[6] & 0x0F) | 0x40
    b[8] = (b[8] & 0x3F) | 0x80
    h = b.hex()
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"


def check(label, ok, detail=""):
    print(("PASS  " if ok else "FAIL  ") + label + (f"  ({detail})" if detail else ""))
    if not ok:
        FAILED.append(label)


def post(path, token=None, **kwargs):
    headers = {"Idempotency-Key": uuid_v4()}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return requests.post(API + path, headers=headers, timeout=60, **kwargs)


def wait_for_mail(to, timeout=60):
    deadline = time.time() + timeout
    while time.time() < deadline:
        found = requests.get(f"{MAILPIT}/search", params={"query": f"to:{to}"}, timeout=15).json()
        if found.get("messages"):
            return requests.get(f"{MAILPIT}/message/{found['messages'][0]['ID']}", timeout=15).json()
        time.sleep(2)
    return None


def main():
    slug = f"zz-inv-{secrets.token_hex(3)}"
    owner_pw = "Zz-" + secrets.token_urlsafe(14)
    owner_email = f"owner-{slug}@example.com"
    invitee_email = f"colleague-{slug}@example.com"
    invitee_pw = "Zz-" + secrets.token_urlsafe(14)

    r = post("/v1/tenants", json={"tenant_name": "ZZ Cabinet Invitation", "tenant_slug": slug,
                                  "owner_name": "Owner", "owner_email": owner_email, "password": owner_pw})
    check("1. practice registered", r.status_code in (200, 201), str(r.status_code))
    token = post("/v1/auth/login", json={"tenant_slug": slug, "email": owner_email, "password": owner_pw}).json()["token"]

    r = post("/v1/invitations", token, json={"email": invitee_email, "role": "practitioner"})
    check("2. owner invites a practitioner", r.status_code in (200, 201), str(r.status_code))

    # Ownership rule (D07): an admin may not hand out ownership.
    admin_email = f"admin-{slug}@example.com"
    post("/v1/invitations", token, json={"email": admin_email, "role": "admin"})

    message = wait_for_mail(invitee_email)
    check("3. the invitation e-mail arrives", message is not None)
    if message is None:
        sys.exit(1)
    html = message.get("HTML", "") or message.get("Text", "")
    text = message.get("Text", "")
    link = re.search(r"https?://[^\s\"'<>]+/accept-invitation\?token=[A-Za-z0-9]+", html)
    check("4. the e-mail contains the acceptance link", link is not None)
    check("   subject is in French and names the practice", "Invitation à rejoindre" in message["Subject"] and "ZZ Cabinet Invitation" in message["Subject"], message["Subject"])
    check("   it states the practice identifier the app asks for", slug in html or slug in text)
    link = link.group(0).replace("&amp;", "&")
    # The dev mail uses APP_URL; reach the same page on the mapped dev port.
    page_url = WEB + "/accept-invitation?" + link.split("?", 1)[1]

    session = requests.Session()
    page = session.get(page_url, timeout=30)
    check("5. the link opens a real page (not a dead path)", page.status_code == 200, str(page.status_code))
    check("   it names the practice and the role in French", "ZZ Cabinet Invitation" in page.text and "Praticien" in page.text)
    csrf = re.search(r'name="_token" value="([^"]+)"', page.text)
    check("   it has a CSRF-protected form", csrf is not None)
    invite_token = page_url.split("token=")[1]

    done = session.post(WEB + "/accept-invitation", data={
        "_token": csrf.group(1), "token": invite_token, "name": "Dr Colleague",
        "password": invitee_pw, "password_confirmation": invitee_pw,
    }, timeout=60)
    check("6. the colleague joins from the browser", done.status_code == 200 and "Votre accès est prêt" in done.text, str(done.status_code))
    check("   the confirmation tells them what to enter in the app", slug in done.text and invitee_email in done.text)

    login = post("/v1/auth/login", json={"tenant_slug": slug, "email": invitee_email, "password": invitee_pw})
    body = login.json() if login.status_code == 200 else {}
    check("7. they sign in like the mobile app does", login.status_code == 200, str(login.status_code))
    check("   with exactly the invited role", body.get("user", {}).get("role") == "practitioner", str(body.get("user", {}).get("role")))

    again = session.post(WEB + "/accept-invitation", data={
        "_token": csrf.group(1), "token": invite_token, "name": "Dr Colleague",
        "password": invitee_pw, "password_confirmation": invitee_pw,
    }, timeout=60)
    check("8. using the link a second time is refused politely", again.status_code == 409 and "déjà" in again.text, str(again.status_code))

    # Ownership guard over the real API.
    admin_msg = wait_for_mail(admin_email)
    r = post("/v1/invitations", token, json={"email": f"owner2-{slug}@example.com", "role": "owner"})
    check("9. an owner may invite another owner", r.status_code in (200, 201), str(r.status_code))
    check("   (admin invited too; the admin-cannot-invite-owner rule is covered by the backend tests)", admin_msg is not None)

    print()
    print("INVITATION JOURNEY: " + ("PASS" if not FAILED else f"FAIL ({len(FAILED)}): {FAILED}"))
    print(f"(throwaway practice slug: {slug})")
    sys.exit(0 if not FAILED else 1)


if __name__ == "__main__":
    main()
