import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ocr_service.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;

  const ResultScreen({super.key, required this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String _extractedText = "Scanning...";
  final OCRService _ocrService = OCRService();

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  Future<void> _processImage() async {
    final text = await _ocrService.processImage(widget.imagePath);
    if (!mounted) return;
    setState(() {
      _extractedText = text;
    });
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Digitized Text")),
      body: Column(
        children: [
          // 1. The Captured Image (Preview)
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),
          
          // 2. The Text Result
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.grey[100],
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Extracted Text:",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _extractedText,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 3. Action Buttons (Save / Gemini)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () {
                // TODO: Save to database or Send to Gemini
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056D2),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Save Document", style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }
}