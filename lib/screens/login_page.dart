import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/asgardeo_auth_service.dart';
import '../services/user_session.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import '../features/scanner/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AsgardeoAuthService _asgardeoAuthService = AsgardeoAuthService();
  final ApiService _apiService = ApiService();

  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;

  Future<void> _signIn() async {
    final usernameOrEmail = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (usernameOrEmail.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _asgardeoAuthService.manualLogin(
      username: usernameOrEmail,
      password: password,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logged in successfully!")),
      );
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Authentication failed")),
      );
    }
  }

  Future<void> _loginWithSocial(String providerName) async {
    setState(() => _isLoading = true);
    if (providerName == 'Google') {
      final googleDetails = await _asgardeoAuthService.getGoogleAccountDetails();
      setState(() => _isLoading = false);

      if (googleDetails == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Google account selection cancelled.")),
          );
        }
        return;
      }

      final googleEmail = googleDetails['email'] ?? '';
      final googleName = googleEmail.contains('@') ? googleEmail.split('@')[0] : (googleDetails['name'] ?? 'user');

      final checkResult = await _apiService.checkUserExists(googleEmail);

      if (!mounted) return;

      if (checkResult['exists'] == true) {
        final username = checkResult['user']?['username'] ?? googleName;
        await UserSession.saveUser(email: googleEmail, username: username);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome back, $username!")),
        );
        context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No account found for $googleEmail. Redirecting to signup...")),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignupPage(
              initialEmail: googleEmail,
              initialUsername: googleName,
            ),
          ),
        );
      }
    } else {
      final success = await _asgardeoAuthService.loginWithSocialProvider(providerName);
      setState(() => _isLoading = false);
      if (success && mounted) {
        context.go('/dashboard');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to sign in with $providerName")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.arrow_back_ios, size: 20),
              const SizedBox(height: 30),
              const Text("Welcome back", 
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const Text("Log in to your account", 
                style: TextStyle(fontSize: 16, color: Colors.black54)),
              const SizedBox(height: 40),
              
              const Text("Email or Username", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: "Enter your email or username",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              
              const Text("Password", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v!)),
                      const Text("Remember me"),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                    ),
                    child: const Text("Forgot password", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056D2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Sign in", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 25),
              
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupPage())),
                  child: RichText(
                    text: const TextSpan(
                      text: "Don't have an account ? ",
                      style: TextStyle(color: Colors.black54),
                      children: [
                        TextSpan(text: "Register", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("OR")),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 30),
              
              // Social Logins (Google & GitHub)
              GestureDetector(
                onTap: _isLoading ? null : () => _loginWithSocial('Google'),
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.g_mobiledata, color: Colors.red, size: 30),
                      SizedBox(width: 10),
                      Text("Sign In With Google", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: _isLoading ? null : () => _loginWithSocial('GitHub'),
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.code, color: Colors.black, size: 24),
                      SizedBox(width: 10),
                      Text("Sign In With GitHub", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}