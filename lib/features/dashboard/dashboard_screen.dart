import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:documate/screens/profile_page.dart';
import 'package:documate/screens/voice_search_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:documate/features/scanner/api_service.dart';
import 'package:documate/features/scanner/document_detail_screen.dart';
import 'package:documate/screens/voice_search_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _documentsFuture;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  // Fetch data from Node.js backend
  void _loadDocuments() {
    setState(() {
      _documentsFuture = _apiService.fetchUserDocuments();
    });
  }

  void _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.black),
          onPressed: () => _handleLogout(context),
        ),
        title: Text(
          "Home",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: Color(0xFF0056D2), size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VoiceSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.orange),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadDocuments(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), 
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hi, ${user?.email?.split('@')[0] ?? 'User'} 👋",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 5),
              Text(
                "Manage your docs",
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 25),

              const QuickActionRow(),
              
              const SizedBox(height: 30),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Scans",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 20, color: Colors.blue[700]),
                ],
              ),
              
              const SizedBox(height: 15),

              FutureBuilder<List<dynamic>>(
                future: _documentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text("Error loading documents.", style: GoogleFonts.poppins(color: Colors.red)),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text("No documents scanned yet.", style: GoogleFonts.poppins(color: Colors.grey)),
                    );
                  }

                  final documents = snapshot.data!;
                  final recentDocs = documents.take(5).toList();

                  return ListView.builder(
                    shrinkWrap: true, 
                    physics: const NeverScrollableScrollPhysics(), 
                    itemCount: recentDocs.length,
                    itemBuilder: (context, index) {
                      final doc = recentDocs[index];
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
           // Wait for the scan process to finish and return a result
           final result = await context.push('/scan');
           
           // If the result is exactly 'true', refresh the list
           if (result == true) {
             _loadDocuments();
           }
        },
        backgroundColor: const Color(0xFF0056D2),
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class QuickActionRow extends StatelessWidget {
  const QuickActionRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(Icons.document_scanner_outlined, "Scan", Colors.green, () => context.push('/scan')),
        _buildActionButton(Icons.edit_outlined, "Edit", Colors.orange, () {}),
        _buildActionButton(Icons.transform_outlined, "Convert", Colors.purple, () {}),
        _buildActionButton(Icons.folder_open_outlined, "Folders", Colors.blue, () => context.push('/folders')),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12)),
        ],
      ),
    );
  }
}

class DocumentCard extends StatelessWidget {
  final int documentId;
  final String title;
  final String time;
  final String pages;
  final String size;
  final String? imagePath; 
  final String content; 
  final VoidCallback onRefresh;

  const DocumentCard({
    super.key,
    required this.documentId,
    required this.title,
    required this.time,
    required this.pages,
    required this.size,
    required this.onRefresh,
    this.imagePath,
    this.content = '', 
  });

  @override
  Widget build(BuildContext context) {
    final bool fileExists = imagePath != null && File(imagePath!).existsSync();

    return InkWell(
      onTap: () {
        if (imagePath != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentDetailScreen(
                title: title,
                imagePath: imagePath!,
                content: content,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: fileExists
                    ? Image.file(File(imagePath!), fit: BoxFit.cover)
                    : const Icon(Icons.description, color: Colors.blue, size: 20),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$time • $pages",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(context, value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'update', child: Text('Update Folder')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
              icon: const Icon(Icons.more_vert, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    if (action == 'rename') {
      _showRenameDialog(context);
    } else if (action == 'update') {
      _showUpdateFolderDialog(context);
    } else if (action == 'delete') {
      _showDeleteConfirmation(context);
    }
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Document"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new title"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                final success = await ApiService().updateDocument(documentId, title: newTitle);
                if (success) onRefresh();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  void _showUpdateFolderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<dynamic>>(
        future: ApiService().fetchFolders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final folders = snapshot.data!;
          return AlertDialog(
            title: const Text("Move to Folder"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: folders.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      title: const Text("None (Remove from folder)"),
                      onTap: () async {
                        await ApiService().updateDocument(documentId, folderId: null);
                        onRefresh();
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  }
                  final folder = folders[index - 1];
                  return ListTile(
                    title: Text(folder['name']),
                    onTap: () async {
                      await ApiService().updateDocument(documentId, folderId: folder['id']);
                      onRefresh();
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Document"),
        content: const Text("Are you sure you want to delete this document?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await ApiService().deleteDocument(documentId);
              if (success) onRefresh();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class CustomBottomNav extends StatelessWidget {
  const CustomBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      elevation: 10,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.grid_view, color: Color(0xFF0056D2)),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.grey),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}