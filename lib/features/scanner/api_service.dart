import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // Use your laptop's Wi-Fi IPv4 address here!
  final String baseUrl = "http://192.168.8.100:3000/api"; 

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
  Future<List<dynamic>> fetchUserDocuments({int? folderId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      String url = '$baseUrl/documents/${user.uid}';
      if (folderId != null) {
        url += '?folderId=$folderId';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Returns a list of maps (your database rows)
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
}