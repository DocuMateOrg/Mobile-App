import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../../core/providers/gemini_provider.dart';
import '../../services/local_export_service.dart';
import 'api_service.dart';
import 'widgets/ask_document_sheet.dart';

class DocumentDetailScreen extends ConsumerStatefulWidget {
  final int documentId;
  final String title;
  final String imagePath;
  final String? serverImagePath;
  final String content;

  const DocumentDetailScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.imagePath,
    this.serverImagePath,
    required this.content,
  });

  @override
  ConsumerState<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  bool _isExporting = false;
  FlutterTts flutterTts = FlutterTts();
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    initTts();
  }

  void initTts() {
    flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
    });
    flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("TTS Error: $msg")),
        );
      }
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  void _editImage() async {
    final imagePathToEdit = widget.imagePath;
    if (!File(imagePathToEdit).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original image not found locally.')),
      );
      return;
    }

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePathToEdit,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Edit Document',
            toolbarColor: const Color(0xFF0056D2),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
        IOSUiSettings(
          title: 'Edit Document',
        ),
      ],
    );

    if (croppedFile != null) {
      // Overwrite the local file with the cropped version
      final croppedBytes = await File(croppedFile.path).readAsBytes();
      await File(widget.imagePath).writeAsBytes(croppedBytes);
      
      if (mounted) {
        setState(() {}); // Trigger a rebuild to show the cropped image
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image cropped successfully!')),
        );
      }
    }
  }

  void _exportDocument(String format) async {
    print("DEBUG: Exporting document ${widget.documentId} to $format");
    setState(() => _isExporting = true);

    try {
      String? filePath;

      // 1. If document is on the remote server (positive ID), attempt server export first
      if (widget.documentId > 0) {
        try {
          filePath = await ApiService().downloadExportedFile(
            widget.documentId,
            format,
            title: widget.title,
            content: widget.content,
            localImagePath: widget.imagePath,
          );
        } catch (e) {
          debugPrint("Server export attempt notice: $e");
        }
      }

      // 2. Local zero-dependency export fallback (handles local offline documents with negative IDs,
      // or remote documents when connection/server is offline or fails)
      if (filePath == null) {
        String? localImg = widget.imagePath;
        if (localImg.isEmpty || !File(localImg).existsSync()) {
          localImg = null;
          if (widget.serverImagePath != null && widget.serverImagePath!.isNotEmpty) {
            try {
              final imgUrl = "${ApiService.baseHost}/${widget.serverImagePath!.replaceAll('\\', '/')}";
              final res = await http.get(Uri.parse(imgUrl)).timeout(const Duration(seconds: 5));
              if (res.statusCode == 200) {
                final tempDir = await getTemporaryDirectory();
                final tempImgFile = File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
                await tempImgFile.writeAsBytes(res.bodyBytes);
                localImg = tempImgFile.path;
              }
            } catch (_) {}
          }
        }

        if (format == 'pdf') {
          filePath = await LocalExportService.exportToPdf(
            title: widget.title,
            content: widget.content,
            imagePath: localImg,
          );
        } else if (format == 'docx' || format == 'doc') {
          filePath = await LocalExportService.exportToWordDoc(
            title: widget.title,
            content: widget.content,
            imagePath: localImg,
          );
        }
      }

      print("DEBUG: Exported file path: $filePath");
      
      if (filePath != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Exported to ${format.toUpperCase()} successfully!")),
          );
        }
        await OpenFilex.open(filePath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to export document. Check your connection.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showSummaryModal() {
    if (ref.read(ocrSummaryProvider).value == null) {
      final imgPath = widget.imagePath.isNotEmpty && File(widget.imagePath).existsSync()
          ? widget.imagePath
          : null;
      ref.read(ocrSummaryProvider.notifier).analyzeDocument(
        text: widget.content,
        imagePath: imgPath,
      );
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final summaryState = ref.watch(ocrSummaryProvider);
            final isVisual = summaryState.value?.isVisualDescription ?? false;
            
            return Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isVisual ? Icons.visibility_outlined : Icons.auto_awesome,
                          color: const Color(0xFF0056D2),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVisual ? "Visual AI Description" : "AI Summary",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0056D2),
                          ),
                        ),
                        if (isVisual) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              "VISION",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0056D2),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    summaryState.when(
                      data: (res) => SelectableText(
                        cleanSummaryText(res?.summary ?? "No summary available."),
                        style: GoogleFonts.poppins(fontSize: 15, height: 1.5),
                      ),
                      loading: () => Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 15),
                            Text(isVisual ? "Analyzing visual elements..." : "Generating summary..."),
                          ],
                        ),
                      ),
                      error: (e, s) => Text("Error: $e", style: const TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleAudioSummary() async {
    if (isPlaying) {
      await flutterTts.stop();
      setState(() => isPlaying = false);
      return;
    }

    final state = ref.read(ocrSummaryProvider);
    String textToSpeak = "";
    
    if (state.value != null && state.value!.summary.isNotEmpty) {
      textToSpeak = state.value!.summary;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Generating summary for audio...")),
      );
      final imgPath = widget.imagePath.isNotEmpty && File(widget.imagePath).existsSync()
          ? widget.imagePath
          : null;
      await ref.read(ocrSummaryProvider.notifier).analyzeDocument(
        text: widget.content,
        imagePath: imgPath,
      );
      
      final newState = ref.read(ocrSummaryProvider);
      if (newState.value != null && newState.value!.summary.isNotEmpty) {
        textToSpeak = newState.value!.summary;
      }
    }

    if (textToSpeak.isNotEmpty) {
      setState(() => isPlaying = true);
      await flutterTts.setLanguage("en-US");
      await flutterTts.setPitch(1.0);
      await flutterTts.speak(textToSpeak);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not generate summary to read.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool fileExists = File(widget.imagePath).existsSync();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF0056D2)),
            tooltip: "Ask DocuMate AI",
            onPressed: () {
              AskDocumentSheet.show(
                context,
                documentText: widget.content,
                documentTitle: widget.title,
                imagePath: widget.imagePath.isNotEmpty && File(widget.imagePath).existsSync()
                    ? widget.imagePath
                    : null,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.crop),
            onPressed: _editImage,
          ),
          if (_isExporting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: _exportDocument,
              icon: const Icon(Icons.file_download_outlined),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'pdf', child: Text("Export as PDF")),
                const PopupMenuItem(value: 'docx', child: Text("Export as Word")),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. The Full-Size Image Section
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: fileExists
                    ? Image.file(File(widget.imagePath), fit: BoxFit.contain, key: UniqueKey())
                    : (widget.serverImagePath != null
                        ? Image.network(
                            "${ApiService.baseHost}/${widget.serverImagePath!.replaceAll('\\', '/')}",
                            fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          ),
                        )),
            ),
          ),
          
          // 2. Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. Ask AI Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0056D2),
                      side: const BorderSide(color: Color(0xFF0056D2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text("Ask AI"),
                    onPressed: () {
                      AskDocumentSheet.show(
                        context,
                        documentText: widget.content,
                        documentTitle: widget.title,
                        imagePath: widget.imagePath.isNotEmpty && File(widget.imagePath).existsSync()
                            ? widget.imagePath
                            : null,
                      );
                    },
                  ),
                  // 2. View Summary
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0056D2),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF0056D2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.article_outlined, size: 18),
                    label: const Text("Summary"),
                    onPressed: _showSummaryModal,
                  ),
                  // 3. Audio
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPlaying ? Colors.red[50] : const Color(0xFF0056D2),
                      foregroundColor: isPlaying ? Colors.red : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined, size: 18),
                    label: Text(isPlaying ? "Stop" : "Listen"),
                    onPressed: _toggleAudioSummary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}