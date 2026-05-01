import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTANT: This import connects the two files
import '../../core/providers/gemini_provider.dart'; 
import 'ocr_service.dart'; 
import 'package:go_router/go_router.dart';
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

  void _showSaveDialog() async {
    setState(() => _isSaving = true);
    final folders = await ApiService().fetchFolders();
    setState(() => _isSaving = false);
    if (!mounted) return;

    int? selectedFolderId;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text("Save Document", style: GoogleFonts.poppins()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(hintText: "Enter document title"),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: selectedFolderId,
                        hint: const Text("Select Folder (Optional)"),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text("None"),
                          ),
                          ...folders.map((folder) => DropdownMenuItem<int?>(
                                value: folder['id'] as int,
                                child: Text(folder['name']),
                              )),
                        ],
                        onChanged: (val) => setStateDialog(() => selectedFolderId = val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.create_new_folder, color: Colors.blue),
                      onPressed: () async {
                        // Quick inline creation
                        final newFolderNameController = TextEditingController();
                        final newName = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("New Folder"),
                            content: TextField(
                              controller: newFolderNameController,
                              decoration: const InputDecoration(hintText: "Folder Name"),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, newFolderNameController.text.trim()),
                                child: const Text("Create"),
                              ),
                            ],
                          ),
                        );

                        if (newName != null && newName.isNotEmpty) {
                          final created = await ApiService().createFolder(newName);
                          if (created && mounted) {
                            // Refetch folders to update the dropdown
                            final updatedFolders = await ApiService().fetchFolders();
                            setStateDialog(() {
                              folders.clear();
                              folders.addAll(updatedFolders);
                              // Try to find the new folder to auto-select it
                              try {
                                selectedFolderId = folders.firstWhere((f) => f['name'] == newName)['id'];
                              } catch (_) {}
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context); // Close the dialog
                  
                  setState(() {
                    _isSaving = true;
                  });

                  final title = _titleController.text.trim().isEmpty ? "Untitled Document" : _titleController.text.trim();
                  
                  final success = await ApiService().saveDocumentMetadata(
                    title: title,
                    extractedText: _extractedText,
                    localImagePath: widget.imagePath,
                    folderId: selectedFolderId, // Passed to API!
                  );

                  if (mounted) {
                    setState(() {
                      _isSaving = false;
                    });

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Document saved!")),
                      );
                      context.pop(true); // Return to ScannerScreen, which returns to Dashboard
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Failed to save document. Please try again.")),
                      );
                    }
                  }
                }, 
                child: const Text("Save")
              ),
            ],
          );
        }
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