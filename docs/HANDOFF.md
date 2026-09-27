# Handoff

**2026-09-26.** For whoever picks this project up next — where to look,
what's actually done, and what genuinely still needs a human.

## Start here

1. Root [`README.md`](../README.md) — setup, running against a local
   `steriqore` backend, testing, CI.
2. [`docs/PILOT_READINESS.md`](PILOT_READINESS.md) — the current, honest
   go/no-go read: what's verified, what's partial, what needs a real
   device.
3. [`docs/README.md`](README.md) — explains this folder's own structure:
   6 user-facing + 3 internal docs the original plan called for by name,
   plus a longer tail of working documents.

## What this app is

A Flutter client for sterilization traceability in dental clinics —
scanning device labels, recording sterilization cycles, tracking stock
and purchase orders, and a prosthetic-case workflow, with an offline
outbox for when the clinic's connection drops. Backend is a separate
Laravel repo, `steriqore`.

## What's real and working

Everything in [`docs/ARCHITECTURE.md`](ARCHITECTURE.md)'s feature list is
built and has at least some test coverage — 51/51 test files are real
(`docs/TESTING.md`), `flutter analyze --fatal-infos` is clean, and CI
enforces both on every push. The prosthetic module
([`docs/PROSTHETIC_MODULE.md`](PROSTHETIC_MODULE.md)) is the newest
addition — real and live per ADR 0011, not the deferred module ADR 0010
describes; if you find a stale reference elsewhere claiming it doesn't
exist, that reference is wrong, not the module.

## What genuinely still needs a human, not more code

These can't be closed from a terminal — see
[`docs/PILOT_READINESS.md`](PILOT_READINESS.md#what-still-blocks-a-clean-go)
for the full list with citations:

- A real device pass (offline queue survives app-kill, reconnect syncs
  correctly, a dual-client web/mobile coherence check) —
  [`docs/DEVICE_TEST_LOG.md`](DEVICE_TEST_LOG.md) has the setup steps and
  known gotchas (including a real, unfixed bug: the hardware back button
  exits the app instead of navigating within it), but zero logged runs.
- Product-owner/legal input for [`docs/PRIVACY.md`](PRIVACY.md) (legal
  basis, retention, data-controller question), on-call contacts for
  [`docs/RUNBOOK.md`](RUNBOOK.md), and whether any migration applies at
  all for [`docs/MIGRATION.md`](MIGRATION.md) — all three are
  intentionally left as open questions, not guessed at.
- A release signing pipeline for either platform
  ([`docs/CICD.md`](CICD.md)) and an iOS `Podfile` fix — both known,
  tracked, not started.

## Where the real backend gaps are tracked

[`docs/BACKEND_BUGS.md`](BACKEND_BUGS.md) is the detailed, curl-verified
log (25 entries) of every real backend issue found and how mobile
worked around or fixed it — never silently. Read
[`docs/MISSING_FEATURES.md`](MISSING_FEATURES.md) first for the short
index of what's still open before diving into the full log.

## How this codebase expects you to work

A few standing rules that shaped every fix in this repo, worth carrying
forward:

- **If the backend is wrong, document it — don't route around it
  silently.** Every workaround in the code has a comment pointing at its
  `BACKEND_BUGS.md` entry.
- **Verify against the real, live backend before trusting a claim about
  it** — the backend's own `docs/openapi.yaml` is confirmed stale; use
  `GET /docs/api.json` against a running instance instead, and
  `test/unit/contract/` for the automated version of that check.
- **A doc claim needs a citable artifact** — a passing test, a live
  curl/device result, or a code read called out as such, not "should
  work." Several docs in this repo were wrong in exactly the way this
  rule exists to prevent (see `docs/DAILY_LOG.md`'s Gate audits and this
  session's documentation-staleness fixes) — check a doc's own claims
  against the current code before trusting it fully, the same way this
  handoff had to.
- **`flutter_test` has real environment quirks** worth knowing before
  writing a new widget test — see `docs/TESTING.md`'s "flutter_test
  environment gotchas" section (real-Hive-in-a-widget-test hangs,
  upper-cased label text, lazy off-screen mounting, snackbar-after-pop
  assertions).

## Who to ask

Not something this codebase or session knows — see
[`docs/RUNBOOK.md`](RUNBOOK.md)'s open support-contact questions and
[`docs/SUPPORT.md`](SUPPORT.md).
