import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'result_screen.dart';

// We need a global variable to store the list of cameras
List<CameraDescription> cameras = [];

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    // 1. Request Camera Permission
    var status = await Permission.camera.request();
    if (status.isDenied) {
      return; // Handle permission denied later
    }

    // 2. Find available cameras
    cameras = await availableCameras();
    
    // 3. Select the back camera
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[0], // Index 0 is usually the back camera
        ResolutionPreset.high, // High res for text recognition
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _controller == null) return;

    try {
      // 1. Capture the image
      final XFile image = await _controller!.takePicture();
      if (!mounted) return;

      // Navigate to the Result Screen with the image path
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(imagePath: image.path),
        ),
      );
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Camera Feed
          SizedBox(
            height: MediaQuery.of(context).size.height,
            width: double.infinity,
            child: CameraPreview(_controller!),
          ),

          // 2. The "Scanner Overlay" (Darkened background with a clear hole)
          const ScannerOverlay(),

          // 3. Top Bar (Back button & Title)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                Text(
                  "Scan Document",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.flash_off, color: Colors.white),
                  onPressed: () {
                    // Toggle Flash Logic here
                  },
                ),
              ],
            ),
          ),

          // 4. Bottom Capture Area
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "Place document inside the frame",
                  style: GoogleFonts.poppins(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white24,
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Widget to create the "Cutout" effect
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Colors.black54, // The darkness of the background
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.transparent,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              height: 500, // Height of the scan area
              width: 350,  // Width of the scan area
              decoration: BoxDecoration(
                color: Colors.black, // This color is "cut out"
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue, width: 2), // The blue border
              ),
            ),
          ),
        ],
      ),
    );
  }
}