import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDocumentService {
  static const String _documentsKey = 'documate_local_documents';
  static const String _foldersKey = 'documate_local_folders';

  static final LocalDocumentService _instance = LocalDocumentService._internal();
  factory LocalDocumentService() => _instance;
  LocalDocumentService._internal();

  // --- FOLDERS ---
  Future<List<Map<String, dynamic>>> getLocalFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_foldersKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint("Error reading local folders: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createLocalFolder(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final folders = await getLocalFolders();

    // Generate local unique ID
    final int id = -(DateTime.now().millisecondsSinceEpoch % 1000000);
    final newFolder = {
      'id': id,
      'name': name.trim(),
      'created_at': DateTime.now().toIso8601String(),
      'is_local': true,
    };

    folders.insert(0, newFolder);
    await prefs.setString(_foldersKey, jsonEncode(folders));
    debugPrint("✅ Local folder created: $name (id: $id)");
    return newFolder;
  }

  Future<bool> deleteLocalFolder(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final folders = await getLocalFolders();
      folders.removeWhere((f) => f['id'] == id);
      await prefs.setString(_foldersKey, jsonEncode(folders));
      return true;
    } catch (e) {
      debugPrint("Error deleting local folder: $e");
      return false;
    }
  }

  // --- DOCUMENTS ---
  Future<List<Map<String, dynamic>>> getLocalDocuments({int? folderId, String? searchQuery}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_documentsKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> list = jsonDecode(jsonStr);
      List<Map<String, dynamic>> docs = list.map((e) => Map<String, dynamic>.from(e)).toList();

      if (folderId != null) {
        docs = docs.where((d) => d['folder_id'] == folderId || d['folderId'] == folderId).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        docs = docs.where((d) {
          final title = (d['title'] ?? '').toString().toLowerCase();
          final content = (d['content'] ?? '').toString().toLowerCase();
          final summary = (d['summary'] ?? '').toString().toLowerCase();
          return title.contains(query) || content.contains(query) || summary.contains(query);
        }).toList();
      }

      return docs;
    } catch (e) {
      debugPrint("Error reading local documents: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> saveLocalDocument({
    required String title,
    required String content,
    String? summary,
    required String localImagePath,
    int? folderId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final docs = await getLocalDocuments();

    final int id = -(DateTime.now().millisecondsSinceEpoch % 1000000);
    final newDoc = {
      'id': id,
      'title': title.trim().isEmpty ? "Untitled Document" : title.trim(),
      'content': content,
      'summary': summary ?? '',
      'local_image_path': localImagePath,
      'folder_id': folderId,
      'created_at': DateTime.now().toIso8601String(),
      'is_local': true,
    };

    docs.insert(0, newDoc);
    await prefs.setString(_documentsKey, jsonEncode(docs));
    debugPrint("✅ Local document saved: $title (id: $id)");
    return newDoc;
  }

  Future<bool> deleteLocalDocument(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final docs = await getLocalDocuments();
      docs.removeWhere((d) => d['id'] == id);
      await prefs.setString(_documentsKey, jsonEncode(docs));
      return true;
    } catch (e) {
      debugPrint("Error deleting local document: $e");
      return false;
    }
  }
}
