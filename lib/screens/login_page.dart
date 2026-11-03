import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:documate/core/widgets/bouncing_button.dart';
import 'package:documate/screens/forgot_password_page.dart';
import 'package:documate/screens/signup_page.dart';
import 'package:documate/services/asgardeo_auth_service.dart';
import 'package:documate/features/scanner/api_service.dart';
import 'package:documate/services/user_session.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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
        if (!mounted) return;
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BouncingPressable(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/splash');
                  }
                },
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
                "Welcome back", 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30, 
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Log in to your account", 
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, 
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),
              
              Text(
                "Email or Username", 
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
                  hintText: "Enter your email or username",
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
                  hintText: "Enter your password",
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
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _rememberMe, 
                          activeColor: const Color(0xFF0056D2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (v) => setState(() => _rememberMe = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Remember me",
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  BouncingPressable(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                    ),
                    child: Text(
                      "Forgot password?", 
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600, 
                        fontSize: 13,
                        color: const Color(0xFF0056D2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              
              // Tactile Primary Sign In Button
              BouncingPressable(
                onTap: _isLoading ? null : _signIn,
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
                            "Sign in", 
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
              const SizedBox(height: 22),
              
              Center(
                child: BouncingPressable(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupPage())),
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 14),
                      children: [
                        TextSpan(
                          text: "Register", 
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
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14), 
                    child: Text(
                      "OR", 
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                ],
              ),
              const SizedBox(height: 24),
              
              // Social Logins (Google & GitHub) with Click Feel
              BouncingPressable(
                onTap: _isLoading ? null : () => _loginWithSocial('Google'),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/icons/google_logo.png', height: 24, width: 24),
                      const SizedBox(width: 12),
                      Text(
                        "Sign In With Google", 
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              BouncingPressable(
                onTap: _isLoading ? null : () => _loginWithSocial('GitHub'),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.code_rounded, color: Color(0xFF1E293B), size: 22),
                      const SizedBox(width: 12),
                      Text(
                        "Sign In With GitHub", 
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
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
}
