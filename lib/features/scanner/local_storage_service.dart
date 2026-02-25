import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  Future<String?> saveImageLocally(String tempImagePath) async {
    try {
      // 1. Get the app's permanent document directory
      final directory = await getApplicationDocumentsDirectory();
      
      // 2. Create a unique file name using the current timestamp
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // 3. Define the new permanent path on the phone
      final savedPath = '${directory.path}/$fileName';
      
      // 4. Copy the temporary file to the permanent location
      final File newFile = await File(tempImagePath).copy(savedPath);
      
      return newFile.path; // Return the safe, permanent path
    } catch (e) {
      print("Error saving image locally: $e");
      return null;
    }
  }
}