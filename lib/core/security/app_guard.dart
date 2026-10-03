import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../version/version_gate.dart';
import 'inactivity_lock.dart';

/// Sits above the whole app and covers it when it must not be used:
///
/// 1. the server says this build is too old (blocking, nothing to dismiss);
/// 2. the device was left alone and the user has not unlocked it yet.
///
/// The app underneath stays mounted while locked, so a half-filled form is
/// still there after unlocking.
class AppGuard extends StatelessWidget {
  final VersionGate gate;
  final InactivityLock lock;
  final VoidCallback onSignOut;
  final Widget child;

  const AppGuard({
    super.key,
    required this.gate,
    required this.lock,
    required this.onSignOut,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([gate, lock]),
      builder: (context, _) {
        if (gate.blocked) {
          return UpdateRequiredScreen(
            current: gate.currentVersion,
            required: gate.requiredVersion,
          );
        }
        return Stack(
          children: [
            child,
            if (lock.locked)
              Positioned.fill(
                child: LockScreen(
                  onUnlock: lock.unlock,
                  onSignOut: () {
                    lock.clear();
                    onSignOut();
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Mise à jour requise": nothing else on screen, no way around it.
class UpdateRequiredScreen extends StatelessWidget {
  final String current;
  final String? required;
  const UpdateRequiredScreen({super.key, required this.current, this.required});

  @override
  Widget build(BuildContext context) {
    final known =
        required != null &&
        AppVersion.parse(required) != null &&
        (AppVersion.parse(required)!.first < 999999);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        key: const Key('update-required'),
        color: AppColors.backgroundApp,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.system_update_alt,
                      size: 56,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Mise à jour requise',
                      textAlign: TextAlign.center,
                      style: AppTypography.pageTitle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Cette version de SteryMed ($current) n\'est plus acceptée '
                      'par le serveur${known ? ' : la version $required ou '
                                'plus récente est nécessaire' : ''}. '
                      'Installez la dernière version proposée par le '
                      'responsable du cabinet pour continuer.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Vos données non envoyées sont conservées sur cet appareil.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown over the app after it was left alone: unlock with the device's own
/// fingerprint, face or PIN, or sign out.
class LockScreen extends StatefulWidget {
  final Future<bool> Function() onUnlock;
  final VoidCallback onSignOut;
  const LockScreen({
    super.key,
    required this.onUnlock,
    required this.onSignOut,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Ask straight away: most of the time that is all the user has to do.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final ok = await widget.onUnlock();
    if (!mounted) return;
    setState(() => _failed = !ok);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        key: const Key('lock-screen'),
        color: AppColors.backgroundApp,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Session verrouillée',
                      textAlign: TextAlign.center,
                      style: AppTypography.pageTitle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _failed
                          ? 'Déverrouillage non confirmé. Réessayez.'
                          : 'L\'appareil est resté inutilisé. Confirmez que '
                                'c\'est bien vous.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      key: const Key('lock-unlock'),
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Déverrouiller'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      key: const Key('lock-sign-out'),
                      onPressed: widget.onSignOut,
                      child: const Text('Se déconnecter'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
