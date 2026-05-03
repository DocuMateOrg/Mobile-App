import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:documate/screens/profile_page.dart';
import 'package:documate/screens/voice_search_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:documate/features/scanner/api_service.dart';
import 'package:documate/features/scanner/document_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _documentsFuture;
  
  String _searchQuery = '';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        setState(() {
          _searchQuery = query;
        });
        _loadDocuments();
      }
    });
  }

  Future<void> _loadDocuments() async {
    final user = FirebaseAuth.instance.currentUser;
    print("DEBUG: Loading documents for user: ${user?.uid}");
    
    final future = _apiService.fetchUserDocuments(searchQuery: _searchQuery);
    setState(() {
      _documentsFuture = future;
    });

    try {
      final docs = await future;
      print("DEBUG: Found ${docs.length} documents");
    } catch (e) {
      print("DEBUG: Error loading documents: $e");
    }
  }

  void _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  Widget _buildPlaceholderLine(double width) {
    return Container(
      width: width,
      height: 4,
      color: Colors.grey[300],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          "Home",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.black, size: 28),
                onPressed: () {},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '2',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0056D2)),
              child: Text("Menu", style: GoogleFonts.poppins(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _handleLogout(context),
            ),
          ],
        ),
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
              const SizedBox(height: 15),

              const QuickActionRow(),
              
              const SizedBox(height: 30),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Documents",
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
                      child: Column(
                        children: [
                          Text("Error loading documents.", style: GoogleFonts.poppins(color: Colors.red)),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _loadDocuments,
                            child: const Text("Try Again"),
                          ),
                        ],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 40.0),
                      child: Center(
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 100,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 30,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF0056D2),
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            height: 4,
                                            width: 40,
                                            color: Colors.white.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      _buildPlaceholderLine(60),
                                      const SizedBox(height: 8),
                                      _buildPlaceholderLine(80),
                                      const SizedBox(height: 8),
                                      _buildPlaceholderLine(60),
                                      const SizedBox(height: 8),
                                      _buildPlaceholderLine(40),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text("No Recent Files", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      ),
                    );
                  }

                  final documents = snapshot.data!;
                  final recentDocs = documents.take(5).toList();

                  return Column(
                    children: recentDocs.map((doc) {
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
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
                  prefixIcon: const Icon(Icons.search, color: Colors.black54, size: 24),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.speaker_phone_outlined, color: Colors.black54),
                    onPressed: () async {
                      final String? voiceQuery = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VoiceSearchScreen()),
                      );
                      if (voiceQuery != null && voiceQuery.trim().isNotEmpty) {
                        _searchController.text = voiceQuery.trim();
                        _onSearchChanged(voiceQuery.trim());
                      }
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Bottom Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0056D2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.grid_view, color: Color(0xFF0056D2), size: 20),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfilePage()),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.person_outline, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
                FloatingActionButton(
                  onPressed: () async {
                    final result = await context.push('/scan');
                    if (result == true) {
                      _loadDocuments();
                    }
                  },
                  backgroundColor: const Color(0xFF0056D2),
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
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
        _buildActionButton(Icons.document_scanner_outlined, "scan", const Color(0xFFC0FE72), const Color(0xFF88C928), () => context.push('/scan')),
        _buildActionButton(Icons.edit_outlined, "edit", const Color(0xFFFFDB99), const Color(0xFFD69A2D), () {}),
        _buildActionButton(Icons.transform_outlined, "convert", const Color(0xFFC2D3FF), const Color(0xFF5A7ED2), () {}),
        _buildActionButton(Icons.folder_open_outlined, "folders", const Color(0xFFE4C1F9), const Color(0xFF9E5CBF), () => context.push('/folders')),
        _buildActionButton(Icons.cloud_upload_outlined, "uploaded", const Color(0xFFFFB3B3), const Color(0xFFD9534F), () {}),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color bgColor, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87)),
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
                documentId: documentId,
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
              color: Colors.grey.withValues(alpha: 0.05),
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