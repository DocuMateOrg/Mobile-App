import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'api_service.dart';

class DocumentDetailScreen extends StatefulWidget {
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
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  bool _isExporting = false;

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

  @override
  Widget build(BuildContext context) {
    final bool fileExists = File(widget.imagePath).existsSync();
    print("DEBUG: Detail Screen - ID: ${widget.documentId}, Path: ${widget.imagePath}, Exists: $fileExists");

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
                      widget.content.isNotEmpty ? widget.content : "No text was extracted for this document.",
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