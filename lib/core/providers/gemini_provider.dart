import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OcrResult {
  final String summary;
  OcrResult({required this.summary});
}

final geminiApiKeyProvider = Provider<String>((ref) {
  return const String.fromEnvironment('API_KEY');
});

final geminiModelProvider = Provider<GenerativeModel>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  if (apiKey.isEmpty) {
    throw Exception('API_KEY not found. Run with --dart-define=API_KEY=your_key');
  }
  
  return GenerativeModel(
    // FIX: Updated to Gemini 2.5 Flash. Remove 'models/' prefix.
    model: 'gemini-2.5-flash', 
    apiKey: apiKey,
  );
});

final ocrSummaryProvider = AsyncNotifierProvider<OcrSummaryNotifier, OcrResult?>(() {
  return OcrSummaryNotifier();
});

class OcrSummaryNotifier extends AsyncNotifier<OcrResult?> {
  @override
  Future<OcrResult?> build() async => null;

  /// NEW: Fast text-only summarization
  Future<void> summarizeText(String text) async {
    if (text.isEmpty) return;
    state = const AsyncValue.loading();
    final model = ref.read(geminiModelProvider);

    state = await AsyncValue.guard(() async {
      final prompt = "Summarize the following text in 3 concise bullet points:\n\n$text";
      final response = await model.generateContent([Content.text(prompt)]);
      return OcrResult(summary: response.text ?? "No summary generated.");
    });
  }
}