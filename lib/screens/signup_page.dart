import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:documate/core/widgets/bouncing_button.dart';
import 'package:documate/services/asgardeo_auth_service.dart';
import 'package:documate/features/scanner/api_service.dart';
import 'package:documate/services/user_session.dart';
import 'package:go_router/go_router.dart';

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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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
        if (!mounted) return;
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BouncingPressable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                "Create an account", 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30, 
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Welcome! Please enter your details.", 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, 
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),

              Text(
                "Username", 
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                maxLength: 16,
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Enter your username (max 16 chars)",
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  counterText: "",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF0056D2), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Email", 
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Enter your email",
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF0056D2), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Password", 
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Create a password",
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF0056D2), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Tactile Primary Sign Up Button
              BouncingPressable(
                onTap: _isLoading ? null : _register,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0056D2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0056D2).withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            "Sign up", 
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white, 
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  "Or sign up with", 
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8), 
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialIcon(
                    child: Image.asset('assets/icons/google_logo.png', height: 26, width: 26),
                    onTap: _isLoading ? null : () => _loginWithSocial('Google'),
                  ),
                  const SizedBox(width: 20),
                  _socialIcon(
                    icon: Icons.code_rounded, 
                    color: const Color(0xFF1E293B), 
                    onTap: _isLoading ? null : () => _loginWithSocial('GitHub'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: BouncingPressable(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: "Already have an account? ",
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 14),
                      children: [
                        TextSpan(
                          text: "Sign in", 
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold, 
                            color: const Color(0xFF0056D2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialIcon({Widget? child, IconData? icon, Color color = Colors.black, VoidCallback? onTap}) {
    return BouncingPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child ?? Icon(icon!, color: color, size: 26),
      ),
    );
  }
}
