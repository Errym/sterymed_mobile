// This stub was named after a WaitingPlacementBloc that doesn't exist —
// same "phantom bloc" situation as goods_receipt_bloc_test.dart,
// label_usage_bloc_test.dart, and the 3 prosthetic_*_bloc_test.dart files
// (Task 2). ProstheticWaitingPlacementScreen (the real feature this name
// points at) is a plain StatefulWidget doing setState + direct
// getIt<ProstheticRepository>() calls, already fully covered — load, empty
// state, error+retry, and cursor-based load-more — by
// test/widget/waiting_placement_screen_test.dart. Nothing distinct is left
// to test under this name; kept as a real (non-empty, compiling) file
// rather than deleted, since removing test/**/*.dart files wasn't asked
// for and this documents *why* it's intentionally empty of assertions,
// not an oversight.
void main() {}
