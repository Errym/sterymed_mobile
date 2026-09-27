# Privacy

**Status: skeleton — needs legal/product-owner input.** What follows is
what the code actually does with personal data, as a factual starting
point; the policy language, legal basis, and retention commitments need
someone with the authority to make those commitments.

## What personal data the app handles

- **Patient data**: **no name or other identifying field exists, by
  deliberate design.** `PatientData` (`lib/features/patients/data/models/patient_data.dart`)
  is `{id, reference}` only — `reference` is a server-generated pseudonym
  (e.g. `PAT-000042`), never client-supplied, so a real name can never
  end up there even by accident. Patients can only be *created*
  (generates a fresh anonymous reference) and searched by that reference
  in `PatientSearchScreen`/`PatientPickerSheet` — there is no edit form,
  because there are no name fields to edit (`docs/BACKEND_BUGS.md#bug-008`).
  This is the single biggest fact for whoever answers the legal questions
  below: the app does not process patient names, dates of birth, or any
  other direct identifier — only an internal pseudonym plus the clinical
  procedure/device-usage linkage below.
- **Practitioner/staff identity**: name, email, role — from
  `/v1/auth/login` and `/v1/me`.
- **Device usage records**: label scan → *pseudonymous* patient
  reference → procedure linkage (`LabelUsageData`) — the core
  traceability record the app exists to create. Still worth legal review
  as clinical/health-adjacent data even without a name attached, since
  the procedure + device + timestamp combination is itself sensitive.

## What the code already does (verified, see `docs/SECURITY.md` for detail)

- Session/credentials stored via platform-encrypted storage
  (`flutter_secure_storage`), not plaintext.
- `PiiScrubber` redacts `patient_id`, `practitioner_id`, tokens, and
  passwords before anything is logged or sent to Sentry — so crash
  reports shouldn't leak this data. (Scrubs field *names* it knows
  about, via regex on JSON — not a general-purpose PII detector; a
  differently-shaped payload could still leak something it doesn't
  recognize.) Applied to both Dio logging and `CrashReporter`'s Sentry
  `beforeSend`/`beforeBreadcrumb` hooks — the latter was found and fixed
  2026-09-26 to also scrub `event.exceptions[].value` (not just
  `event.message`), see `docs/SECURITY.md`.
- No analytics/tracking SDK sends patient data anywhere outside the
  `steriqore` backend and (scrubbed) Sentry.

## GDPR / HDS posture

**Neither is a settled position — this is what's code-verified today,
not a compliance sign-off.**

- **GDPR**: the "Export Données" screen (`Routes.dataExports`,
  `DataExportRequestScreen`) exists and is real — `GET/POST
  /v1/data-export-requests` (see `docs/UI_MAPPING.md`), labeled in-app as
  "Portabilité RGPD / ARS" and gated behind `data_exports.manage`
  (owner/admin only, see `docs/ROLE_MATRIX.md`). This is evidence of a
  *portability* mechanism, not a full Article 15/20 compliance audit —
  no one has verified the export's actual contents against what GDPR
  requires a subject-access/portability response to contain, and there's
  no equivalent in-app *erasure* request flow (see the open questions
  below).
- **HDS (Hébergement de Données de Santé — French law, Code de la santé
  publique art. L1111-8)**: applies to whoever hosts the health-adjacent
  data this app creates (device-usage/procedure records — see above),
  not to this mobile app itself. **Undetermined, and not this repo's to
  answer**: no real production/staging host exists yet for `steriqore`
  (`README.md`'s "Known gaps" — `docker-compose.staging.yml` is a
  local-only skeleton), so there is no infrastructure today whose HDS
  certification status could even be checked. This must be resolved
  before any real clinic's data touches a production host, not before —
  whoever stands up that hosting needs to confirm HDS certification (or
  a certified sub-processor) as part of that decision, not retrofit it
  after.

## Open questions only the product owner / legal can answer

- [ ] What's the legal basis for processing patient data here (consent,
  legitimate interest, legal obligation for device traceability)? This
  is likely jurisdiction-specific (France, given the French UI).
- [ ] Data retention period for patient/usage records — is there a
  regulatory minimum (medical device traceability often has one) or
  maximum?
- [ ] Right to erasure / right to access requests — is there a process,
  and does the backend support deleting or exporting a specific
  patient's records on request?
- [ ] Data processing agreement with any third party in the chain
  (Sentry for crash reports, the hosting provider for `steriqore` once a
  real staging/production host exists)?
- [ ] Who is the data controller vs. processor here — the clinic
  (tenant) or the SteryMed operator?
- [ ] Once real hosting exists for `steriqore`: is that host (or its
  provider) HDS-certified? Required before it carries real clinic data —
  see [GDPR / HDS posture](#gdpr--hds-posture) above.
- [ ] Is there (or should there be) an erasure-request flow to match the
  existing export/portability one, or does the traceability/retention
  requirement above override right-to-erasure for this record type?
