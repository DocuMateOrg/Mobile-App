import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:documate/features/scanner/api_service.dart';
import 'package:documate/features/dashboard/dashboard_screen.dart'; // For DocumentCard
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';

class EditDocumentsListScreen extends StatefulWidget {
  const EditDocumentsListScreen({super.key});

  @override
  State<EditDocumentsListScreen> createState() => _EditDocumentsListScreenState();
}

class _EditDocumentsListScreenState extends State<EditDocumentsListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  void _loadDocuments() {
    setState(() {
      _documentsFuture = _apiService.fetchUserDocuments();
    });
  }

  Future<void> _editDocumentImage(BuildContext context, Map<String, dynamic> doc) async {
    final imagePath = doc['local_image_path'];
    if (imagePath == null || !File(imagePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original image not found on this device.')),
      );
      return;
    }

    // Step 1: Crop the image
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Document',
            toolbarColor: const Color(0xFF0056D2),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
        IOSUiSettings(
          title: 'Crop Document',
        ),
      ],
    );

    if (croppedFile != null) {
      // TODO: Implement Brightness adjustment and save to backend.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cropped successfully! (Backend update needed to save)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Select Document to Edit", style: GoogleFonts.poppins(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _documentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No documents found.", style: GoogleFonts.poppins()));
          }

          final documents = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              final rawDate = doc['created_at'] ?? '';
              final displayDate = rawDate.length > 10 ? rawDate.substring(0, 10) : 'Just now';

              return InkWell(
                onTap: () => _editDocumentImage(context, doc),
                child: AbsorbPointer(
                  // Prevent the DocumentCard from navigating to DocumentDetailScreen
                  child: DocumentCard(
                    documentId: doc['id'],
                    title: doc['title'] ?? 'Untitled',
                    time: displayDate,
                    pages: "1 page",
                    size: "Local File",
                    imagePath: doc['local_image_path'],
                    serverImagePath: doc['server_image_path'],
                    content: doc['content'] ?? '',
                    onRefresh: _loadDocuments,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
