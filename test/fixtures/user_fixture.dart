import 'package:steriymed_mobile/features/auth/data/models/user_data.dart';
import 'package:steriymed_mobile/features/auth/data/models/tenant_data.dart';
import 'package:steriymed_mobile/features/auth/data/models/login_response.dart';

final testUser = const UserData(
  id: 'user-1',
  name: 'Dr Test',
  email: 'test@test.com',
  role: 'owner',
);

final testTenant = TenantData(
  id: 'tenant-1',
  name: 'My Practice',
  slug: 'my-practice',
);

final testLoginResponse = LoginResponse(
  token: 'test-token',
  tokenType: 'Bearer',
  user: testUser,
  tenant: testTenant,
);
