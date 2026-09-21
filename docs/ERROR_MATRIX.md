# Error Matrix

Every error code the mobile app must handle, with the exact message from the server.

| Status | error.code | Message | Trigger | Mobile handling |
|---|---|---|---|---|
| 401 | `INVALID_CREDENTIALS` | "These credentials do not match our records." | Wrong email/password on login | Toast, keep form |
| 401 | `UNAUTHENTICATED` | "Authentication is required." | Missing/expired bearer | Logout, redirect to login |
| 401 | `TENANT_NOT_FOUND` | "No practice matches this identifier." | Unknown tenant_slug on login | Toast, keep form |
| 401 | `TENANT_MEMBERSHIP_PENDING` | "This invitation has not been accepted yet." | Member status is `invited` | Toast, contact admin |
| 403 | `forbidden` | "This action is unauthorized." | Insufficient role | Toast, block action |
| 404 | `NOT_FOUND` | "The route api/v1/... could not be found." | Unknown route | Bug — fix URL |
| 404 | `NOT_FOUND` | "No query results for model [App\\Domain\\...\\Model] <id>" | Valid route, missing resource | Empty state, back |
| 409 | `conflict` | "Enregistré précédemment." | Idempotency replay | Toast, mark done |
| 422 | `VALIDATION_FAILED` | "The given data was invalid." | Field validation | Show field errors |
| 429 | `RATE_LIMITED` | "Trop de requêtes. Réessayez dans un instant." | Rate limit hit | Backoff, retry |
| 500 | `SERVER_ERROR` | "Erreur serveur. Réessayez plus tard." | Unhandled exception | Sentry, retry |

## Non-HTTP errors (client-side)

| Code | French message | Trigger |
|---|---|---|
| `network_error` | "Connexion impossible. Vérifiez votre réseau." | No connectivity |
| `timeout` | "Le délai de connexion a expiré." | Timeout |
| `unknown` | "Une erreur est survenue." | Fallback |

## Real captures

- 401 wrong password: `docs/captures/errors/401_wrong_password.json`
- 401 no token: `docs/captures/errors/401_no_token.json`
- 404 unknown route: `docs/captures/errors/404_unknown_route.json`
- 404 unknown resource: `docs/captures/errors/404_unknown_resource.json`
- 422 missing reason: `docs/captures/errors/422_missing_reason.json`
- 422 invalid login: `docs/captures/errors/422_invalid_login.json`

## Known issues

- Some 422 `details` are in English (e.g., "The selected batch id is invalid."). Tracked in `BACKEND_BUGS.md #009`.
- Real 409 capture requires seeded stock level. Deferred to Phase 3.
