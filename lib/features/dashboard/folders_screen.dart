import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../scanner/api_service.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _foldersFuture;
  final TextEditingController _folderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  void _loadFolders() {
    setState(() {
      _foldersFuture = _apiService.fetchFolders();
    });
  }

  void _showCreateFolderDialog() {
    _folderNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Create New Folder", style: GoogleFonts.poppins()),
        content: TextField(
          controller: _folderNameController,
          decoration: const InputDecoration(hintText: "Enter folder name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _folderNameController.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context); // close dialog

              final success = await _apiService.createFolder(name);
              if (!context.mounted) return;

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Folder created successfully!")),
                );
                _loadFolders();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to create folder.")),
                );
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Folders", style: GoogleFonts.poppins(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadFolders(),
        child: FutureBuilder<List<dynamic>>(
          future: _foldersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text("Error loading folders."));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No folders created yet."));
            }

            final folders = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => context.push('/folders/${folder['id']}', extra: folder['name']),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.folder, color: Colors.blue, size: 40),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(folder['name'] ?? 'Untitled', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                                Text("Created: ${folder['created_at']?.substring(0, 10) ?? ''}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
                            onPressed: () {
                              print("DEBUG: Delete Button Pressed for folder ${folder['id']}");
                              _showDeleteFolderConfirmation(folder['id'], folder['name'] ?? 'Untitled');
                            },
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
        child: const Icon(Icons.create_new_folder, color: Colors.white),
      ),
    );
  }

  void _showDeleteFolderConfirmation(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Folder", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete '$name'? The documents inside will NOT be deleted; they will move back to your Recent Scans."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final success = await _apiService.deleteFolder(id);
              if (success) {
                _loadFolders();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Folder deleted")));
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
