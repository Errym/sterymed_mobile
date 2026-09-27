# Demo Script

**Status: skeleton — the product owner fills in delivery specifics
(recording format, which test account) before recording.** Structure
below follows the master plan's six journeys — all six are real and
demoable today; journey #3 was briefly blocked (see below) but the
module was rebuilt for real since.

## Journeys (per the original plan)

1. **Login → scan → record usage** — [ ] script TBD. Real, tested:
   `test/widget/label_detail_screen_test.dart`, `test/bloc/label_usage_bloc_test.dart`.
2. **Full cycle lifecycle** — [ ] script TBD. Real, tested:
   `integration_test/journeys/cycle_lifecycle_journey_test.dart` (a real
   integration test already exists for this one — could double as the
   demo's actual walkthrough).
3. **Prosthetic case: create → transitions → waiting for placement →
   payment check** — **real and demoable now.** Was briefly blocked per
   `docs/adr/0010-prosthetic-deferred.md` (no backend domain existed at
   the time); rebuilt for real per
   `docs/adr/0011-prosthetic-module-adopted.md` (supersedes 0010) — see
   `docs/PROSTHETIC_MODULE.md`. The exact journey the original plan
   asked for now maps directly onto real screens: create
   (`Routes.prostheticCreate`) → status transitions with the
   placed/cancelled confirmation gate (`prosthetic_case_detail_screen.dart`)
   → waiting-for-placement list (`Routes.prostheticWaitingPlacement`) →
   payment section (editable for `prosthetic_payments.manage`, read-only
   status otherwise). Tested:
   `test/widget/prosthetic_form_test.dart`, `prosthetic_case_detail_test.dart`,
   `waiting_placement_screen_test.dart`, `test/bloc/prosthetic_status_bloc_test.dart`,
   `prosthetic_payment_bloc_test.dart`. [ ] script TBD.
4. **Quick stock issue** — [ ] script TBD.
5. **Alert resolve** — [ ] script TBD.
6. **Offline → sync → conflict** — [ ] script TBD. This one has the most
   real evidence behind it already — see `docs/DAILY_LOG.md` and
   `test/unit/storage/sync_engine_test.dart` for the 409/422
   manual-review behavior this journey would demonstrate. No real device
   test of the actual offline→reconnect flow is logged yet though — see
   `docs/DEVICE_TEST_LOG.md` (empty) — worth doing before relying on this
   as a live demo rather than a narrated code-walkthrough.

Plus: an error-handling montage (per the plan) — [ ] TBD.

## Open questions for the product owner

- [ ] Real device or simulator/emulator for recording? (If a real
  device: mind the known hardware-back-button-exits-the-app issue
  documented in `docs/DEVICE_TEST_LOG.md` — avoid it during recording,
  use in-app navigation.)
- [ ] Which pilot-tenant test account(s) to use — see `.env.local` for
  what currently exists locally; a real demo likely wants dedicated,
  clean seed data instead of ad-hoc dev-tenant state.
- [ ] Target length / format (single take vs. edited segments per
  journey)?
