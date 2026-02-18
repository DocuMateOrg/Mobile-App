import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Create a provider for the API Key
final geminiApiKeyProvider = Provider<String>((ref) {
  return const String.fromEnvironment('API_KEY');
});

// 2. Create the provider for the Generative Model
final geminiModelProvider = Provider<GenerativeModel>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  
  if (apiKey.isEmpty) {
    throw Exception('API_KEY not found. Did you forget --dart-define?');
  }

  return GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: apiKey,
  );
});