# Privacy

**Status: skeleton — needs legal/product-owner input.** What follows is
what the code actually does with personal data, as a factual starting
point; the policy language, legal basis, and retention commitments need
someone with the authority to make those commitments.

## What personal data the app handles

- **Patient data**: name, and whatever `PatientData`/`patient_create_request`
  capture — created/edited via `PatientFormSheet`, viewed in
  `PatientSearchScreen`. This is clinical/health-adjacent data (tied to
  device usage on a specific patient) — treat as sensitive by default.
- **Practitioner/staff identity**: name, email, role — from
  `/v1/auth/login` and `/v1/me`.
- **Device usage records**: label scan → patient → procedure linkage
  (`LabelUsageData`) — the core traceability record the app exists to
  create.

## What the code already does (verified, see `docs/SECURITY.md` for detail)

- Session/credentials stored via platform-encrypted storage
  (`flutter_secure_storage`), not plaintext.
- `PiiScrubber` redacts `patient_id`, `practitioner_id`, tokens, and
  passwords before anything is logged or sent to Sentry — so crash
  reports shouldn't leak this data. (Scrubs field *names* it knows
  about, via regex on JSON — not a general-purpose PII detector; a
  differently-shaped payload could still leak something it doesn't
  recognize.)
- No analytics/tracking SDK sends patient data anywhere outside the
  `steriqore` backend and (scrubbed) Sentry.

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
