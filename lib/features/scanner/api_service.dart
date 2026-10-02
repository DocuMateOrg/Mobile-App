import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:documate/services/user_session.dart';

class ApiService {
  static const String baseHost = "http://10.0.2.2:3000";
  static const String baseUrl = "$baseHost/api";

  Future<String?> _getUserId() async {
    return await UserSession.getUserId();
  }

  Future<bool> saveDocumentMetadata({
    required String title,
    required String extractedText,
    required String localImagePath,
    int? folderId,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return false;

      final uri = Uri.parse('$baseUrl/documents');
      final request = http.MultipartRequest('POST', uri);

      // Add fields
      request.fields['userId'] = userId;
      request.fields['title'] = title;
      request.fields['content'] = extractedText;
      request.fields['localImagePath'] = localImagePath;
      if (folderId != null) {
        request.fields['folderId'] = folderId.toString();
      }

      // Add file
      final file = await http.MultipartFile.fromPath(
        'image', 
        localImagePath,
      );
      request.files.add(file);

      // Add headers
      request.headers['Authorization'] = 'Bearer $userId';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Error saving with upload: $e");
      return false;
    }
  }

  Future<List<dynamic>> fetchUserDocuments({int? folderId, String? searchQuery}) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return [];

      String url = '$baseUrl/documents/$userId';
      
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

      if (response.statusCode == 200) {
        return jsonDecode(response.body); 
      }
      return [];
    } catch (e) {
      print("CONNECTION ERROR: Could not reach backend at $baseUrl. Details: $e");
      return [];
    }
  }

  // --- 3. CREATE FOLDER ---
  Future<bool> createFolder(String name) async {
    try {
      final userId = await _getUserId();
      if (userId == null) return false;
      
      final response = await http.post(
        Uri.parse('$baseUrl/folders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
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
      final userId = await _getUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/folders/$userId'),
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

  // --- 5. DELETE FOLDER ---
  Future<bool> deleteFolder(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/folders/$id'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting folder: $e");
      return false;
    }
  }

  // --- 6. DELETE DOCUMENT ---
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

  // --- 7. UPDATE DOCUMENT (Title & Folder Assignment) ---
  Future<bool> updateDocument(
    int id, {
    String? title,
    int? folderId,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (folderId != null) body['folderId'] = folderId;

      final response = await http.put(
        Uri.parse('$baseUrl/documents/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error updating document: $e");
      return false;
    }
  }

  // --- 8. EXPORT & DOWNLOAD DOCUMENT (PDF / DOCX) ---
  String getExportUrl(int id, String format) {
    return '$baseUrl/documents/$id/export?format=$format';
  }

  Future<String?> downloadExportedFile(int id, String format) async {
    try {
      final url = getExportUrl(id, format);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/export_$id.$format');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
      return null;
    } catch (e) {
      print("Error downloading export: $e");
      return null;
    }
  }

  // --- 9. USER MANAGEMENT APIS ---
  Future<Map<String, dynamic>> checkUserExists(String email) async {
    try {
      final url = Uri.parse('$baseUrl/users/check?email=${Uri.encodeComponent(email)}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"exists": false, "user": null};
    } catch (e) {
      print("Error checking user existence: $e");
      return {"exists": false, "user": null};
    }
  }

  Future<bool> registerUser({
    required String email,
    required String username,
    String? authProvider,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/users/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'authProvider': authProvider ?? 'email',
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error registering user in DB: $e");
      return false;
    }
  }

  Future<bool> updateUserProfile({
    required String email,
    required String username,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/users/profile');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error updating user profile in DB: $e");
      return false;
    }
  }
}