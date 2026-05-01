import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // Use localhost because adb reverse tcp:3000 tcp:3000 maps it to your laptop
  final String baseUrl = "http://127.0.0.1:3000/api"; 

  // --- 1. THE SAVE METHOD ---
  Future<bool> saveDocumentMetadata({
    required String title,
    required String extractedText,
    required String localImagePath,
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
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Error saving to API: $e");
      return false;
    }
  }

  // --- 2. THE FETCH METHOD (This fixes your error) ---
  Future<List<dynamic>> fetchUserDocuments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/documents/${user.uid}'),
      );

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
}