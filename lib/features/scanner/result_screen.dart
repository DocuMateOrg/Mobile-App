import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/providers/gemini_provider.dart'; 
import 'ocr_service.dart'; 
import 'api_service.dart';
import '../../services/local_document_service.dart';
import 'widgets/ask_document_sheet.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final List<String> imagePaths;

  ResultScreen({super.key, List<String>? imagePaths, String? imagePath})
      : imagePaths = imagePaths ?? (imagePath != null ? [imagePath] : []);

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  String _extractedText = "Processing OCR...";
  bool _isOcrRunning = true;
  bool _isSaving = false;
  int _currentPageIndex = 0;
  final PageController _pageController = PageController();

  // TTS Audio Player State
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlayingAudio = false;

  final OCRService _ocrService = OCRService();
  final TextEditingController _titleController = TextEditingController();
  final LocalDocumentService _localService = LocalDocumentService();

  @override
  void initState() {
    super.initState();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMultiPageOCRAndSummary();
    });
  }

  void _initTts() {
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
    _flutterTts.setErrorHandler((_) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _startMultiPageOCRAndSummary() async {
    if (widget.imagePaths.isEmpty) {
      if (mounted) {
        setState(() {
          _extractedText = "No scanned images provided.";
          _isOcrRunning = false;
        });
      }
      return;
    }

    try {
      setState(() => _isOcrRunning = true);
      final List<String> pageTexts = [];

      for (int i = 0; i < widget.imagePaths.length; i++) {
        final path = widget.imagePaths[i];
        if (File(path).existsSync()) {
          final text = await _ocrService.processImage(path);
          if (widget.imagePaths.length > 1) {
            pageTexts.add("--- Page ${i + 1} ---\n${text.trim()}");
          } else {
            pageTexts.add(text.trim());
          }
        }
      }

      final combined = pageTexts.where((t) => t.isNotEmpty).join("\n\n");

      if (!mounted) return;

      setState(() {
        _extractedText = combined.isEmpty ? "No text detected in scanned image(s)." : combined;
        _isOcrRunning = false;
      });

      if (combined.trim().isNotEmpty) {
        // Trigger Gemini structured summary and smart metadata
        await ref.read(ocrSummaryProvider.notifier).summarizeText(combined);

        // Pre-fill suggested title if available
        final summaryResult = ref.read(ocrSummaryProvider).value;
        if (summaryResult?.suggestedTitle != null && summaryResult!.suggestedTitle!.isNotEmpty) {
          if (_titleController.text.isEmpty || _titleController.text == "Untitled Document") {
            _titleController.text = summaryResult.suggestedTitle!;
          }
        }
      } else {
        ref.read(ocrSummaryProvider.notifier).summarizeText("");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _extractedText = "OCR Error: $e";
          _isOcrRunning = false;
        });
      }
    }
  }

  void _toggleAudio(String textToSpeak) async {
    if (_isPlayingAudio) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isPlayingAudio = false);
    } else {
      if (textToSpeak.trim().isEmpty) return;
      if (mounted) setState(() => _isPlayingAudio = true);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak(textToSpeak);
    }
  }

  Future<void> _showSaveDialog() async {
    setState(() => _isSaving = true);

    // Fetch both local and remote folders
    List<Map<String, dynamic>> combinedFolders = [];
    try {
      final localFolders = await _localService.getLocalFolders();
      combinedFolders.addAll(localFolders);
    } catch (_) {}

    try {
      final remoteFolders = await ApiService().fetchFolders();
      for (final rf in remoteFolders) {
        if (!combinedFolders.any((f) => f['id'] == rf['id'] || f['name'] == rf['name'])) {
          combinedFolders.add(Map<String, dynamic>.from(rf));
        }
      }
    } catch (_) {}

    setState(() => _isSaving = false);
    if (!mounted) return;

    int? selectedFolderId;

    // Check if Gemini recommended a category that matches an existing folder
    final summaryResult = ref.read(ocrSummaryProvider).value;
    final suggestedCategory = summaryResult?.suggestedCategory;
    if (suggestedCategory != null) {
      for (final f in combinedFolders) {
        if (f['name'].toString().toLowerCase() == suggestedCategory.toLowerCase()) {
          selectedFolderId = f['id'] as int;
          break;
        }
      }
    }

    if (_titleController.text.trim().isEmpty && summaryResult?.suggestedTitle != null) {
      _titleController.text = summaryResult!.suggestedTitle!;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.bookmark_add_rounded, color: Color(0xFF0056D2)),
                const SizedBox(width: 10),
                Text("Save Document", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Document Title", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleController,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Enter title (e.g. Utility Bill)",
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("Folder (Optional)", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              isExpanded: true,
                              value: selectedFolderId,
                              hint: Text("Select Folder", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text("None (Root)", style: GoogleFonts.poppins(fontSize: 14)),
                                ),
                                ...combinedFolders.map((folder) => DropdownMenuItem<int?>(
                                      value: folder['id'] as int,
                                      child: Text(folder['name'] ?? 'Untitled', style: GoogleFonts.poppins(fontSize: 14)),
                                    )),
                              ],
                              onChanged: (val) => setStateDialog(() => selectedFolderId = val),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Create Folder Inline
                      IconButton.filledTonal(
                        tooltip: "Create Folder",
                        icon: const Icon(Icons.create_new_folder, color: Color(0xFF0056D2)),
                        onPressed: () async {
                          final newFolderController = TextEditingController(text: suggestedCategory ?? '');
                          final newName = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text("New Folder", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              content: TextField(
                                controller: newFolderController,
                                decoration: const InputDecoration(hintText: "Folder Name (e.g. Bills)"),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, newFolderController.text.trim()),
                                  child: const Text("Create"),
                                ),
                              ],
                            ),
                          );

                          if (newName != null && newName.isNotEmpty) {
                            // 1. Create locally (guaranteed instant success)
                            final createdLocal = await _localService.createLocalFolder(newName);
                            // 2. Try remote in background
                            ApiService().createFolder(newName).catchError((_) => false);

                            setStateDialog(() {
                              combinedFolders.insert(0, createdLocal);
                              selectedFolderId = createdLocal['id'] as int;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey[600])),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056D2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context); // Close dialog

                  setState(() => _isSaving = true);

                  final title = _titleController.text.trim().isEmpty 
                      ? (summaryResult?.suggestedTitle ?? "Document ${DateTime.now().toString().substring(0, 10)}")
                      : _titleController.text.trim();

                  final structuredText = ref.read(ocrSummaryProvider).value?.summary ?? _extractedText;

                  // 1. Move primary image to permanent local storage
                  final directory = await getApplicationDocumentsDirectory();
                  final primaryPath = widget.imagePaths.isNotEmpty ? widget.imagePaths.first : '';
                  final String fileName = "scan_${DateTime.now().millisecondsSinceEpoch}${p.extension(primaryPath).isEmpty ? '.jpg' : p.extension(primaryPath)}";
                  final String persistentPath = p.join(directory.path, fileName);

                  if (primaryPath.isNotEmpty && File(primaryPath).existsSync()) {
                    await File(primaryPath).copy(persistentPath);
                  }

                  // 2. Save to local-first database (guaranteed safe offline)
                  await _localService.saveLocalDocument(
                    title: title,
                    content: _extractedText,
                    summary: structuredText,
                    localImagePath: persistentPath,
                    folderId: selectedFolderId,
                  );

                  // 3. Sync to API backend in parallel
                  try {
                    await ApiService().saveDocumentMetadata(
                      title: title,
                      extractedText: structuredText,
                      localImagePath: persistentPath,
                      folderId: selectedFolderId,
                    );
                  } catch (e) {
                    debugPrint("Backend sync notice (offline mode active): $e");
                  }

                  if (!mounted) return;
                  final messenger = ScaffoldMessenger.of(this.context);
                  final router = GoRouter.of(this.context);

                  setState(() => _isSaving = false);

                  messenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(child: Text("Document \"$title\" saved successfully!")),
                        ],
                      ),
                      backgroundColor: Colors.green[700],
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  router.pop(true); // Return to scanner or dashboard
                },
                child: Text("Save", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryState = ref.watch(ocrSummaryProvider);
    final summaryText = summaryState.value?.summary ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Scan Results",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          // Ask AI Button in AppBar
          TextButton.icon(
            onPressed: () {
              AskDocumentSheet.show(
                context,
                documentText: _extractedText,
                documentTitle: _titleController.text.isNotEmpty ? _titleController.text : "Scanned Document",
              );
            },
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF0056D2), size: 18),
            label: Text(
              "Ask AI",
              style: GoogleFonts.poppins(
                color: const Color(0xFF0056D2),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Multi-Page Image Carousel
          if (widget.imagePaths.isNotEmpty)
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.imagePaths.length,
                    onPageChanged: (idx) => setState(() => _currentPageIndex = idx),
                    itemBuilder: (context, index) {
                      final file = File(widget.imagePaths[index]);
                      return file.existsSync()
                          ? Container(
                              color: Colors.black,
                              child: Image.file(file, fit: BoxFit.contain),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Center(child: Icon(Icons.broken_image, size: 48)),
                            );
                    },
                  ),
                  // Page Indicator Badge
                  if (widget.imagePaths.length > 1)
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Page ${_currentPageIndex + 1} of ${widget.imagePaths.length}",
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Smart Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0056D2), Color(0xFF0284C7)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0056D2).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Gemini AI Analysis Ready",
                                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                "Ask questions, listen aloud, or auto-categorize.",
                                style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0056D2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            AskDocumentSheet.show(
                              context,
                              documentText: _extractedText,
                              documentTitle: _titleController.text.isNotEmpty ? _titleController.text : "Scanned Document",
                            );
                          },
                          child: Text("Ask AI", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 1: Summary with Text-To-Speech Listen button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFF0056D2), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            "AI SUMMARY & HIGHLIGHTS",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0056D2),
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (summaryText.isNotEmpty)
                        IconButton.filledTonal(
                          tooltip: _isPlayingAudio ? "Stop Audio" : "Listen Aloud",
                          icon: Icon(
                            _isPlayingAudio ? Icons.stop_rounded : Icons.volume_up_rounded,
                            size: 18,
                            color: const Color(0xFF0056D2),
                          ),
                          onPressed: () => _toggleAudio(summaryText),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: summaryState.when(
                      data: (result) {
                        final text = result?.summary ?? "No summary available.";
                        return SelectableText(
                          text,
                          style: GoogleFonts.poppins(fontSize: 14, height: 1.5, color: const Color(0xFF1E293B)),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(strokeWidth: 2.5),
                              SizedBox(height: 12),
                              Text("Gemini is analyzing document..."),
                            ],
                          ),
                        ),
                      ),
                      error: (err, _) => SelectableText(
                        "Summary notice: $err",
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 2: Extracted OCR Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "RAW EXTRACTED TEXT (${widget.imagePaths.length} ${widget.imagePaths.length == 1 ? 'PAGE' : 'PAGES'})",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[700],
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (_isOcrRunning)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SelectableText(
                      _extractedText,
                      style: GoogleFonts.poppins(fontSize: 13, height: 1.5, color: Colors.blueGrey[900]),
                    ),
                  ),

                  const SizedBox(height: 80), // Padding for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Ask AI Quick Button
              OutlinedButton.icon(
                onPressed: () {
                  AskDocumentSheet.show(
                    context,
                    documentText: _extractedText,
                    documentTitle: _titleController.text.isNotEmpty ? _titleController.text : "Scanned Document",
                  );
                },
                icon: const Icon(Icons.auto_awesome, color: Color(0xFF0056D2), size: 18),
                label: Text("Ask AI", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF0056D2))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  side: const BorderSide(color: Color(0xFF0056D2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(width: 12),
              // Save Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _showSaveDialog,
                  icon: _isSaving 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                  label: Text(
                    _isSaving ? "SAVING..." : "SAVE DOCUMENT",
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056D2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}