/// Corner radius scale.
/// Cards are generous pebbles (20), controls (buttons, inputs) are a tighter
/// 14 so an action is never mistaken for a container, chips are full pills.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double control = 14;
  static const double card = 20;
  static const double lg = 22;
  static const double xl = 24;
  static const double pill = 999;
}
