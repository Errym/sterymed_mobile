# Testing Strategy — SteryMed Mobile

**Last updated:** 2026-09-18

## Run tests

    flutter test
    flutter test --coverage
    genhtml coverage/lcov.info -o coverage/html

## Test matrix

| Layer | File | Covers |
|-------|------|--------|
| Unit | error_mapper_test.dart | Dio → ApiException |
| Unit | validators_test.dart | required, email, password |
| Unit | pii_scrubber_test.dart | token/password/ID redaction |
| Unit | idempotency_key_test.dart | UUID v4 format |
| Unit | debouncer_test.dart | Debouncer timing |
| Bloc | auth_bloc_test.dart | login, 401, session restore, logout |
| Bloc | scanner_bloc_test.dart | scan, blocked, error, torch, reset |
| Bloc | cycle_detail_bloc_test.dart | load, partial failure |
| Bloc | dashboard_cubit_test.dart | load, error |
| Bloc | stock_issue_bloc_test.dart | success, 422 |
| Bloc | alert_list_bloc_test.dart | load, error, severity grouping |
| Widget | login_screen_test.dart | render, validation, submit |
| Widget | alert_list_screen_test.dart | severity groups, empty |

## Not yet tested

- Integration journeys (Phase 8)
- Golden tests (Phase 5)
- Offline sync flow (Phase 2)

## Conventions

- Use `mocktail`, not `mockito`.
- Test names start with a verb.
- Never commit a test that only passes locally.
