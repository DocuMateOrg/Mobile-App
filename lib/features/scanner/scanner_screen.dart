import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  DocumentScanner? _documentScanner;
  bool _isScanning = false;
  bool _hasAttemptedScan = false;

  @override
  void initState() {
    super.initState();
    // Auto-launch the native scanner after the frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanning();
    });
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _hasAttemptedScan = true;
    });

    // Configure Google ML Kit Document Scanner
    final options = DocumentScannerOptions(
      documentFormats: {DocumentFormat.jpeg},
      mode: ScannerMode.full, // Full gives automated edge detection, perspective correction, filters & cropping
      pageLimit: 5,           // Support up to 5 pages per scan
      isGalleryImport: true,  // Allow importing documents directly from device gallery
    );

    _documentScanner = DocumentScanner(options: options);

    try {
      HapticFeedback.lightImpact();
      final DocumentScanningResult result = await _documentScanner!.scanDocument();

      if (!mounted) return;

      if (result.images != null && result.images!.isNotEmpty) {
        // Pass all scanned, perspective-corrected pages to ResultScreen
        final List<String> images = result.images!;

        // Navigate to ResultScreen for instant ML Kit OCR and Gemini AI summarization
        final saved = await context.push('/result', extra: images);

        if (!mounted) return;
        // If document was saved successfully in ResultScreen, notify the Dashboard
        if (saved == true) {
          context.pop(true);
          return;
        }
      }
    } catch (e) {
      debugPrint("Google Document Scanner Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Scanner notice: ${e.toString().split('\n').first}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _documentScanner?.close();
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  void dispose() {
    _documentScanner?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Modern dark slate
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(false),
        ),
        title: Text(
          "Document Scanner",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Scanner Icon with Ambient Glow
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0056D2),
                        Color(0xFF002952),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0056D2).withValues(alpha: 0.4),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isScanning
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          )
                        : const Icon(
                            Icons.document_scanner_rounded,
                            color: Colors.white,
                            size: 54,
                          ),
                  ),
                ),

                const SizedBox(height: 36),

                // Status Title
                Text(
                  _isScanning ? "Scanning in progress..." : "AI Document Scanner",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  _isScanning
                      ? "Align document within the camera. Edges and perspective will be automatically detected."
                      : "Real-time edge detection, automatic perspective correction, and smart contrast filters powered by Google ML Kit.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 48),

                // Action Buttons (shown if user cancelled or wants to scan again)
                if (!_isScanning) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _startScanning,
                      icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                      label: Text(
                        _hasAttemptedScan ? "Scan Document Again" : "Start Scanner",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0056D2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFF0056D2).withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(false),
                    child: Text(
                      "Return to Dashboard",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}