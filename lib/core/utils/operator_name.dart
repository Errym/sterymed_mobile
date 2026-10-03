import '../../di/di.dart';
import '../storage/session_store.dart';

/// The name a movement is recorded under, for the "enregistré sous le nom de"
/// notes. Falls back to a neutral word when no session is available (it never
/// throws: a note must not be able to break a form).
String operatorName() {
  if (!getIt.isRegistered<SessionStore>()) return "l'opérateur";
  final name = getIt<SessionStore>().userName;
  return (name == null || name.trim().isEmpty) ? "l'opérateur" : name;
}
