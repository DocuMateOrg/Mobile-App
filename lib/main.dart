import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:documate/core/theme/router.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,

      title: 'Doc Digitizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Extracting the colors from your screenshots
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0056D2), // The deep blue from your Login btn
          primary: const Color(0xFF0056D2),
          secondary: const Color(0xFFEDF2F7), // Light grey background
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        // Setting a global font that looks like the design
        textTheme: GoogleFonts.poppinsTextTheme(), 
      ), // We will replace this with Router later
    );
  }
}

// Temporary screen to test setup
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Complete")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner, size: 64, color: Color(0xFF0056D2)),
            const SizedBox(height: 20),
            Text(
              "Ready to Start Building",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}