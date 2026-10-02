import 'asgardeo_auth_service.dart';

class AuthService {
  final AsgardeoAuthService _asgardeoAuthService = AsgardeoAuthService();

  Future<bool> loginWithHostedWeb() async {
    return await _asgardeoAuthService.loginWithHostedWeb();
  }
}