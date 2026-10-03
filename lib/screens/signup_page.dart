import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/asgardeo_auth_service.dart';
import '../services/user_session.dart';
import 'otp_verification_page.dart';
import '../features/scanner/api_service.dart';

class SignupPage extends StatefulWidget {
  final String? initialEmail;
  final String? initialUsername;

  const SignupPage({
    super.key,
    this.initialEmail,
    this.initialUsername,
  });

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final AsgardeoAuthService _asgardeoAuthService = AsgardeoAuthService();
  final ApiService _apiService = ApiService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.initialUsername != null && widget.initialUsername!.isNotEmpty) {
      _usernameController.text = widget.initialUsername!;
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
          SnackBar(content: Text("Account already exists for $googleEmail! Logged in.")),
        );
        context.go('/dashboard');
      } else {
        await _apiService.registerUser(
          email: googleEmail,
          username: googleName,
          authProvider: 'google',
        );

        final result = await _asgardeoAuthService.signUp(
          username: googleName,
          email: googleEmail,
          password: "GoogleAuth_${DateTime.now().millisecondsSinceEpoch}",
        );

        await UserSession.saveUser(email: googleEmail, username: googleName);

        if (!mounted) return;

        if (result["success"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Welcome $googleName!")),
          );
          context.go('/dashboard');
        } else {
          context.go('/dashboard');
        }
      }
    } else {
      final success = await _asgardeoAuthService.loginWithSocialProvider(providerName);
      setState(() => _isLoading = false);
      if (success && mounted) {
        context.go('/dashboard');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to sign up with $providerName")),
        );
      }
    }
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _asgardeoAuthService.signUp(
      username: username,
      email: email,
      password: password,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result["success"] == true) {
      await UserSession.saveUser(email: email, username: username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Registration successful! Welcome!")),
      );
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Registration failed")),
      );
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
              IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 30),
              const Text("Create an account", 
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const Text("Welcome! Please enter your details.", 
                style: TextStyle(fontSize: 16, color: Colors.black54)),
              const SizedBox(height: 40),

              const Text("Username", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                maxLength: 16,
                decoration: InputDecoration(
                  hintText: "Enter your username (max 16 chars)",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 20),

              const Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
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
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056D2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Sign up", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
              const Center(child: Text("Or sign up with", style: TextStyle(color: Colors.grey))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialIcon(Icons.g_mobiledata, color: Colors.red, onTap: _isLoading ? null : () => _loginWithSocial('Google')),
                  const SizedBox(width: 20),
                  _socialIcon(Icons.code, color: Colors.black, onTap: _isLoading ? null : () => _loginWithSocial('GitHub')),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: const TextSpan(
                      text: "Already have an account ? ",
                      style: TextStyle(color: Colors.black54),
                      children: [
                        TextSpan(text: "Sign in", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialIcon(IconData icon, {Color color = Colors.black, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}