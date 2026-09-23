# Data Migration & Rollback Plan

**Status: skeleton — needs product-owner input.** This was originally a
pre-flight (P11) deliverable per the master plan ("Confirm data migration
+ rollback plan"), meant to exist *before* coding started. It doesn't;
this is the outline to fill in, not the plan itself.

## Open questions only the product owner can answer

- [ ] **Is there an existing system being replaced?** Paper logs, a
  spreadsheet, another software product? If nothing existing is being
  migrated (pilot clinics start on SteryMed from zero), most of this doc
  collapses to "N/A" and that should be stated explicitly, not left
  blank.
- [ ] If yes: what data needs to come across (patients, devices, cycle
  history, stock levels) and from what format/source?
- [ ] Who owns the go/no-go decision for a migration attempt, and what's
  the acceptance criteria before calling it successful?
- [ ] **Rollback plan**: if a migration corrupts or loses data, what's
  the recovery path? (`docs/BACKUP_RESTORE.md` in the `steriqore` repo
  documents the underlying backup/restore mechanism this would build on
  — a drilled, working DB + media restore — but the migration-specific
  rollback trigger and decision process still needs defining here.)
- [ ] Any regulatory/compliance retention requirement on the data being
  replaced (medical device traceability records often have legal minimum
  retention periods) that constrains how/whether old records can be
  discarded post-migration?

## What exists today that this can build on

- `steriqore`'s backup/restore mechanism is drilled and documented
  (`docs/BACKUP_RESTORE.md` in that repo) — DB dump + S3/MinIO media
  mirror, both independently destroy/restore tested.
- No import/migration tooling exists in either repo yet — this would be
  new work once the questions above are answered.
