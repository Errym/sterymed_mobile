# Localization

## Why French-only

SteryMed Mobile targets French dental clinics. Every user-facing string
in the app is French. There's no requirement or plan for another
language for the pilot.

## How strings actually work today

Two things exist side by side, and only one of them is actually used:

1. **`lib/l10n/app_fr.arb`** (58 entries) → generates
   `AppLocalizations` (`l10n.yaml` is configured, `flutter gen-l10n`
   produces `app_localizations.dart`/`app_localizations_fr.dart`).
   `app.dart` sets `supportedLocales: [Locale('fr')]`.
2. **Every screen hardcodes its French strings directly** —
   `Text('Paramètres')`, `label: 'Se déconnecter'`, and so on, all over
   `lib/features/`.

**`AppLocalizations.of(context)` / `.delegate` is referenced nowhere
outside its own generated file.** The ARB-based infrastructure is
correctly set up but not actually wired into `MaterialApp`'s
`localizationsDelegates` (only the standard Flutter Material/Widgets/
Cupertino delegates are registered — not `AppLocalizations.delegate`)
and no widget calls it. It's dead, not broken — the app works fine
because every string is hardcoded — but it means the ARB file is
disconnected from reality: editing it changes nothing a user sees.

## If a second language is ever needed

Two real options, not a small tweak either way:

- **Use the existing infrastructure**: add
  `AppLocalizations.delegate` to `app.dart`'s
  `localizationsDelegates`, then replace every hardcoded string across
  `lib/features/` and `lib/shared/` with `AppLocalizations.of(context)!.xxx`
  calls, keeping `app_fr.arb` in sync and adding a second `.arb` file
  for the new locale. This is a full sweep of the codebase, not a config
  change — most strings aren't in the ARB file yet (58 entries won't
  cover everything currently hardcoded).
- **Start over with a different i18n approach** (e.g. `easy_localization`
  or similar) if the ARB/gen-l10n workflow isn't preferred — same
  scope of work either way (sweep every screen), just a different
  target API.

Not planned or started; noting the real starting state for whoever picks
this up.
