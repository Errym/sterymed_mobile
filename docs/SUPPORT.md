# Support

**Status: structure only — needs product-owner input for every contact
detail.** This was also pre-flight deliverable P10 ("Confirm support
channel + SLA for pilot"), meant to exist before coding started. It
doesn't; this is the shape to fill in.

## Support channel

- [ ] **Channel**: TBD (email? a shared inbox? a chat channel the pilot
  clinic can reach directly?)
- [ ] **Hours**: TBD — does support exist outside clinic hours? A
  sterilization/traceability app failing during active clinic hours is
  a different severity than a weekend outage.
- [ ] **Who's behind it**: TBD — see `docs/RUNBOOK.md`'s on-call section,
  same missing information from the operational angle.

## SLA

- [ ] **Response time** by severity — not yet defined. Suggested
  starting categories (fill with real numbers, not defaults):
  - Critical (data loss risk, app unusable for active sterilization
    workflow): TBD
  - High (a feature broken, workaround exists): TBD
  - Normal (cosmetic, non-blocking): TBD
- [ ] **Resolution time** targets, if any — TBD.

## What the pilot clinic should know before day one

- [ ] How to report an issue (once the channel above is decided).
- [ ] What "known limitations" they should expect going in — this repo
  already has an honest list (`docs/SECURITY.md`'s Known Gaps,
  `docs/OFFLINE_MATRIX.md`'s NOT QUEUED rows, the disabled cycle-
  attachments screen pending BUG-001) — worth summarizing for the
  clinic specifically, in plain language, not engineering terms.
- [ ] Whether there's a status page or any way to check "is this a known
  issue" before reporting a new one — TBD, likely doesn't exist yet for
  a pilot this size.

## Related

- `docs/RUNBOOK.md` — the engineering-facing incident-response
  counterpart to this doc; same missing contact information, different
  audience.
