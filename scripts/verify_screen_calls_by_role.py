import json, secrets, time, requests

d = json.load(open('build/web-journeys/defines.json'))
B = d['API_BASE_URL']


def login(role):
    for _ in range(4):
        r = requests.post(B + '/v1/auth/login', headers={'Idempotency-Key': secrets.token_hex(8)},
                          json={'tenant_slug': d['WEB_TENANT_SLUG'], 'email': d['WEB_EMAIL_' + role],
                                'password': d['WEB_PASSWORD']})
        if r.status_code == 200:
            j = r.json()
            return j['token'], j['user']
        if r.status_code == 429:
            time.sleep(20)
            continue
        raise SystemExit(f'login {role}: {r.status_code} {r.text[:120]}')
    raise SystemExit('rate limited')


# every call the new screens make, with the permission that gates it in the app
CALLS = [
    ('dashboard cycles', 'cycles.view', '/v1/cycles', {'limit': 50}),
    ('dashboard alerts', 'alerts.view', '/v1/alerts', {'filter[state]': 'open', 'limit': 50}),
    ('dashboard audit', 'audit.view', '/v1/audit-events', {'limit': 20}),
    ('dashboard devices', None, '/v1/devices', {'limit': 50}),
    ('dashboard stock', 'inventory.view', '/v1/stock-levels', {'limit': 200}),
    ('dashboard orders', 'purchasing.view', '/v1/purchase-orders', {'limit': 50}),
    ('dashboard prosthetic', 'prosthetic_cases.view', '/v1/prosthetic-dashboard', {}),
    ('stock list', 'inventory.view', '/v1/stock-levels', {'limit': 200}),
    ('lots', 'inventory.view', '/v1/batches', {'limit': 200}),
    ('products', 'products.view', '/v1/products', {'limit': 100}),
    ('product families', 'products.view', '/v1/product-categories', {}),
    ('suppliers', 'suppliers.view', '/v1/suppliers', {'limit': 100}),
    ('orders list', 'purchasing.view', '/v1/purchase-orders', {}),
    ('sites', 'sites.view', '/v1/sites', {}),
    ('devices', 'devices.view', '/v1/devices', {'limit': 100}),
    ('patients', 'patients.view', '/v1/patients', {'limit': 100}),
    ('patient: prosthetic files', 'prosthetic_cases.view', '/v1/prosthetic-cases', {'patient_reference': 'PAT-000001'}),
    ('patient: material used', 'usages.view', '/v1/evidence-search', {'patient_reference': 'PAT-000001'}),
    ('inventories', 'inventory.view', '/v1/inventory-counts', {}),
    ('non-conformities', 'non_conformities.view', '/v1/non-conformities', {}),
    ('team members', 'invitations.create', '/v1/members', {}),
    ('invitations', 'invitations.create', '/v1/invitations', {}),
    ('dlu rules', 'labels.view', '/v1/dlu-rules', {}),
    ('audit log', 'audit.view', '/v1/audit-events', {'limit': 50}),
]

roles = ['OWNER', 'ADMIN', 'STOCK_MANAGER', 'RELEASER', 'PRACTITIONER', 'VIEWER']
problems = []
for role in roles:
    token, user = login(role)
    perms = set(user.get('permissions', []))
    h = {'Authorization': 'Bearer ' + token, 'Accept': 'application/json'}
    print(f'\n== {role} ({user.get("role")}) — {len(perms)} permissions')
    for name, need, path, q in CALLS:
        allowed_in_app = need is None or need in perms
        r = requests.get(B + path, params=q, headers=h)
        ok = r.status_code == 200
        # The app asks only when it believes the role may; a mismatch either way is a bug.
        verdict = 'ok'
        if allowed_in_app and not ok:
            verdict = f'APP WILL ASK BUT SERVER SAYS {r.status_code}'
            problems.append((role, name, r.status_code, r.text[:140]))
        elif not allowed_in_app and ok:
            verdict = 'server allows but app hides it (check permission name)'
            problems.append((role, name, 'hidden-but-allowed', need))
        if verdict != 'ok':
            print(f'  {name:28} app-allowed={allowed_in_app!s:5} http={r.status_code}  -> {verdict}')
    time.sleep(1)

print('\nPROBLEMS:', len(problems))
for p in problems:
    print(' ', p)
