import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OcrResult {
  final String summary;
  OcrResult({required this.summary});
}

// API Key Provider - loads dynamically from .env or --dart-define without committing secret keys
final geminiApiKeyProvider = Provider<String>((ref) {
  final envKey = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['API_KEY'];
  if (envKey != null && envKey.trim().isNotEmpty) {
    return envKey.trim();
  }
  return const String.fromEnvironment('API_KEY', defaultValue: '');
});

// Model Provider
final geminiModelProvider = Provider<GenerativeModel>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  if (apiKey.isEmpty) {
    throw Exception('API_KEY not found. Please provide GEMINI_API_KEY in .env or run with --dart-define=API_KEY=your_key');
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
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      state = AsyncValue.data(OcrResult(summary: "No text found to summarize."));
      return;
    }

    state = const AsyncValue.loading();
    final apiKey = ref.read(geminiApiKeyProvider);

    final prompt = """
Analyze the following raw OCR text and extract the key information into a clear list of bullet points.
Rules:
1. Provide only a list of bullet points.
2. Do not use headers, titles, or centered text.
3. Fix any obvious OCR typos while preserving the original details.

Raw OCR Text:
$cleanText
""";

    final candidateModels = [
      'gemini-3.8-flash',
      'gemini-3.6-flash',
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
    final bullets = lines.take(5).map((l) => "• $l").join('\n');
    state = AsyncValue.data(OcrResult(summary: "Document Summary:\n$bullets"));
  }
}