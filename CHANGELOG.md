# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/). Versions follow `pubspec.yaml`.

## [Unreleased] — pilot candidate

### Added
- Prosthetic work module: cases, status lifecycle with history, laboratories, payments, waiting-for-placement list with aging, dashboard cards that open the matching list, case PDF.
- Offline outbox with durable queue, stable idempotency keys, replay window, "Renvoyer / Abandonner" for stuck items.
- Session fencing and encrypted, owner-scoped local storage; inactivity lock; screen content hidden in the app switcher.
- Inventory counts, product code lookup, scanner product mode.
- Team invitations (list, resend, revoke) and owner-only guards.
- Minimum-version gate: the server can retire an old build ("Mise à jour requise").
- Evidence search with filters, CSV/PDF exports with unique file names.

### Changed
- Application id is now `com.sterymed.mobile` (provisional until the owner confirms it).
- Every status change on a prosthetic case asks for an optional note; Cancelled and Placed ask for confirmation.
- Settings no longer offers a notification switch: push notifications do not exist yet, alerts are in the app only.
- Launcher icon is the SteryMed mark instead of the Flutter default.

### Fixed
- Layout overflows on small phones with large text (alerts, login footer, lock screen, evidence search, buttons).
- Date pickers no longer crash when the allowed range ends before today.
- A practice could answer 403 everywhere after another practice registered (server, BUG-026).
- Photo and export links now open from outside the server network (server, BUG-010).

### Known limitations (see docs/ANOMALIES.md)
- No push notifications. No "overdue control" alert (the server does not raise it).
- Cycle notes are kept on the phone only (no server route).
- All text is French and hardcoded; the localization files are not wired.
- Certificate pinning is deferred (docs/SECURITY.md).
- iOS is out of scope for the pilot.
