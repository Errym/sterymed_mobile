# Demo Script

**Status: skeleton — the product owner fills this in before recording**
(Day 54). Structure below follows the master plan's six journeys, with
one flagged as no longer possible.

## Journeys (per the original plan)

1. **Login → scan → record usage** — [ ] script TBD
2. **Full cycle lifecycle** — [ ] script TBD
3. ~~**Prosthetic case: create → transitions → waiting for placement →
   payment check**~~ — **not possible.** This module was removed per
   `docs/adr/0010-prosthetic-deferred.md`; no code exists for it. This
   journey needs to either be dropped from the demo or replaced with
   something that reflects what the app actually does (e.g. a second
   real journey — Stock or Purchases both have complete implementations
   worth showing instead).
4. **Quick stock issue** — [ ] script TBD
5. **Alert resolve** — [ ] script TBD
6. **Offline → sync → conflict** — [ ] script TBD. This one has the most
   real evidence behind it already — see `docs/DAILY_LOG.md` and
   `test/unit/storage/sync_engine_test.dart` for the 409/422
   manual-review behavior this journey would demonstrate.

Plus: an error-handling montage (per the plan) — [ ] TBD.

## Open questions for the product owner

- [ ] Replace or drop journey #3 (prosthetic)?
- [ ] Real device or simulator/emulator for recording?
- [ ] Which pilot-tenant test account(s) to use — see `.env.local` for
  what currently exists locally; a real demo likely wants dedicated,
  clean seed data instead of ad-hoc dev-tenant state.
- [ ] Target length / format (single take vs. edited segments per
  journey)?
