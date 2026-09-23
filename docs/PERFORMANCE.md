# Performance

**Status: skeleton — the measured targets need a real device, which is
outside what this session can do.**

## Targets (from the master plan, Day 47)

- [ ] Shell screens < 2s on 4G mid-range Android — **not measured**,
  needs a real device.
- [ ] Scan → detail < 2s on mid-range Android — **not measured**.
- ~~Prosthetic waiting list < 2s~~ — N/A, module void (ADR-0010).

## What's done code-side (verified in the repo, not measured on-device)

These are the structural practices the plan calls for; whether they
translate to the actual millisecond targets above still needs a device:

- Every list uses builder-based rendering + cursor pagination
  (`CursorPaginatedList<T>`) — Cycles and Purchase Orders confirmed this
  session; a handful of lower-traffic reference-data lists (Devices,
  Sites, Suppliers, Team, Patients, Non-Conformities) still use a flat
  page-size cap instead, a known, deliberately-deferred gap.
- Debounced search (300ms) on product list and stock level list blocs
  (`Debouncer`, `lib/core/utils/debouncer.dart`), following the same
  pattern already used by patient search.
- Dispose audit done — found and fixed real leaks (recreated
  `TextEditingController`s in `PatientPickerSheet`,
  `CycleItemsScreen`/`CycleControlTestsScreen` dialog controllers not
  disposed on early-exit paths).

## Open questions for whoever runs the device pass

- [ ] What counts as "mid-range Android" for this measurement — a
  specific device/spec floor needs picking.
- [ ] Is image caching actually needed anywhere in this app? (The plan
  lists it under Day 47, but this app doesn't display much user-uploaded
  imagery outside cycle attachments, which are currently disabled
  pending BUG-001 — worth confirming this line item still applies before
  spending time on it.)
