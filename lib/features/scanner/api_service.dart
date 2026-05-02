import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ApiService {
  final String baseUrl = "http://localhost:3000/api";

  // --- 1. THE SAVE METHOD ---
  Future<bool> saveDocumentMetadata({
    required String title,
    required String extractedText,
    required String localImagePath,
    int? folderId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      final response = await http.post(
        Uri.parse('$baseUrl/documents'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user?.uid}', 
        },
        body: jsonEncode({
          'userId': user?.uid,
          'title': title,
          'content': extractedText,
          'localImagePath': localImagePath, 
          'folderId': folderId,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Error saving to API: $e");
      return false;
    }
  }

  // --- 2. THE FETCH METHOD ---
  Future<List<dynamic>> fetchUserDocuments({int? folderId, String? searchQuery}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      String url = '$baseUrl/documents/${user.uid}';
      
      List<String> queryParams = [];
      if (folderId != null) {
        queryParams.add('folderId=$folderId');
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        queryParams.add('search=${Uri.encodeComponent(searchQuery.trim())}');
      }
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      print("Fetching from: $url");
      final response = await http.get(Uri.parse(url));
      print("Status: ${response.statusCode}");
      print("Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body); 
      }
      return [];
    } catch (e) {
      print("Error fetching documents: $e");
      return [];
    }
  }

  // --- 3. CREATE FOLDER ---
  Future<bool> createFolder(String name) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      final response = await http.post(
        Uri.parse('$baseUrl/folders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': user.uid,
          'name': name,
        }),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Error creating folder: $e");
      return false;
    }
  }

  // --- 4. FETCH FOLDERS ---
  Future<List<dynamic>> fetchFolders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/folders/${user.uid}'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body); 
      }
      return [];
    } catch (e) {
      print("Error fetching folders: $e");
      return [];
    }
  }

  // --- 5. DELETE DOCUMENT ---
  Future<bool> deleteDocument(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/documents/$id'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting document: $e");
      return false;
    }
  }

  // --- 6. UPDATE DOCUMENT ---
  Future<bool> updateDocument(int id, {String? title, int? folderId}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/documents/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (title != null) 'title': title,
          'folderId': folderId, // Can be null to remove from folder
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error updating document: $e");
      return false;
    }
  }

  // --- 5. EXPORT DOCUMENT ---
  Future<String?> downloadExportedFile(int id, String format) async {
    try {
      final url = '$baseUrl/documents/$id/export?format=$format';
      print("DEBUG: Export URL: $url");
      final response = await http.get(Uri.parse(url));
      print("DEBUG: Export Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = "Exported_Doc_${id}_${DateTime.now().millisecondsSinceEpoch}.$format";
        final filePath = "${directory.path}/$fileName";
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      print("Export Error: $e");
      return null;
    }
  }
}