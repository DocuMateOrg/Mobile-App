import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import your screens (adjust paths if needed)
import '../../features/scanner/result_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/scanner/scanner_screen.dart';
import '../../screens/login_page.dart';  
import '../../screens/signup_page.dart'; 
import '../../screens/profile_page.dart'; 
import 'dart:async';

final router = GoRouter(
  initialLocation: '/dashboard',
  
  // This "redirect" logic replaces the RootAuthWrapper
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;
    final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

    // 1. If user is NOT logged in and tries to go somewhere else -> Force Login
    if (!isLoggedIn && !isLoggingIn) {
      return '/login';
    }

    // 2. If user IS logged in and tries to go to Login -> Send to Dashboard
    if (isLoggedIn && isLoggingIn) {
      return '/dashboard';
    }

    // 3. Otherwise, let them go where they want
    return null; 
  },

  // Refresh the router when Auth State changes (Auto-logout/login)
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),

  routes: [
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) {
        // Retrieve the imagePath passed from the camera
        final imagePath = state.extra as String; 
        return ResultScreen(imagePath: imagePath);
      },
    ),
  ],
);

// Helper class to listen to Firebase Auth changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}