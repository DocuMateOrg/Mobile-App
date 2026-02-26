import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ocr_service.dart';
import '../../core/providers/gemini_provider.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String imagePath;
  const ResultScreen({super.key, required this.imagePath});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  String _extractedText = "Processing OCR...";
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
    
    if (!mounted) return;
    setState(() {
      _extractedText = text.isEmpty ? "No text detected." : text;
    });

    // 2. Trigger Gemini using the extracted text (faster than image bytes)
    if (text.isNotEmpty) {
      ref.read(ocrSummaryProvider.notifier).summarizeText(text);
    }
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
    final summaryState = ref.watch(ocrSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text("Scan Results", style: GoogleFonts.poppins())),
      body: Column(
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

  Widget _buildHeader(String title) {
    return Text(title.toUpperCase(), 
      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12));
  }
}