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
  String _extractedText = "Processing...";
  final OCRService _ocrService = OCRService();

  @override
  void initState() {
    super.initState();
    _startOCR();
  }

  Future<void> _startOCR() async {
    // 1. Run the OCR
    final text = await _ocrService.processImage(widget.imagePath);
    
    // 2. Update UI
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
      appBar: AppBar(title: const Text("Scan Result")),
      body: Column(
        children: [
          // Top: Image Preview
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),
          
          // Bottom: Extracted Text
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey[50],
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Extracted Text",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      _extractedText, // SelectableText lets users copy the text
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}