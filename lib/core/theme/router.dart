import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// Import your screens (adjust paths if needed)
import '../../features/scanner/result_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/scanner/scanner_screen.dart';
import '../../screens/login_page.dart';  
import '../../screens/signup_page.dart'; 
import '../../screens/profile_page.dart'; 
import '../../features/dashboard/folders_screen.dart';
import '../../features/dashboard/folder_detail_screen.dart';
import 'dart:async';

import '../../services/user_session.dart';

final router = GoRouter(
  initialLocation: '/dashboard',
  
  redirect: (context, state) async {
    final isLoggedIn = await UserSession.isLoggedIn();
    final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

    if (!isLoggedIn && !isAuthRoute) {
      return '/login';
    }
    if (isLoggedIn && isAuthRoute) {
      return '/dashboard';
    }
    return null;
  },

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
    GoRoute(
      path: '/folders',
      builder: (context, state) => const FoldersScreen(),
    ),
    GoRoute(
      path: '/folders/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final folderName = state.extra as String? ?? 'Folder';
        return FolderDetailScreen(folderId: id, folderName: folderName);
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