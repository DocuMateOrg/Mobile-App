import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OcrResult {
  final String summary;
  final String? suggestedTitle;
  final String? suggestedCategory;
  OcrResult({
    required this.summary,
    this.suggestedTitle,
    this.suggestedCategory,
  });
}

// API Key Provider - loads dynamically from .env or --dart-define without committing secret keys
final geminiApiKeyProvider = Provider<String>((ref) {
  final envKey = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['API_KEY'];
  if (envKey != null && envKey.trim().isNotEmpty) {
    return envKey.trim();
  }
  return const String.fromEnvironment('API_KEY', defaultValue: '');
});

// Primary Working Model Provider
final geminiModelProvider = Provider<GenerativeModel>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  if (apiKey.isEmpty) {
    throw Exception('API_KEY not found. Please provide GEMINI_API_KEY in .env or run with --dart-define=API_KEY=your_key');
  }
  return GenerativeModel(
    model: 'gemini-2.5-flash', 
    apiKey: apiKey,
  );
});

// Candidate models ordered by reliability and availability
const List<String> kGeminiCandidateModels = [
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-flash-latest',
  'gemini-2.5-pro',
  'gemini-2.0-flash',
  'gemini-3.5-flash',
  'gemini-3.8-flash',
];

// Gemini Service for direct AI calls (Q&A, suggestions, summaries)
class GeminiService {
  final String apiKey;
  GeminiService(this.apiKey);

  Future<String?> _callWithFallback(String prompt) async {
    if (apiKey.isEmpty) {
      debugPrint("⚠️ GeminiService: API key is empty");
      return null;
    }

    for (final modelName in kGeminiCandidateModels) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([Content.text(prompt)]);
        if (response.text != null && response.text!.trim().isNotEmpty) {
          debugPrint("✅ Gemini response received from model: $modelName");
          return response.text!.trim();
        }
      } catch (e) {
        debugPrint("⚠️ Gemini model $modelName failed: $e");
      }
    }
    return null;
  }

  // 1. Generate Structured Summary
  Future<String> summarizeText(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return "No text found to summarize.";

    final prompt = """
Analyze the following raw OCR document text and extract the key information into a clear list of bullet points.
Rules:
1. Provide a concise, bulleted summary (3-7 bullets maximum).
2. Highlight essential facts (amounts, dates, people, obligations, action items).
3. Do not include introductory phrases like "Here is a summary".
4. Fix any obvious OCR scanning typos.

Raw OCR Text:
$cleanText
""";

    final result = await _callWithFallback(prompt);
    if (result != null && result.isNotEmpty) {
      return result;
    }

    // Fallback: local bullet generator
    final lines = cleanText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final bullets = lines.take(5).map((l) => "• $l").join('\n');
    return "Document Highlights:\n$bullets";
  }

  // 2. Smart Auto-Naming & Category Suggestion
  Future<Map<String, String>> suggestMetadata(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return {
        'title': 'Scanned Document',
        'category': 'General',
      };
    }

    final prompt = """
Analyze this scanned document text and return a JSON object with:
1. "title": A concise, descriptive title (maximum 4-6 words, e.g. "Electricity Bill - Oct 2026", "Apartment Lease Contract", "Blood Test Report").
2. "category": A single-word category from: Receipts, Invoices, Medical, Legal, Academic, Personal, Work.

Output ONLY valid JSON without markdown wrapping. Format:
{"title": "...", "category": "..."}

Text:
${cleanText.length > 1500 ? cleanText.substring(0, 1500) : cleanText}
""";

    final result = await _callWithFallback(prompt);
    if (result != null) {
      try {
        final cleanedJson = result.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> parsed = jsonDecode(cleanedJson);
        return {
          'title': (parsed['title'] ?? 'Scanned Document').toString().replaceAll('"', '').trim(),
          'category': (parsed['category'] ?? 'General').toString().replaceAll('"', '').trim(),
        };
      } catch (e) {
        debugPrint("Error parsing metadata JSON: $e");
      }
    }

    // Local fallback
    final firstLine = cleanText.split('\n').firstWhere((l) => l.trim().length > 3, orElse: () => "Document");
    final title = firstLine.length > 25 ? "${firstLine.substring(0, 25)}..." : firstLine;
    return {
      'title': title,
      'category': 'General',
    };
  }

  // 3. Interactive Document Q&A (Ask Gemini about the Document)
  Future<String> askDocument(String documentText, String question) async {
    if (documentText.trim().isEmpty) return "The document contains no readable text to answer questions.";
    if (question.trim().isEmpty) return "Please enter a question about the document.";

    final prompt = """
You are DocuMate AI, an intelligent document assistant. Answer the user's question based strictly on the following scanned document text.
If the answer is not mentioned in the text, politely state that it is not found in the document.

Document Text:
$documentText

User Question:
$question

Provide a direct, helpful, concise answer.
""";

    final answer = await _callWithFallback(prompt);
    return answer ?? "Unable to analyze the document right now. Please check your internet connection.";
  }
}

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  return GeminiService(apiKey);
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
    final service = ref.read(geminiServiceProvider);

    try {
      // Run summary and smart metadata extraction concurrently
      final summaryFuture = service.summarizeText(cleanText);
      final metadataFuture = service.suggestMetadata(cleanText);

      final summary = await summaryFuture;
      final metadata = await metadataFuture;

      state = AsyncValue.data(OcrResult(
        summary: summary,
        suggestedTitle: metadata['title'],
        suggestedCategory: metadata['category'],
      ));
    } catch (e) {
      debugPrint("OCR Summary Error: $e");
      final lines = cleanText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final bullets = lines.take(5).map((l) => "• $l").join('\n');
      state = AsyncValue.data(OcrResult(summary: "Document Summary:\n$bullets"));
    }
  }
}