import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OcrResult {
  final String summary;
  final String? suggestedTitle;
  final String? suggestedCategory;
  final bool isVisualDescription;

  OcrResult({
    required this.summary,
    this.suggestedTitle,
    this.suggestedCategory,
    this.isVisualDescription = false,
  });
}

// API Key Provider - loads dynamically from .env or --dart-define
final geminiApiKeyProvider = Provider<String>((ref) {
  final envKey = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['API_KEY'];
  if (envKey != null && envKey.trim().isNotEmpty) {
    return envKey.trim();
  }
  const compileKey = String.fromEnvironment('API_KEY', defaultValue: '');
  if (compileKey.isNotEmpty) return compileKey;
  return '';
});

// Primary Working Model Provider
final geminiModelProvider = Provider<GenerativeModel>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  if (apiKey.isEmpty) {
    throw Exception('API_KEY not found.');
  }
  return GenerativeModel(
    model: 'gemini-2.5-flash', 
    apiKey: apiKey,
  );
});

// Candidate models ordered by summary quality, reliability, and fallback speed
const List<String> kGeminiCandidateModels = [
  'gemini-2.5-flash',      // Primary: thorough, in-depth, structured summaries
  'gemini-3.5-flash',      // State-of-the-art multimodal model with deep reasoning
  'gemini-flash-latest',   // Dynamic latest alias
  'gemini-3.5-flash-lite', // Super-fast fallback if full models experience spikes
];

// Helper to scale down oversized camera photos before uploading to Gemini Vision
Future<Uint8List> _optimizeImageForVision(Uint8List bytes) async {
  if (bytes.lengthInBytes < 500 * 1024) return bytes;
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1200);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) {
      final optimized = data.buffer.asUint8List();
      debugPrint("Optimized image for Vision AI: ${bytes.lengthInBytes ~/ 1024}KB -> ${optimized.lengthInBytes ~/ 1024}KB");
      return optimized;
    }
  } catch (e) {
    debugPrint("Image resize notice: $e");
  }
  return bytes;
}

/// Strips markdown asterisks, hash marks, preambles, and editorial correction commentary
String cleanSummaryText(String raw) {
  if (raw.trim().isEmpty) return raw;

  String text = raw;

  // 1. Remove introductory conversational greetings/preambles
  text = text.replaceAll(
    RegExp(
      r"^(Here('s| is) (a|the|an) (detailed |structured |concise |comprehensive )?(summary|overview|breakdown)[^\n]*\n+)",
      caseSensitive: false,
    ),
    '',
  );

  // 2. Strip explicit correction sections often appended at the end
  text = text.replaceAll(
    RegExp(
      r'\n+\s*(?:#{1,6}\s*)?(?:Corrections?|Typo\s*Fixes|Notes\s*on\s*Corrections?|OCR\s*Fixes|Corrections\s*Made)\s*:?[\s\S]*$',
      caseSensitive: false,
    ),
    '',
  );

  // 3. Strip inline correction remarks e.g. "(corrected from 'X')" or "[Note: fixed typo]"
  text = text.replaceAll(
    RegExp(r'[\(\[]\s*(?:Note:\s*)?(?:fixed|corrected)\s+[^\]\)]+[\)\]]', caseSensitive: false),
    '',
  );

  final lines = text.split('\n');
  final cleanedLines = <String>[];

  for (int i = 0; i < lines.length; i++) {
    var line = lines[i].trim();

    // Skip horizontal divider lines (--- or *** or ___)
    if (RegExp(r'^[-\*_]{3,}$').hasMatch(line)) {
      continue;
    }

    // Remove markdown heading hashes: ### Header -> Header
    if (line.startsWith('#')) {
      line = line.replaceFirst(RegExp(r'^#+\s*'), '');
    }

    // Convert bullet markers (*, -, +) to clean unicode bullet •
    if (RegExp(r'^[\*\-\+]\s+').hasMatch(line)) {
      line = line.replaceFirst(RegExp(r'^[\*\-\+]\s+'), '• ');
    }

    // Remove bold asterisks: **text** -> text
    line = line.replaceAll('**', '');

    // Remove isolated single asterisks used for italics: *text* -> text
    line = line.replaceAll('*', '');

    // Remove markdown underscores: __text__ or _text_
    line = line.replaceAll('__', '');

    cleanedLines.add(line);
  }

  // Remove redundant consecutive blank lines
  final result = <String>[];
  bool lastWasEmpty = false;
  for (final l in cleanedLines) {
    if (l.isEmpty) {
      if (!lastWasEmpty && result.isNotEmpty) {
        result.add('');
      }
      lastWasEmpty = true;
    } else {
      result.add(l);
      lastWasEmpty = false;
    }
  }

  return result.join('\n').trim();
}

// Gemini Service for direct AI calls (Q&A, suggestions, multimodal vision descriptions)
class GeminiService {
  final String apiKey;
  GeminiService(this.apiKey);

  Future<String?> _callWithFallbackContent(
    List<Content> contents, {
    Duration timeout = const Duration(seconds: 14),
  }) async {
    if (apiKey.isEmpty) {
      debugPrint("⚠️ GeminiService: API key is empty");
      return null;
    }

    for (final modelName in kGeminiCandidateModels) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent(contents).timeout(timeout);
        if (response.text != null && response.text!.trim().isNotEmpty) {
          debugPrint("✅ Gemini response received from model: $modelName");
          return response.text!.trim();
        }
      } catch (e) {
        debugPrint("⚠️ Gemini model $modelName failed or timed out: $e");
      }
    }
    return null;
  }

  Future<String?> _callWithFallback(String prompt, {Duration timeout = const Duration(seconds: 14)}) async {
    return _callWithFallbackContent([Content.text(prompt)], timeout: timeout);
  }

  // 1. In-Depth, Structured Document Summary (Clean, human-readable format without markdown hashes or asterisks)
  Future<String> summarizeText(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return "No text found to summarize.";

    final prompt = """
You are an expert document assistant. Analyze the following document text and produce a clean, well-organized, and thorough summary.

CRITICAL FORMATTING INSTRUCTIONS:
1. NEVER use markdown hash symbols (#, ##, ###) for headers.
2. NEVER use asterisks (* or **) for bolding, italics, or bullet points. Output plain text without any asterisks.
3. Use the clean unicode bullet symbol "• " for every bullet point.
4. DO NOT mention OCR corrections, typos fixed, or editorial changes. Silently use the correct words in your summary without ever mentioning what you corrected.
5. DO NOT include introductory or concluding conversational filler (e.g. "Here is a summary", "Summary:", "Hope this helps"). Start immediately with OVERVIEW:.

STRUCTURE YOUR SUMMARY CLEARLY:

OVERVIEW:
[A clear 1-2 sentence statement explaining what this document is, its issuer, and its purpose.]

KEY DETAILS:
• [Key fact, person, date, or detail]
• [Amounts, figures, or metrics]
• [Core obligations, terms, or findings]

ACTION ITEMS:
• [Action item, deadline, or next step, if applicable]

Document Text:
$cleanText
""";

    final result = await _callWithFallback(prompt);
    if (result != null && result.isNotEmpty) {
      return cleanSummaryText(result);
    }

    // Local bullet generator fallback
    final lines = cleanText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final bullets = lines.take(8).map((l) => "• $l").join('\n');
    return cleanSummaryText("OVERVIEW:\nDocument scanned successfully.\n\nKEY DETAILS:\n$bullets");
  }

  // 2. Multimodal Vision: Clean Comprehensive Visual Breakdown
  Future<String> describeImage(Uint8List imageBytes) async {
    final optimized = await _optimizeImageForVision(imageBytes);

    final prompt = """
Analyze this scanned image in detail. No readable text was detected by the OCR engine.

CRITICAL FORMATTING INSTRUCTIONS:
1. NEVER use markdown hash symbols (#, ##, ###).
2. NEVER use asterisks (* or **) for bolding, italics, or bullet points. Output plain text without any asterisks.
3. Use the clean unicode bullet symbol "• " for every bullet point.
4. DO NOT include introductory or concluding conversational filler. Start directly with VISUAL OVERVIEW:.

STRUCTURE YOUR OUTPUT CLEARLY:

VISUAL OVERVIEW:
[Identify what this visual is (e.g. architecture diagram, flowchart, technical drawing, schematic, whiteboard sketch, certificate, photograph, object, or receipt) and its central subject.]

KEY VISUAL ELEMENTS:
• [Shape, object, component, or section]
• [Connections, arrows, flow, or relationships]
• [Labels, symbols, or structural hierarchy]

KEY TAKEAWAYS & MEANING:
• [What process, design, or purpose is communicated by this visual]
""";

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', optimized),
      ])
    ];

    final result = await _callWithFallbackContent(content);
    if (result != null && result.isNotEmpty) {
      return cleanSummaryText(result);
    }

    return "VISUAL OVERVIEW:\nVisual document scanned.\n\nKEY VISUAL ELEMENTS:\n• Image analyzed with visual AI (no embedded text detected).";
  }

  // 3. Smart Auto-Naming & Category for Text
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

    final result = await _callWithFallback(prompt, timeout: const Duration(seconds: 8));
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

    final firstLine = cleanText.split('\n').firstWhere((l) => l.trim().length > 3, orElse: () => "Document");
    final title = firstLine.length > 25 ? "${firstLine.substring(0, 25)}..." : firstLine;
    return {
      'title': title,
      'category': 'General',
    };
  }

  // 4. Multimodal Smart Auto-Naming for Images
  Future<Map<String, String>> suggestImageMetadata(Uint8List imageBytes) async {
    final prompt = """
Look at this scanned image and return a JSON object with:
1. "title": A concise, descriptive title of what is shown (maximum 3-5 words, e.g. "Network Architecture Diagram", "Whiteboard Flowchart", "Handwritten Notes", "ID Document Photo", "Product Design Sketch").
2. "category": A single-word category from: Diagrams, Sketches, Photos, Receipts, Medical, Legal, Academic, Personal, Work.

Output ONLY valid JSON without markdown wrapping. Format:
{"title": "...", "category": "..."}
""";

    final optimized = await _optimizeImageForVision(imageBytes);
    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', optimized),
      ])
    ];

    final result = await _callWithFallbackContent(content, timeout: const Duration(seconds: 8));
    if (result != null) {
      try {
        final cleanedJson = result.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> parsed = jsonDecode(cleanedJson);
        return {
          'title': (parsed['title'] ?? 'Scanned Visual').toString().replaceAll('"', '').trim(),
          'category': (parsed['category'] ?? 'Diagrams').toString().replaceAll('"', '').trim(),
        };
      } catch (e) {
        debugPrint("Error parsing image metadata JSON: $e");
      }
    }

    return {
      'title': 'Scanned Visual',
      'category': 'General',
    };
  }

  // 5. Interactive Document & Image Q&A
  Future<String> askDocument({
    String? documentText,
    Uint8List? imageBytes,
    required String question,
  }) async {
    if (question.trim().isEmpty) return "Please enter a question about the document.";

    final cleanText = documentText?.trim() ?? '';
    final hasMeaningfulText = cleanText.isNotEmpty && !cleanText.startsWith("[No text detected");
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;

    if (!hasMeaningfulText && !hasImage) {
      return "No document text or image content available to analyze.";
    }

    final prompt = """
You are DocuMate AI, an intelligent document and visual assistant.
Answer the user's question accurately based on the provided ${hasMeaningfulText ? 'scanned text' : ''} ${hasImage ? 'and visual image' : ''}.
If the answer cannot be determined from the document or image, politely say so.
Do not use markdown hash symbols or asterisks in your answer.

User Question:
$question
""";

    final parts = <Part>[TextPart(prompt)];
    if (hasMeaningfulText) {
      parts.add(TextPart("Scanned Text Content:\n$cleanText\n"));
    }
    if (hasImage) {
      final optimized = await _optimizeImageForVision(imageBytes);
      parts.add(DataPart('image/jpeg', optimized));
    }

    final content = [Content.multi(parts)];
    final answer = await _callWithFallbackContent(content, timeout: const Duration(seconds: 14));
    return answer != null ? cleanSummaryText(answer) : "Unable to analyze the document right now. Please check your internet connection.";
  }

  // 6. Interactive Voice Assistant Q&A across documents and general conversation
  Future<String> answerVoiceAssistant({
    required String question,
    List<Map<String, dynamic>> userDocuments = const [],
  }) async {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) return "I'm listening. Ask me anything about your documents or any question!";

    final buffer = StringBuffer();
    buffer.writeln("You are DocuMate AI Voice Assistant, a friendly, ultra-intelligent personal document manager and voice assistant.");
    buffer.writeln("The user is chatting with you using voice or text.");
    buffer.writeln("CRITICAL INSTRUCTIONS:");
    buffer.writeln("1. Answer in natural, friendly, conversational English (ideal for text-to-speech reading).");
    buffer.writeln("2. NEVER use markdown asterisks (*, **) or hash symbols (#). Use clear natural phrasing and bullet symbol '• ' if listing items.");
    buffer.writeln("3. Keep answers direct, concise (1 to 3 short paragraphs max), and helpful.");
    buffer.writeln("4. If the user asks about their documents, bills, receipts, costs, dates, or summaries, check the user's documents listed below and cite exact names and details.");
    buffer.writeln("5. If no documents match their request, inform them politely and offer helpful next steps.");
    buffer.writeln("6. If their question is general conversation (e.g. 'how are you', 'what is an invoice', 'tell me a joke'), answer naturally and warmly.");
    buffer.writeln();

    if (userDocuments.isNotEmpty) {
      buffer.writeln("USER'S SAVED DOCUMENTS CONTEXT:");
      final docsToInclude = userDocuments.take(8);
      int idx = 1;
      for (final doc in docsToInclude) {
        final title = doc['title'] ?? 'Untitled Document';
        final category = doc['category'] ?? doc['folder_name'] ?? 'General';
        final summary = (doc['summary'] ?? '').toString();
        final content = (doc['content'] ?? '').toString();
        final previewContent = content.length > 250 ? '${content.substring(0, 250)}...' : content;

        buffer.writeln("[$idx] Title: $title | Category: $category");
        if (summary.isNotEmpty) buffer.writeln("Summary: $summary");
        if (previewContent.isNotEmpty && previewContent != summary) buffer.writeln("Excerpt: $previewContent");
        buffer.writeln();
        idx++;
      }
    } else {
      buffer.writeln("NOTE: The user currently has no saved documents in this folder.");
      buffer.writeln();
    }

    buffer.writeln("USER QUERY:");
    buffer.writeln(cleanQuestion);

    final answer = await _callWithFallback(buffer.toString(), timeout: const Duration(seconds: 12));
    if (answer != null && answer.trim().isNotEmpty) {
      return cleanSummaryText(answer);
    }
    return "I'm having trouble connecting to AI services right now, but I found some relevant documents below.";
  }
}

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  return GeminiService(apiKey);
});

// Main Summary & Visual Analysis Provider
final ocrSummaryProvider = AsyncNotifierProvider<OcrSummaryNotifier, OcrResult?>(() {
  return OcrSummaryNotifier();
});

class OcrSummaryNotifier extends AsyncNotifier<OcrResult?> {
  @override
  Future<OcrResult?> build() async => null;

  /// Backwards-compatible text-only summarization
  Future<void> summarizeText(String text) async {
    await analyzeDocument(text: text);
  }

  /// Full Document Analysis: Intelligently handles both OCR text and Multimodal Visual AI
  Future<void> analyzeDocument({String? text, String? imagePath}) async {
    final cleanText = text?.trim() ?? "";
    final hasText = cleanText.isNotEmpty && 
                    cleanText != "No text detected." &&
                    cleanText != "No text detected in scanned image(s)." &&
                    !cleanText.startsWith("[No text detected");

    state = const AsyncValue.loading();
    final service = ref.read(geminiServiceProvider);

    try {
      if (hasText) {
        // Run deep structured summary and smart metadata extraction concurrently
        final summaryFuture = service.summarizeText(cleanText);
        final metadataFuture = service.suggestMetadata(cleanText);

        final results = await Future.wait([summaryFuture, metadataFuture]);
        final summary = results[0] as String;
        final metadata = results[1] as Map<String, String>;

        state = AsyncValue.data(OcrResult(
          summary: summary,
          suggestedTitle: metadata['title'],
          suggestedCategory: metadata['category'],
          isVisualDescription: false,
        ));
      } else {
        Uint8List? imageBytes;
        if (imagePath != null && File(imagePath).existsSync()) {
          try {
            imageBytes = await File(imagePath).readAsBytes();
          } catch (e) {
            debugPrint("Notice: could not read image bytes: $e");
          }
        }

        if (imageBytes != null && imageBytes.isNotEmpty) {
          debugPrint("🔍 OCR found no text: Analyzing with Gemini Vision AI...");
          final describeFuture = service.describeImage(imageBytes);
          final metadataFuture = service.suggestImageMetadata(imageBytes);

          final results = await Future.wait([describeFuture, metadataFuture]);
          final summary = results[0] as String;
          final metadata = results[1] as Map<String, String>;

          state = AsyncValue.data(OcrResult(
            summary: summary,
            suggestedTitle: metadata['title'],
            suggestedCategory: metadata['category'],
            isVisualDescription: true,
          ));
        } else {
          state = AsyncValue.data(OcrResult(
            summary: "No text or image found to analyze.",
            isVisualDescription: false,
          ));
        }
      }
    } catch (e) {
      debugPrint("Analysis Error: $e");
      final lines = cleanText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final bullets = lines.take(8).map((l) => "• $l").join('\n');
      state = AsyncValue.data(OcrResult(
        summary: cleanText.isNotEmpty ? cleanSummaryText("OVERVIEW:\nDocument scanned successfully.\n\nKEY DETAILS:\n$bullets") : "Visual document scanned.",
        isVisualDescription: !hasText,
      ));
    }
  }
}