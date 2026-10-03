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
    model: 'gemini-3.8-flash', 
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
    if (text.isEmpty) return;
    state = const AsyncValue.loading();
    final apiKey = ref.read(geminiApiKeyProvider);

    state = await AsyncValue.guard(() async {
      final prompt = "Summarize the following text in 3 concise bullet points:\n\n$text";
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

      return OcrResult(summary: "No summary generated ($lastError).");
    });
  }
}