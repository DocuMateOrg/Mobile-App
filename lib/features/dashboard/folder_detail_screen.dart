import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../scanner/api_service.dart';
import 'dashboard_screen.dart'; // To reuse DocumentCard

class FolderDetailScreen extends StatefulWidget {
  final int folderId;
  final String folderName;

  const FolderDetailScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  void _loadDocuments() {
    setState(() {
      _documentsFuture = _apiService.fetchUserDocuments(folderId: widget.folderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.folderName, style: GoogleFonts.poppins(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadDocuments(),
        child: FutureBuilder<List<dynamic>>(
          future: _documentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text("Error loading documents."));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No documents in this folder."));
            }

            final documents = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                final rawDate = doc['created_at'] ?? '';
                final displayDate = rawDate.length > 10 ? rawDate.substring(0, 10) : 'Just now';

                return DocumentCard(
                  documentId: doc['id'],
                  title: doc['title'] ?? 'Untitled',
                  time: displayDate,
                  pages: "1 page", 
                  size: "Local File", 
                  imagePath: doc['local_image_path'], 
                  content: doc['content'] ?? '',
                  onRefresh: _loadDocuments,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
