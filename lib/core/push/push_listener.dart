import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/widgets/feedback/app_snackbar.dart';
import 'push_service.dart';

/// Turns notifications into something a person can act on:
///  - tapped from the notification shade → open the screen it names;
///  - arriving while the app is open → a banner with a "Voir" shortcut (the
///    system shows nothing in that case).
///
/// Only routes on the app's own allow-list are ever opened (see
/// `PushPayload.safeRoute`); anything else is ignored.
class PushListener extends StatefulWidget {
  final Stream<PushEvent> events;
  final bool Function() hasSession;
  final void Function(String route) onOpen;
  final Widget child;

  const PushListener({
    super.key,
    required this.events,
    required this.hasSession,
    required this.onOpen,
    required this.child,
  });

  @override
  State<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends State<PushListener> {
  StreamSubscription<PushEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.events.listen(_handle);
  }

  void _handle(PushEvent event) {
    if (!mounted || !widget.hasSession()) return;
    final route = event.payload.safeRoute;
    if (event.opened) {
      if (route != null) widget.onOpen(route);
      return;
    }
    final body = event.payload.body;
    if (body.isEmpty) return;
    AppSnackbar.show(
      context,
      body,
      kind: SnackKind.warning,
      actionLabel: route == null ? null : 'Voir',
      onAction: route == null ? null : () => widget.onOpen(route),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
