import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../scanner/api_service.dart';
import '../../services/local_document_service.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final ApiService _apiService = ApiService();
  final LocalDocumentService _localService = LocalDocumentService();
  late Future<List<dynamic>> _foldersFuture;
  final TextEditingController _folderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  void _loadFolders() {
    setState(() {
      _foldersFuture = _fetchCombinedFolders();
    });
  }

  Future<List<dynamic>> _fetchCombinedFolders() async {
    final List<dynamic> combined = [];

    // 1. Fetch local folders (instant)
    try {
      final localFolders = await _localService.getLocalFolders();
      combined.addAll(localFolders);
    } catch (e) {
      debugPrint("Error fetching local folders: $e");
    }

    // 2. Fetch remote folders
    try {
      final remoteFolders = await _apiService.fetchFolders();
      for (final rf in remoteFolders) {
        if (!combined.any((f) => f['id'] == rf['id'] || f['name'] == rf['name'])) {
          combined.add(rf);
        }
      }
    } catch (e) {
      debugPrint("Remote folders offline notice: $e");
    }

    return combined;
  }

  void _showCreateFolderDialog() {
    _folderNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.create_new_folder_rounded, color: Color(0xFF0056D2)),
            const SizedBox(width: 10),
            Text("Create New Folder", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: TextField(
          controller: _folderNameController,
          autofocus: true,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: "Folder name (e.g. Invoices, Receipts)",
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              final name = _folderNameController.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context); // close dialog

              // 1. Create locally (guaranteed instant success)
              await _localService.createLocalFolder(name);

              // 2. Try remote in background
              _apiService.createFolder(name).catchError((_) => false);

              if (!mounted) return;

              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text("Folder \"$name\" created successfully!"),
                  backgroundColor: Colors.green[700],
                  behavior: SnackBarBehavior.floating,
                ),
              );
              _loadFolders();
            },
            child: Text("Create", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Folders", style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadFolders(),
        child: FutureBuilder<List<dynamic>>(
          future: _foldersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error loading folders.", style: GoogleFonts.poppins()));
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
                      Text("No Folders Yet", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        "Organize your documents into folders like Invoices, Receipts, or Medical.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _showCreateFolderDialog,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text("Create First Folder", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0056D2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final folders = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                final folderId = folder['id'] as int;
                final folderName = folder['name'] ?? 'Untitled';
                final createdAt = folder['created_at']?.toString() ?? '';
                final displayDate = createdAt.length >= 10 ? createdAt.substring(0, 10) : 'Recent';

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  color: Colors.white,
                  child: InkWell(
                    onTap: () => context.push('/folders/$folderId', extra: folderName),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0056D2).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.folder_rounded, color: Color(0xFF0056D2), size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folderName,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Created: $displayDate",
                                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400], size: 22),
                            onPressed: () => _showDeleteFolderConfirmation(folderId, folderName),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateFolderDialog,
        backgroundColor: const Color(0xFF0056D2),
        elevation: 3,
        child: const Icon(Icons.create_new_folder_rounded, color: Colors.white),
      ),
    );
  }

  void _showDeleteFolderConfirmation(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Folder?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete \"$name\"?", style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              if (id < 0) {
                await _localService.deleteLocalFolder(id);
              } else {
                await _apiService.deleteFolder(id);
                await _localService.deleteLocalFolder(id);
              }
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text("Folder \"$name\" deleted.")),
                );
                _loadFolders();
              }
            },
            child: Text("Delete", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
