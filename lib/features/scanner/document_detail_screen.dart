import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DocumentDetailScreen extends StatelessWidget {
  final String title;
  final String imagePath;
  final String content; // The extracted OCR text

  const DocumentDetailScreen({
    super.key,
    required this.title,
    required this.imagePath,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final bool fileExists = File(imagePath).existsSync();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. The Full-Size Image Section
          SizedBox(
            height: 350,
            width: double.infinity,
            child: fileExists
                ? Image.file(File(imagePath), fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    ),
                  ),
          ),
          
          // 2. The Extracted Text Section
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.grey[50],
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Extracted Text",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0056D2),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SelectableText(
                      content.isNotEmpty ? content : "No text was extracted for this document.",
                      style: GoogleFonts.poppins(fontSize: 15, height: 1.5),
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