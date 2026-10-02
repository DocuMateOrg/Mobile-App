import 'dart:async';
import 'package:flutter/material.dart';
import '../services/asgardeo_auth_service.dart';
import 'login_page.dart';
import '../features/dashboard/dashboard_screen.dart';

enum OtpScenario { signUp, forgotPassword, mfaLogin }

class OtpVerificationPage extends StatefulWidget {
  final OtpScenario scenario;
  final String emailOrUsername;
  final String? flowId; // Required if mfaLogin

  const OtpVerificationPage({
    super.key,
    required this.scenario,
    required this.emailOrUsername,
    this.flowId,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final AsgardeoAuthService _authService = AsgardeoAuthService();

  bool _isLoading = false;
  int _resendCountdown = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 20);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the OTP code")),
      );
      return;
    }

    setState(() => _isLoading = true);

    Map<String, dynamic> result;

    if (widget.scenario == OtpScenario.signUp) {
      result = await _authService.verifySignUpOtp(code: code);
    } else if (widget.scenario == OtpScenario.forgotPassword) {
      if (_newPasswordController.text.trim().isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter your new password")),
        );
        return;
      }
      result = await _authService.resetPasswordWithOtp(
        confirmationCode: widget.flowId ?? code,
        otp: code,
        newPassword: _newPasswordController.text.trim(),
      );
    } else {
      result = await _authService.verifyMfaOtp(
        flowId: widget.flowId ?? "",
        authenticatorId: "EmailOTP",
        otpCode: code,
      );
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Success!")),
      );

      if (widget.scenario == OtpScenario.signUp || widget.scenario == OtpScenario.mfaLogin) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      } else {
        // Reset password success -> navigate to Login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Verification failed")),
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
              const Text("OTP verification",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                "Enter the code sent to your email ID (${widget.emailOrUsername})",
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter 6-digit OTP code (e.g. 123456)",
                  prefixIcon: const Icon(Icons.lock_clock_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (widget.scenario == OtpScenario.forgotPassword) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Enter new password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056D2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Continue", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: _resendCountdown == 0 ? _startResendTimer : null,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    "Resend the code",
                    style: TextStyle(
                      color: _resendCountdown == 0 ? Colors.black87 : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: Text(
                  _resendCountdown > 0
                      ? "Resend OTP again in ${_resendCountdown}s"
                      : "You can resend the code now",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
