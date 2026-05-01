import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTANT: This import connects the two files
import '../../core/providers/gemini_provider.dart'; 
import 'ocr_service.dart'; 
import 'api_service.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String imagePath;
  const ResultScreen({super.key, required this.imagePath});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  String _extractedText = "Processing OCR...";
  bool _isSaving = false;
  
  final OCRService _ocrService = OCRService();
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fire the logic after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOCRAndSummary();
    });
  }

  Future<void> _startOCRAndSummary() async {
    try {
      final text = await _ocrService.processImage(widget.imagePath);

      if (!mounted) return;

      setState(() {
        _extractedText = text.isEmpty ? "No text detected." : text;
      });

      if (text.trim().isNotEmpty) {
        // Calls the provider defined in the other file
        await ref.read(ocrSummaryProvider.notifier).summarizeText(text);
      } else {
        // If no text, stop the loading state immediately
        ref.read(ocrSummaryProvider.notifier).summarizeText(""); 
      }
    } catch (e) {
      if (mounted) setState(() => _extractedText = "OCR Error: $e");
    }
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Save Document", style: GoogleFonts.poppins()),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: "Enter document title"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final title = _titleController.text.trim();
              if (title.isEmpty) return;
              
              Navigator.pop(context); // close dialog
              setState(() => _isSaving = true);
              
              final success = await ApiService().saveDocumentMetadata(
                title: title,
                extractedText: _extractedText,
                localImagePath: widget.imagePath,
              );
              
              if (!mounted) return;
              setState(() => _isSaving = false);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Document saved successfully!")),
                );
                // Return to dashboard and signal a refresh
                Navigator.pop(context, true); 
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to save document. Check backend connection.")),
                );
              }
            }, 
            child: const Text("Save")
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title.toUpperCase(), 
      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12)
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watching the provider for state changes (loading, data, error)
    final summaryState = ref.watch(ocrSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Scan Results", style: GoogleFonts.poppins()),
        elevation: 0,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader("Extracted Text"),
                  const SizedBox(height: 8),
                  SelectableText(_extractedText, style: GoogleFonts.poppins(fontSize: 14)),
                  const Divider(height: 40),
                  _buildHeader("Summary Text"),
                  const SizedBox(height: 8),

                  // Handling the 3 states of the Gemini call
                  summaryState.when(
                    data: (result) => SelectableText(
                      result?.summary ?? "No summary available.",
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.blueGrey[900]),
                    ),
                    loading: () => const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text("Gemini is thinking..."),
                        ],
                      ),
                    ),
                    error: (err, _) => Text("Error: $err", style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _showSaveDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0056D2),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: _isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("SAVE DOCUMENT", style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}