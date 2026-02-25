import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'ocr_service.dart';
import 'local_storage_service.dart'; 
import 'api_service.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  const ResultScreen({super.key, required this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String _extractedText = "Processing...";
  bool _isSaving = false;
  
  final OCRService _ocrService = OCRService();
  final LocalStorageService _storageService = LocalStorageService(); 
  final ApiService _apiService = ApiService();
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startOCR();
  }

  Future<void> _startOCR() async {
    final text = await _ocrService.processImage(widget.imagePath);
    if (!mounted) return;
    setState(() => _extractedText = text);
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
        // CHANGED: We pop back and pass 'true' to signal a successful save
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Result")),
      body: _isSaving 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
        children: [
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey[50],
              width: double.infinity,
              child: SingleChildScrollView(
                child: SelectableText(
                  _extractedText,
                  style: GoogleFonts.poppins(fontSize: 14),
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