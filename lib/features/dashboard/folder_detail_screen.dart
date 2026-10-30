import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../scanner/api_service.dart';
import '../../services/local_document_service.dart';
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
  final LocalDocumentService _localService = LocalDocumentService();
  late Future<List<dynamic>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  void _loadDocuments() {
    setState(() {
      _documentsFuture = _fetchCombinedDocuments();
    });
  }

  Future<List<dynamic>> _fetchCombinedDocuments() async {
    final List<dynamic> combined = [];

    // 1. Local documents in this folder
    try {
      final localDocs = await _localService.getLocalDocuments(folderId: widget.folderId);
      combined.addAll(localDocs);
    } catch (e) {
      debugPrint("Error fetching local folder docs: $e");
    }

    // 2. Remote documents in this folder
    try {
      final remoteDocs = await _apiService.fetchUserDocuments(folderId: widget.folderId);
      for (final rd in remoteDocs) {
        if (!combined.any((d) => d['id'] == rd['id'])) {
          combined.add(rd);
        }
      }
    } catch (e) {
      debugPrint("Remote folder docs notice: $e");
    }

    return combined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.folderName, style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadDocuments(),
        child: FutureBuilder<List<dynamic>>(
          future: _documentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error loading documents.", style: GoogleFonts.poppins()));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0056D2).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.folder_open_rounded, color: Color(0xFF0056D2), size: 48),
                      ),
                      const SizedBox(height: 16),
                      Text("No Documents In Folder", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        "Scan a document and choose this folder to organize it here.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            }

            final documents = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                final rawDate = doc['created_at']?.toString() ?? '';
                final displayDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : 'Recent';

                return DocumentCard(
                  documentId: doc['id'],
                  title: doc['title'] ?? 'Untitled',
                  time: displayDate,
                  pages: "1 page", 
                  size: "Saved", 
                  imagePath: doc['local_image_path'], 
                  serverImagePath: doc['server_image_path'],
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
