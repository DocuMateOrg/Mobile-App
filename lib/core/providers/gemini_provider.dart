import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OcrResult {
  final String summary;
  OcrResult({required this.summary});
}

// API Key Provider
final geminiApiKeyProvider = Provider<String>((ref) {
  return const String.fromEnvironment('API_KEY', defaultValue: 'AIzaSyCkjm20_c5P8K-Y3TCVoddy7FQ9NdfZSyk');
});

// Model Provider
final geminiModelProvider = Provider<GenerativeModel>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  if (apiKey.isEmpty) {
    throw Exception('API_KEY not found. Run with --dart-define=API_KEY=your_key');
  }
  return GenerativeModel(
    model: 'gemini-2.5-flash', 
    apiKey: apiKey,
  );
});

// Main Summary Provider
final ocrSummaryProvider = AsyncNotifierProvider<OcrSummaryNotifier, OcrResult?>(() {
  return OcrSummaryNotifier();
});

class OcrSummaryNotifier extends AsyncNotifier<OcrResult?> {
  @override
  Future<OcrResult?> build() async => null;

  Future<void> summarizeText(String text) async {
    if (text.trim().isEmpty) {
      state = AsyncValue.error("No text found to summarize", StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    final model = ref.read(geminiModelProvider);

    state = await AsyncValue.guard(() async {
      final prompt = """
Analyze the following raw OCR text and extract the key information into a clear list of bullet points.
Rules:
1. Provide only a list of bullet points.
2. Do not use headers, titles, or centered text.
3. Fix any obvious OCR typos while preserving the original details.

Raw OCR Text:
$text
""";
      final response = await model.generateContent([Content.text(prompt)]);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception("Gemini returned an empty response.");
      }
      
      return OcrResult(summary: response.text!);
    });
  }
}