import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OcrResult {
  final String summary;
  OcrResult({required this.summary});
}

// 1. Create a provider for the API Key
final geminiApiKeyProvider = Provider<String>((ref) {
  return const String.fromEnvironment('API_KEY', defaultValue: 'AIzaSyA0NzBJLFMAXyvurdGmPySRNpMQMvfgxkk');
});

// 2. Create the provider for the Generative Model
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

// 3. Notifier to handle the summary state
final ocrSummaryProvider = AsyncNotifierProvider<OcrSummaryNotifier, OcrResult?>(() {
  return OcrSummaryNotifier();
});

class OcrSummaryNotifier extends AsyncNotifier<OcrResult?> {
  @override
  Future<OcrResult?> build() async => null;

  /// Fast text-only summarization
  Future<void> summarizeText(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      state = AsyncValue.data(OcrResult(summary: "No text found to summarize."));
      return;
    }

    state = const AsyncValue.loading();
    final apiKey = ref.read(geminiApiKeyProvider);

    final prompt = "Summarize the following text in 3 concise bullet points:\n\n$cleanText";
    final candidateModels = [
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash-latest',
      'gemini-1.5-flash',
      'gemini-1.5-pro-latest',
      'gemini-1.5-pro',
    ];

    for (final modelName in candidateModels) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([Content.text(prompt)]);
        if (response.text != null && response.text!.isNotEmpty) {
          state = AsyncValue.data(OcrResult(summary: response.text!));
          return;
        }
      } catch (_) {
        // Try next candidate model
      }
    }

    // Fallback: Generate local summary from key sentences if Gemini API fails
    final lines = cleanText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final bullets = lines.take(4).map((l) => "• $l").join('\n');
    state = AsyncValue.data(OcrResult(summary: "Document Summary:\n$bullets"));
  }
}