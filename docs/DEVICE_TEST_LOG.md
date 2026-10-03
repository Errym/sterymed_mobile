# Device Test Log

Real, physical-device test runs only — not simulator/emulator, not
`flutter test` (that's `docs/TESTING.md`). Referenced from
`docs/OFFLINE_MATRIX.md` ("log every offline-queue test here"). Scenarios
stay unverified until a real entry exists here.

## Setup

- Physical test device: Samsung S928B, serial `RZCXB0F5S9Z`, via USB.
- Backend: local `steriqore` Docker stack (`docker compose up -d`),
  exposed to the phone via `adb -s RZCXB0F5S9Z reverse tcp:8010 tcp:8010`
  — not LAN/WiFi (Windows Firewall has no inbound rule for port 8010 from
  other LAN devices).
- `adb reverse` does not survive every rebuild/reinstall — re-assert it
  before every on-device test session.
- Screen timeout must be raised before a test session:
  `adb shell settings put system screen_off_timeout 1800000` — a
  locked/dimmed screen silently stops touch input mid-test with no clear
  error.
- Prefer `adb shell uiautomator dump` → grep the target's real `bounds=`
  over screenshot-derived tap coordinates — this device's soft-keyboard
  layout shifts and autofill overlays make blind coordinate taps
  unreliable.

## Known device-testing issue — fixed in code, not yet re-verified on-device

**Hardware back button exits the app instead of navigating within it.**
Reproduced 3+ times from at least the Cycles list, Purchase Orders list,
and Suppliers list screens — pressing the Android hardware back button
from these top-level screens pops out of the app entirely to whatever was
last in the multitasking stack, rather than navigating up within the app
shell.

**Root cause found (2026-09-27, final QA pass):** `BottomNavBar` switches
tabs via `context.go()`, which replaces go_router's entire stack rather
than pushing — so every top-level tab has nothing left to pop, and with
no `PopScope`, Android's back button fell straight through to the OS.
Not specific to Cycles/Purchase Orders/Suppliers; the same root cause
applies to every top-level tab, those were just the screens tried.

**Fix**: `ShellScreen` (`lib/features/shell/presentation/screens/shell_screen.dart`)
now wraps its `Scaffold` in a `PopScope<Object?>` — `canPop` is only true
on the Accueil (dashboard) tab; anywhere else, back navigates to
dashboard instead of exiting. Covered by
`test/widget/shell_screen_back_button_test.dart` (2 tests, passing).
**Still needs a real-device re-run** — this session had no physical
Android device connected (`adb devices` empty) to confirm the fix
against actual hardware back-button behavior, only the widget-test-level
`PopScope` interception logic. Re-run the Cycles/Purchase
Orders/Suppliers repro steps above on the S928B before calling this
closed.

## Log format

Each entry: date, tester, build/commit, scenario, steps, result.

```
### 2026-MM-DD — <scenario name>
- Build/commit: <git sha or build number>
- Tester: <name>
- Steps: <what was actually done, e.g. "airplane mode ON, issued stock,
  airplane mode OFF, confirmed sync">
- Result: PASS / FAIL — <what was observed, screenshots/adb logcat
  excerpts if a failure>
```

## Entries

*(none yet — every offline-queue scenario in `docs/OFFLINE_MATRIX.md` and
the app-kill-and-relaunch scenario remain unverified on a real device; this is real, tracked debt, not
fabricated as done)*

## Device steps owed for Phase 6 and Phase 7 (no phone was attached on 2026-10-02)

Everything below is covered by tests and, for the server side, by
`scripts/verify_prosthetic_journey.py` (ALL PASS). These steps need a physical
Android phone and cannot be closed by tests. Record each one as an entry above.

| Task | Step | Pass when |
|---|---|---|
| T6.6 | Create a prosthetic case with a stopwatch, from the home screen to the saved case | under 2 minutes; the time is written in the entry |
| T6.8 | Add a photo to a case with the camera; repeat with the network cut and restored | upload shows progress, a failure shows Réessayer, the photo opens afterwards |
| T6.9 | Detail screen, Imprimer / Exporter en PDF | the PDF opens on the phone and shows the case, history and payment |
| T7.4 | Cahier journey 5: alert, then journal, then export | the exported file is opened on the phone |
| T7.5 | Set `MIN_APP_VERSION` above the installed build on the server, open the app | the "Mise à jour requise" screen blocks the app; clearing the setting lets it in again |
| T7.6 | Leave the app in the background past the lock delay | the lock screen asks for fingerprint / PIN; the app switcher shows no content |
| T7.7 | Open the home, list and detail screens on a normal connection | each is usable in under 2 seconds; write down the phone and network |

### 2026-10-02 — API time per screen (server side only, not a phone run)
- Build/commit: dev backend, practice seeded by `scripts/seed_web_journeys.py`
- Tester: `python scripts/measure_api_times.py --runs 5` on the dev machine
- Result: PASS — slowest screen (Prothèses liste, 2 calls) 0.29 s, home 0.31 s
  worst case; all 13 first-load screens under the 2 s budget. This covers the
  network + API part only; T7.7 still needs the phone's render time.
