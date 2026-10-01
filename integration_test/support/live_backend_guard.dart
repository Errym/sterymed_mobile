/// Every journey in `integration_test/journeys/` drives the real app
/// against the real, isolated clinic fixture backend (see each journey's
/// header for its generated dart-define file) — there
/// is no mock/fake backend involved, unlike `test/`. That makes them
/// unsafe to run unattended: `mobile-test.yml` only runs `flutter test`
/// (which does not pick up `integration_test/` by default), but recent
/// Flutter/`integration_test` versions can also run these via a plain
/// `flutter test integration_test/...` invocation on desktop, which would
/// silently hang or fail here with no backend reachable.
///
/// `kRunLiveIntegrationTests` requires an explicit opt-in
/// (`--dart-define=RUN_LIVE_INTEGRATION_TESTS=true`) in addition to
/// whatever `API_BASE_URL`/`ENV` defines a journey's own header already
/// asks for, so a bare `flutter test integration_test/...` skips every
/// journey instead of trying to reach a backend that may not exist.
/// Implemented journeys also verify the fixture server's identity before boot.
const bool kRunLiveIntegrationTests =
    bool.fromEnvironment('RUN_LIVE_INTEGRATION_TESTS');

/// `testWidgets`'s `skip` parameter is `bool?`, not a reason string — use
/// this in every journey as `skip: kSkipUnlessLiveBackend`. The "why" for
/// anyone reading skipped output lives in this file's doc comment and in
/// each journey's own header comment, not in the skip flag itself.
const bool kSkipUnlessLiveBackend = !kRunLiveIntegrationTests;
