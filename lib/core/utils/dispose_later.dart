import 'package:flutter/widgets.dart';

/// Disposes a controller that was handed to a dialog, once the dialog's exit
/// animation is over. Disposing it the moment `showDialog` returns races that
/// animation, which still rebuilds the field with the (dead) controller.
void disposeControllerLater(TextEditingController controller) {
  Future<void>.delayed(
    const Duration(milliseconds: 500),
    controller.dispose,
  );
}
