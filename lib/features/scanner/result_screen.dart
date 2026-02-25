import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ocr_service.dart';
import 'local_storage_service.dart'; 
import 'api_service.dart';
import 'package:documate/core/constants/gemini_provider.dart';

// CHANGED: Now a ConsumerStatefulWidget to listen to Riverpod
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
  final LocalStorageService _storageService = LocalStorageService(); 
  final ApiService _apiService = ApiService();
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startOCRAndSummary();
  }

  Future<void> _startOCRAndSummary() async {
    // 1. Run local OCR first
    final text = await _ocrService.processImage(widget.imagePath);

    // 2. Update UI
    if (!mounted) return;
    setState(() {
      _extractedText = text.isEmpty ? "No text detected." : text;
    });

    // 3. Trigger Gemini using the extracted text
    if (text.isNotEmpty) {
      ref.read(ocrSummaryProvider.notifier).summarizeText(text);
    }
  }

  Future<void> _saveDocument() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a title")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final savedLocalPath = await _storageService.saveImageLocally(widget.imagePath);

    if (savedLocalPath != null) {
      final success = await _apiService.saveDocumentMetadata(
        title: _titleController.text.trim(),
        extractedText: _extractedText,
        localImagePath: savedLocalPath,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document Saved!")),
        );
        context.pop(true); 
      } else {
        _showError("Failed to save data to database.");
      }
    } else {
      _showError("Failed to save image locally.");
    }

    if (mounted) setState(() => _isSaving = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save Document"),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: "e.g., Biology Notes Chapter 1"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); 
              _saveDocument();        
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Widget _buildHeader(String title) {
    return Text(
      title.toUpperCase(), 
      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12)
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the Gemini Summary State from Riverpod
    final summaryState = ref.watch(ocrSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text("Scan Results", style: GoogleFonts.poppins())),
      body: _isSaving 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader("Extracted Text"),
                    const SizedBox(height: 8),
                    SelectableText(_extractedText, style: GoogleFonts.poppins()),
                    
                    const Divider(height: 40),
                    
                    _buildHeader("Summary Text"),
                    const SizedBox(height: 8),
                    
                    // Handle Gemini Loading, Error, and Success states smoothly
                    summaryState.when(
                      data: (result) => SelectableText(
                        result?.summary ?? "Waiting for text...",
                        style: GoogleFonts.poppins(color: Colors.blueGrey[900]),
                      ),
                      loading: () => const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text("Gemini is thinking...", style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      error: (err, _) => Text("Error: $err", style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _showSaveDialog,
          icon: const Icon(Icons.save, color: Colors.white),
          label: const Text("Save Document", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0056D2),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }
}