import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:documate/screens/profile_page.dart';
import 'package:documate/screens/voice_search_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:documate/features/scanner/api_service.dart';
import 'package:documate/features/scanner/document_detail_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:documate/features/scanner/result_screen.dart';
import 'package:documate/services/user_session.dart';
import 'package:documate/services/local_document_service.dart';
import 'package:documate/services/local_export_service.dart';
import 'package:documate/core/widgets/bouncing_button.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _documentsFuture;
  
  String _searchQuery = '';
  String _displayName = 'User';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDocuments();
  }

  Future<void> _loadUserData() async {
    final savedEmail = await UserSession.getEmail();
    final savedName = await UserSession.getUsername();

    if (savedEmail != null && savedEmail.contains('@')) {
      try {
        final checkResult = await ApiService().checkUserExists(savedEmail);
        if (checkResult['exists'] == true && checkResult['user'] != null) {
          final String? dbUsername = checkResult['user']?['username'];
          if (dbUsername != null && dbUsername.isNotEmpty) {
            await UserSession.updateUsername(dbUsername);
            if (mounted) {
              setState(() {
                _displayName = dbUsername;
              });
              return;
            }
          }
        }
      } catch (e) {
        debugPrint("Error loading user profile in dashboard: $e");
      }
    }

    if (mounted) {
      setState(() {
        _displayName = savedName ?? (savedEmail?.contains('@') == true ? savedEmail!.split('@')[0] : 'User');
      });
    }
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final clean = query.trim().replaceAll(RegExp(r'[.,!?]+$'), '');
      if (_searchQuery != clean) {
        setState(() {
          _searchQuery = clean;
        });
        _loadDocuments();
      }
    });
  }

  Future<List<dynamic>> _fetchCombinedDocuments() async {
    final List<dynamic> combined = [];

    // 1. Fetch local documents (instant offline access)
    try {
      final localDocs = await LocalDocumentService().getLocalDocuments(searchQuery: _searchQuery);
      combined.addAll(localDocs);
    } catch (e) {
      debugPrint("Error fetching local documents: $e");
    }

    // 2. Fetch remote documents
    try {
      final remoteDocs = await _apiService.fetchUserDocuments(searchQuery: _searchQuery);
      for (final rd in remoteDocs) {
        if (!combined.any((d) => d['id'] == rd['id'] || (d['title'] == rd['title'] && d['created_at'] == rd['created_at']))) {
          combined.add(rd);
        }
      }
    } catch (e) {
      debugPrint("Remote documents fetch notice: $e");
    }

    // 3. Fallback token-based filter to guarantee voice searches match local and remote docs
    if (_searchQuery.isNotEmpty) {
      final tokens = LocalDocumentService.extractSearchTokens(_searchQuery);
      final rawLower = _searchQuery.toLowerCase();
      return combined.where((d) {
        final title = (d['title'] ?? '').toString().toLowerCase();
        final content = (d['content'] ?? '').toString().toLowerCase();
        final summary = (d['summary'] ?? '').toString().toLowerCase();
        final category = (d['category'] ?? d['folder_name'] ?? '').toString().toLowerCase();

        if (title.contains(rawLower) || content.contains(rawLower) || summary.contains(rawLower) || category.contains(rawLower)) {
          return true;
        }

        if (tokens.isNotEmpty) {
          return tokens.any((t) =>
              title.contains(t) || content.contains(t) || summary.contains(t) || category.contains(t));
        }

        return false;
      }).toList();
    }

    return combined;
  }

  Future<void> _loadDocuments() async {
    _loadUserData();
    final future = _fetchCombinedDocuments();
    setState(() {
      _documentsFuture = future;
    });
  }

  void _handleLogout(BuildContext context) async {
    await UserSession.logout(context);
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
                "Hi, $_displayName 👋",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 5),
              Text(
                "Manage your docs",
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              QuickActionRow(onRefresh: _loadDocuments),
              
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
                        serverImagePath: doc['server_image_path'], 
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
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchQuery.isNotEmpty || _searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                          tooltip: "Clear Search",
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: BouncingPressable(
                          onTap: () async {
                            final String? voiceQuery = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const VoiceSearchScreen()),
                            );
                            if (voiceQuery != null && voiceQuery.trim().isNotEmpty) {
                              final cleanQuery = voiceQuery.trim().replaceAll(RegExp(r'[.,!?]+$'), '');
                              _searchController.text = cleanQuery;
                              _onSearchChanged(cleanQuery);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0056D2).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: Color(0xFF0056D2),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
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
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfilePage()),
                          );
                          _loadUserData();
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
  final VoidCallback? onRefresh;
  const QuickActionRow({super.key, this.onRefresh});

  Future<void> _handleUpload(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image != null && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(imagePath: image.path),
          ),
        );
        if (onRefresh != null) {
          onRefresh!();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading document image: $e")),
        );
      }
    }
  }

  void _showConvertDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Convert Document Format",
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              "Export saved docs or convert photos into PDF or Word (.docx):",
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0056D2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF0056D2), size: 26),
              ),
              title: Text("Convert Saved Document", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text("Select any saved document to export as PDF or Word", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _showPickDocumentToConvert(context);
              },
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_search_outlined, color: Colors.green, size: 26),
              ),
              title: Text("Convert Photo from Gallery", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text("Extract text from an image & immediately convert", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _convertPhotoFromGallery(context);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showPickDocumentToConvert(BuildContext context) async {
    final docs = await LocalDocumentService().getLocalDocuments();
    if (!context.mounted) return;

    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No saved documents found to convert. Scan or upload one first!")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Choose Document to Convert",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text("Tap a document to choose PDF or Word export", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final title = d['title'] ?? 'Document';
                    final category = d['category'] ?? 'General';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEBF3FF),
                        child: Icon(Icons.description, color: Color(0xFF0056D2)),
                      ),
                      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(category, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.pop(ctx);
                        _promptFormatAndExport(context, d);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptFormatAndExport(BuildContext context, Map<String, dynamic> doc) {
    final title = doc['title'] ?? 'Document';
    final content = doc['content'] ?? '';
    final localImagePath = doc['local_image_path'];

    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Export \"$title\"", style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text("Select your desired export format:"),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            label: const Text("PDF Document"),
            onPressed: () async {
              Navigator.pop(dlgContext);
              final path = await LocalExportService.exportToPdf(
                title: title,
                content: content,
                imagePath: localImagePath,
              );
              if (path != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Converted to PDF successfully!")),
                  );
                }
                await OpenFilex.open(path);
              }
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.description, color: Colors.blue),
            label: const Text("Word (.docx)"),
            onPressed: () async {
              Navigator.pop(dlgContext);
              final path = await LocalExportService.exportToWordDoc(
                title: title,
                content: content,
                imagePath: localImagePath,
              );
              if (path != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Converted to Word successfully!")),
                  );
                }
                await OpenFilex.open(path);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _convertPhotoFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (image == null || !context.mounted) return;

      // Extract text
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(InputImage.fromFilePath(image.path));
      await textRecognizer.close();

      final ocrText = recognizedText.text.trim();
      final docTitle = "Converted_${DateTime.now().millisecondsSinceEpoch % 10000}";

      if (!context.mounted) return;
      _promptFormatAndExport(context, {
        'title': docTitle,
        'content': ocrText.isNotEmpty ? ocrText : "Image converted document.",
        'local_image_path': image.path,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Convert error: $e")),
        );
      }
    }
  }

  void _showEditDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Edit Documents & Photos",
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              "Crop image borders, enhance scans, or edit document text:",
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.crop_rotate_outlined, color: Colors.orange, size: 26),
              ),
              title: Text("Crop & Enhance Photo", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text("Crop, straighten, and adjust image borders", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _cropAndEnhanceImage(context);
              },
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0056D2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_note_outlined, color: Color(0xFF0056D2), size: 26),
              ),
              title: Text("Edit Document Text & Title", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text("Modify titles, extracted OCR content, or notes", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _showPickDocumentToEdit(context);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _cropAndEnhanceImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (image == null || !context.mounted) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop & Enhance',
            toolbarColor: const Color(0xFF0056D2),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop & Enhance'),
        ],
      );

      if (croppedFile != null && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ResultScreen(imagePath: croppedFile.path)),
        );
        if (onRefresh != null) onRefresh!();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Crop error: $e")),
        );
      }
    }
  }

  void _showPickDocumentToEdit(BuildContext context) async {
    final docs = await LocalDocumentService().getLocalDocuments();
    if (!context.mounted) return;

    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No saved documents found to edit.")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Select Document to Edit",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text("Tap any document to update its title and text", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final title = d['title'] ?? 'Document';
                    final category = d['category'] ?? 'General';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFF3DC),
                        child: Icon(Icons.edit, color: Colors.orange),
                      ),
                      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(category, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      trailing: const Icon(Icons.edit_outlined, color: Color(0xFF0056D2), size: 20),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openEditDocumentSheet(context, d);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditDocumentSheet(BuildContext context, Map<String, dynamic> doc) {
    final titleController = TextEditingController(text: doc['title'] ?? '');
    final contentController = TextEditingController(text: doc['content'] ?? '');
    final docId = doc['id'] is int ? doc['id'] : int.tryParse(doc['id'].toString()) ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (editCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(editCtx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Edit Document",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: "Document Title",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contentController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: "Document Text / Content",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056D2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () async {
                    final newTitle = titleController.text.trim();
                    final newContent = contentController.text.trim();
                    await LocalDocumentService().updateLocalDocument(
                      id: docId,
                      title: newTitle.isNotEmpty ? newTitle : "Document",
                      content: newContent,
                    );
                    if (editCtx.mounted) Navigator.pop(editCtx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Document updated successfully!")),
                      );
                    }
                    if (onRefresh != null) onRefresh!();
                  },
                  child: Text("Save Changes", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(
          Icons.document_scanner_outlined,
          "scan",
          const Color(0xFFC0FE72),
          const Color(0xFF88C928),
          () async {
            final result = await context.push('/scan');
            if (result == true && onRefresh != null) {
              onRefresh!();
            }
          },
        ),
        _buildActionButton(
          Icons.edit_outlined,
          "edit",
          const Color(0xFFFFDB99),
          const Color(0xFFD69A2D),
          () => _showEditDialog(context),
        ),
        _buildActionButton(
          Icons.transform_outlined,
          "convert",
          const Color(0xFFC2D3FF),
          const Color(0xFF5A7ED2),
          () => _showConvertDialog(context),
        ),
        _buildActionButton(
          Icons.folder_open_outlined,
          "folders",
          const Color(0xFFE4C1F9),
          const Color(0xFF9E5CBF),
          () async {
            await context.push('/folders');
            if (onRefresh != null) {
              onRefresh!();
            }
          },
        ),
        _buildActionButton(
          Icons.cloud_upload_outlined,
          "uploaded",
          const Color(0xFFFFB3B3),
          const Color(0xFFD9534F),
          () => _handleUpload(context),
        ),
      ],
    );
  }

    Widget _buildActionButton(IconData icon, String label, Color bgColor, Color iconColor, VoidCallback onTap) {
    return BouncingPressable(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label, 
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12, 
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
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
  final String? serverImagePath; 
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
    this.serverImagePath,
    this.content = '', 
  });

  @override
  Widget build(BuildContext context) {
    final bool fileExists = imagePath != null && File(imagePath!).existsSync();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentDetailScreen(
              documentId: documentId,
              title: title,
              imagePath: imagePath ?? '',
              serverImagePath: serverImagePath,
              content: content,
            ),
          ),
        );
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
                    : (serverImagePath != null 
                        ? Image.network(
                            "${ApiService.baseHost}/${serverImagePath!.replaceAll('\\', '/')}",
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                          )
                        : const Icon(Icons.description, color: Colors.blue, size: 20)),
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
              if (documentId < 0) {
                await LocalDocumentService().deleteLocalDocument(documentId);
              } else {
                await ApiService().deleteDocument(documentId);
                await LocalDocumentService().deleteLocalDocument(documentId);
              }
              onRefresh();
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