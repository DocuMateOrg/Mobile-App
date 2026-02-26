import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:documate/core/constants/gemini_provider.dart';  
// 1. Converted to ConsumerStatefulWidget to talk to Gemini
class DocumentDetailScreen extends ConsumerStatefulWidget {
  final String title;
  final String imagePath;
  final String content; // This is the raw text from your database

  const DocumentDetailScreen({
    super.key,
    required this.title,
    required this.imagePath,
    required this.content,
  });

  @override
  ConsumerState<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  
  @override
  void initState() {
    super.initState();
    // 2. The moment this screen opens, we ask Gemini to summarize the hidden raw text!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.content.isNotEmpty) {
        ref.read(ocrSummaryProvider.notifier).summarizeText(widget.content);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool fileExists = File(widget.imagePath).existsSync();
    
    // 3. Watch the Gemini state
    final summaryState = ref.watch(ocrSummaryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Top: The Full-Size Image Section
          SizedBox(
            height: 350,
            width: double.infinity,
            child: fileExists
                ? Image.file(File(widget.imagePath), fit: BoxFit.cover)
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    ),
                  ),
          ),
          
          // Bottom: The AI Summary Section (Raw text is now completely hidden!)
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
                      "AI Summary",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0056D2),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    // 4. Show loading spinner, error, or the final summary
                    if (widget.content.isEmpty)
                      Text("No text was found in this document to summarize.", style: GoogleFonts.poppins())
                    else
                      summaryState.when(
                        data: (result) => SelectableText(
                          result?.summary ?? "Waiting for summary...",
                          style: GoogleFonts.poppins(fontSize: 15, height: 1.5),
                        ),
                        loading: () => const Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text("Gemini is summarizing..."),
                            ],
                          ),
                        ),
                        error: (err, _) => Text(
                          "Error connecting to AI: $err",
                          style: const TextStyle(color: Colors.red),
                        ),
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