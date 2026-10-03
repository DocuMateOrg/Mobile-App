import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OcrResult {
  final String summary;
  OcrResult({required this.summary});
}

// API Key Provider
final geminiApiKeyProvider = Provider<String>((ref) {
  return const String.fromEnvironment('API_KEY', defaultValue: 'AIzaSyA0NzBJLFMAXyvurdGmPySRNpMQMvfgxkk');
});

// Model Provider
final geminiModelProvider = Provider<GenerativeModel>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  if (apiKey.isEmpty) {
    throw Exception('API_KEY not found. Run with --dart-define=API_KEY=your_key');
  }
  return GenerativeModel(
    model: 'gemini-3.8-flash', 
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
    final apiKey = ref.read(geminiApiKeyProvider);

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

      final candidateModels = [
        'gemini-3.8-flash',
        'gemini-3.6-flash',
        'gemini-2.0-flash',
        'gemini-1.5-flash'
      ];

      Object? lastError;
      for (final modelName in candidateModels) {
        try {
          final model = GenerativeModel(model: modelName, apiKey: apiKey);
          final response = await model.generateContent([Content.text(prompt)]);
          if (response.text != null && response.text!.isNotEmpty) {
            return OcrResult(summary: response.text!);
          }
        } catch (e) {
          lastError = e;
        }
      }

      throw Exception("All Gemini models failed: $lastError");
    });
  }
}