import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
// Import the dashboard screen we are about to create
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/scanner/scanner_screen.dart';

final router = GoRouter(
  initialLocation: '/dashboard', // Skipping login for development speed
  routes: [
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScannerScreen(),
    ),
    // We will add '/login' here later
  ],
);