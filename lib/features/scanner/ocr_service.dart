import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  // Use the default script (Latin). You can change this for other languages.
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      // The magic happens here:
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      return recognizedText.text; // Returns the raw text found in the image
    } catch (e) {
      return "Error recognizing text: $e";
    }
  }

  void dispose() {
    _textRecognizer.close(); // Always close to prevent memory leaks
  }
}