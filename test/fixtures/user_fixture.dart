import 'package:steriymed_mobile/features/auth/data/models/user_data.dart';
import 'package:steriymed_mobile/features/auth/data/models/tenant_data.dart';
import 'package:steriymed_mobile/features/auth/data/models/login_response.dart';

const testUser = UserData(
  id: 'user-1',
  name: 'Dr Test',
  email: 'test@test.com',
  role: 'owner',
);

const testAdmin = UserData(
  id: 'user-2',
  name: 'Admin',
  email: 'admin@test.com',
  role: 'owner',
);

const testTenant = TenantData(
  id: 'tenant-1',
  name: 'My Practice',
  slug: 'my-practice',
);

const testLoginResponse = LoginResponse(
  token: 'test-token',
  tokenType: 'Bearer',
  user: testUser,
  tenant: testTenant,
);
