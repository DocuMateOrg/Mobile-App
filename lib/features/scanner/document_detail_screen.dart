import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/providers/gemini_provider.dart';
import 'api_service.dart';

class DocumentDetailScreen extends ConsumerStatefulWidget {
  final int documentId;
  final String title;
  final String imagePath;
  final String content;

  const DocumentDetailScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.imagePath,
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

  void _exportDocument(String format) async {
    print("DEBUG: Exporting document ${widget.documentId} to $format");
    setState(() => _isExporting = true);

    try {
      final filePath = await ApiService().downloadExportedFile(widget.documentId, format);
      print("DEBUG: Exported file path: $filePath");
      
      if (filePath != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Exported to $format successfully!")),
          );
        }
        await OpenFilex.open(filePath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to export document.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showSummaryModal() {
    if (ref.read(ocrSummaryProvider).value == null) {
      ref.read(ocrSummaryProvider.notifier).summarizeText(widget.content);
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
            
            return Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "AI Summary",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0056D2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    summaryState.when(
                      data: (res) => SelectableText(
                        res?.summary ?? "No summary available.",
                        style: GoogleFonts.poppins(fontSize: 15, height: 1.5),
                      ),
                      loading: () => const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 15),
                            Text("Generating summary..."),
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
      await ref.read(ocrSummaryProvider.notifier).summarizeText(widget.content);
      
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not generate summary to read.")),
      );
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
                  ? Image.file(File(widget.imagePath), fit: BoxFit.contain)
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    ),
            ),
          ),
          
          // 2. Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0056D2),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF0056D2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text("View Summary"),
                    onPressed: _showSummaryModal,
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPlaying ? Colors.red[50] : const Color(0xFF0056D2),
                      foregroundColor: isPlaying ? Colors.red : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                    label: Text(isPlaying ? "Stop Audio" : "Audio Summary"),
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