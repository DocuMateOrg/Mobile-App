import 'package:flutter/material.dart';
import '../services/asgardeo_auth_service.dart';
import 'otp_verification_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _usernameController = TextEditingController();
  final AsgardeoAuthService _authService = AsgardeoAuthService();
  bool _isLoading = false;

  Future<void> _sendRecoveryEmail() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your username")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.initiatePasswordRecovery(username: username);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "OTP dispatched!")),
      );

      // Navigate to OTP verification page for Forgot Password scenario
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationPage(
            scenario: OtpScenario.forgotPassword,
            emailOrUsername: username,
            flowId: result["flowId"],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Failed to send recovery code")),
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
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 30),
              const Text("Forgot password",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                "We've got you covered. Enter your email or username to begin resetting your password.",
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              const Text("Email / Username", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: "Enter your email or username here",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendRecoveryEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056D2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Send email OTP", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text("cancel", style: TextStyle(color: Colors.black87, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
