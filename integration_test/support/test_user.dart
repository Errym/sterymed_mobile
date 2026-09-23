/// Test credentials for the local `steriqore` dev backend's demo2 tenant.
/// Mirrors `.env.local` (gitignored) — kept in sync manually since
/// integration tests can't read a dotenv file without an extra
/// dependency, and these are already non-secret local dev/demo values.
abstract final class TestUser {
  static const tenantSlug = 'demo2';

  static const adminEmail = 'admin2@steriqore.local';
  static const adminPassword = 'password';

  static const staffEmail = 'staff2@steriqore.local';
  static const staffPassword = 'password';
}
