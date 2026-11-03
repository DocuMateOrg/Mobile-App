import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:siri_wave/siri_wave.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/providers/gemini_provider.dart';
import '../services/local_document_service.dart';
import '../features/scanner/api_service.dart';
import '../features/scanner/document_detail_screen.dart';

class VoiceChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Map<String, dynamic>> matchedDocuments;

  VoiceChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.matchedDocuments = const [],
  }) : timestamp = timestamp ?? DateTime.now();
}

class VoiceSearchScreen extends ConsumerStatefulWidget {
  const VoiceSearchScreen({super.key});

  @override
  ConsumerState<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends ConsumerState<VoiceSearchScreen> with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final IOS7SiriWaveformController _waveController;

  bool _isSpeechInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isProcessing = false;
  bool _autoTtsEnabled = true;
  String _currentSpeechText = '';

  final List<VoiceChatMessage> _messages = [];

  final List<String> _suggestedPrompts = [
    "Find all my invoices",
    "Show recent receipts",
    "What utility bills do I have?",
    "Summarize my latest documents",
    "How much did I spend recently?",
  ];

  @override
  void initState() {
    super.initState();
    _waveController = IOS7SiriWaveformController(
      amplitude: 0.0,
      color: const Color(0xFF0056D2),
    );

    _initTts();
    _initSpeech();

    // Initial greeting message
    _messages.add(
      VoiceChatMessage(
        id: 'welcome',
        text: "Hello! I am your DocuMate AI Voice Assistant. Speak or type below to find documents, get answers about your bills and receipts, or chat!",
        isUser: false,
      ),
    );
  }

  void _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);

      _flutterTts.setStartHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = true;
            _waveController.amplitude = 0.8;
          });
        }
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _waveController.amplitude = 0.0;
          });
        }
      });

      _flutterTts.setCancelHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _waveController.amplitude = 0.0;
          });
        }
      });

      _flutterTts.setErrorHandler((msg) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _waveController.amplitude = 0.0;
          });
        }
      });
    } catch (e) {
      debugPrint("TTS initialization notice: $e");
    }
  }

  Future<void> _initSpeech() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isDenied) {
        await Permission.microphone.request();
      }

      final hasSpeech = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint("Speech status: $status");
          if (status == 'listening') {
            if (mounted) setState(() => _isListening = true);
          } else if (status == 'notListening' || status == 'done') {
            if (mounted) {
              setState(() {
                _isListening = false;
                _waveController.amplitude = 0.0;
              });
              if (_currentSpeechText.trim().isNotEmpty) {
                final queryToSubmit = _currentSpeechText.trim();
                _currentSpeechText = '';
                _submitQuery(queryToSubmit);
              }
            }
          }
        },
        onError: (errorNotification) {
          debugPrint("Speech error: ${errorNotification.errorMsg}");
          if (mounted) {
            setState(() {
              _isListening = false;
              _waveController.amplitude = 0.0;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isSpeechInitialized = hasSpeech;
        });
      }
    } catch (e) {
      debugPrint("Speech init error: $e");
    }
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }

    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Microphone permission is required for voice search."),
            action: SnackBarAction(
              label: "Settings",
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    if (!_isSpeechInitialized) {
      await _initSpeech();
      if (!_isSpeechInitialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Voice recognition unavailable on this device. You can type your query below.")),
          );
        }
        return;
      }
    }

    setState(() {
      _currentSpeechText = '';
      _isListening = true;
      _waveController.amplitude = 1.0;
    });

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _currentSpeechText = result.recognizedWords;
              _waveController.amplitude = 1.0;
            });
            if (result.finalResult && _currentSpeechText.trim().isNotEmpty) {
              final finalWords = _currentSpeechText.trim();
              _currentSpeechText = '';
              _stopListening(autoSubmit: false);
              _submitQuery(finalWords);
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint("Error listening: $e");
      if (mounted) {
        setState(() {
          _isListening = false;
          _waveController.amplitude = 0.0;
        });
      }
    }
  }

  Future<void> _stopListening({bool autoSubmit = true}) async {
    try {
      await _speechToText.stop();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isListening = false;
        _waveController.amplitude = 0.0;
      });
    }

    if (autoSubmit && _currentSpeechText.trim().isNotEmpty) {
      final query = _currentSpeechText.trim();
      _currentSpeechText = '';
      _submitQuery(query);
    }
  }

  Future<void> _speakText(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      return;
    }
    try {
      final clean = text
          .replaceAll(RegExp(r'[•\-*#]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      await _flutterTts.speak(clean);
    } catch (e) {
      debugPrint("TTS error: $e");
    }
  }

  Future<void> _submitQuery(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty || _isProcessing) return;

    _textController.clear();

    setState(() {
      _messages.add(
        VoiceChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: query,
          isUser: true,
        ),
      );
      _isProcessing = true;
    });
    _scrollToBottom();

    try {
      // 1. Gather all documents (local + remote)
      final allDocs = <Map<String, dynamic>>[];
      try {
        final localDocs = await LocalDocumentService().getLocalDocuments();
        allDocs.addAll(localDocs);
      } catch (e) {
        debugPrint("Voice assistant: local docs fetch notice: $e");
      }

      try {
        final remoteDocs = await ApiService().fetchUserDocuments();
        for (final rd in remoteDocs) {
          final map = Map<String, dynamic>.from(rd);
          if (!allDocs.any((d) => d['id'] == map['id'] || (d['title'] == map['title'] && d['created_at'] == map['created_at']))) {
            allDocs.add(map);
          }
        }
      } catch (e) {
        debugPrint("Voice assistant: remote docs fetch notice: $e");
      }

      // 2. Extract keywords & filter matching documents
      final tokens = LocalDocumentService.extractSearchTokens(query);
      final rawLower = query.toLowerCase();

      final matchedDocs = allDocs.where((d) {
        final title = (d['title'] ?? '').toString().toLowerCase();
        final content = (d['content'] ?? '').toString().toLowerCase();
        final summary = (d['summary'] ?? '').toString().toLowerCase();
        final category = (d['category'] ?? d['folder_name'] ?? '').toString().toLowerCase();

        if (title.contains(rawLower) || summary.contains(rawLower) || category.contains(rawLower)) {
          return true;
        }

        if (tokens.isNotEmpty) {
          return tokens.any((t) =>
              title.contains(t) || content.contains(t) || summary.contains(t) || category.contains(t));
        }

        return false;
      }).toList();

      // 3. Ask Gemini for an intelligent voice response
      final gemini = ref.read(geminiServiceProvider);
      final answer = await gemini.answerVoiceAssistant(
        question: query,
        userDocuments: matchedDocs.isNotEmpty ? matchedDocs : allDocs,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          VoiceChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: answer,
            isUser: false,
            matchedDocuments: matchedDocs.take(5).toList(),
          ),
        );
        _isProcessing = false;
      });
      _scrollToBottom();

      // 4. Speak response aloud if enabled
      if (_autoTtsEnabled && answer.isNotEmpty) {
        _speakText(answer);
      }
    } catch (e) {
      debugPrint("Voice assistant error: $e");
      if (!mounted) return;
      setState(() {
        _messages.add(
          VoiceChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: "Sorry, I had trouble answering that. Please check your connection and try again.",
            isUser: false,
          ),
        );
        _isProcessing = false;
      });
      _scrollToBottom();
    }
  }

  void _applyFilterAndReturn(String query) {
    Navigator.pop(context, query);
  }

  void _openDocument(Map<String, dynamic> doc) {
    final int docId = doc['id'] is int ? doc['id'] : int.tryParse(doc['id'].toString()) ?? 0;
    final String title = doc['title'] ?? 'Document';
    final String imagePath = doc['local_image_path'] ?? doc['image_url'] ?? '';
    final String? serverImagePath = doc['image_url'];
    final String content = doc['content'] ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentDetailScreen(
          documentId: docId,
          title: title,
          imagePath: imagePath,
          serverImagePath: serverImagePath,
          content: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: "Back to Dashboard",
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "DocuMate Voice AI",
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            Text(
              "Ask questions, find docs & chat",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _autoTtsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _autoTtsEnabled ? const Color(0xFF0056D2) : Colors.grey,
            ),
            tooltip: _autoTtsEnabled ? "Mute Voice Replies" : "Enable Voice Replies",
            onPressed: () {
              setState(() {
                _autoTtsEnabled = !_autoTtsEnabled;
                if (!_autoTtsEnabled && _isSpeaking) {
                  _flutterTts.stop();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
            tooltip: "Clear Chat",
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(
                  VoiceChatMessage(
                    id: 'welcome',
                    text: "Conversation cleared. How can I help you with your documents?",
                    isUser: false,
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF4F9FF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Waveform Banner (Active when listening or speaking)
              if (_isListening || _isSpeaking)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0056D2).withValues(alpha: 0.06),
                    border: Border(bottom: BorderSide(color: const Color(0xFF0056D2).withValues(alpha: 0.15))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isListening ? Icons.mic : Icons.graphic_eq,
                            size: 16,
                            color: const Color(0xFF0056D2),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isListening ? "Listening to your voice..." : "DocuMate AI speaking...",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0056D2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SiriWaveform.ios7(
                        controller: _waveController,
                        options: const IOS7SiriWaveformOptions(
                          height: 55,
                          width: 260,
                        ),
                      ),
                      if (_isListening && _currentSpeechText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Text(
                            '"$_currentSpeechText"',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // Chat Messages List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length + (_isProcessing ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isProcessing) {
                      return _buildLoadingBubble();
                    }
                    final msg = _messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),

              // Suggested prompt chips (if chat has few messages)
              if (_messages.length <= 2 && !_isListening && !_isProcessing)
                Container(
                  height: 40,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _suggestedPrompts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final prompt = _suggestedPrompts[i];
                      return ActionChip(
                        label: Text(
                          prompt,
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0056D2)),
                        ),
                        backgroundColor: const Color(0xFF0056D2).withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                        onPressed: () => _submitQuery(prompt),
                      );
                    },
                  ),
                ),

              // Bottom Input Bar
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(VoiceChatMessage msg) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0056D2),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0056D2).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blue[100],
                  child: const Icon(Icons.person, size: 16, color: Color(0xFF0056D2)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 38),
              child: GestureDetector(
                onTap: () => _applyFilterAndReturn(msg.text),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search, size: 13, color: Color(0xFF0056D2)),
                    const SizedBox(width: 3),
                    Text(
                      "Filter in Dashboard",
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF0056D2), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // AI Assistant Bubble
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0056D2), Color(0xFF4A90E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF1E293B),
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                            tooltip: "Copy text",
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: msg.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Copied to clipboard!"), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              _isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                              size: 18,
                              color: const Color(0xFF0056D2),
                            ),
                            tooltip: _isSpeaking ? "Stop speech" : "Read aloud",
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _speakText(msg.text),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Embedded Matched Documents Cards (if any)
          if (msg.matchedDocuments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Matching Documents (${msg.matchedDocuments.length}):",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: msg.matchedDocuments.map((doc) => _buildDocumentCard(doc)).toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final title = doc['title'] ?? 'Document';
    final category = doc['category'] ?? doc['folder_name'] ?? 'General';
    final isLocal = doc['is_local'] == true;

    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openDocument(doc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0056D2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.description_outlined, size: 16, color: Color(0xFF0056D2)),
                ),
                const Spacer(),
                if (isLocal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Local",
                      style: GoogleFonts.poppins(fontSize: 9, color: Colors.green[800], fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
            ),
            Text(
              category,
              maxLines: 1,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "Open",
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF0056D2), fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.chevron_right, size: 14, color: Color(0xFF0056D2)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF0056D2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0056D2)),
                ),
                const SizedBox(width: 10),
                Text(
                  "Searching documents & analyzing...",
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Text Input Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: _submitQuery,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isListening ? "Listening..." : "Ask or search by voice/text...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send / Submit Button (if text entered)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (context, value, _) {
              if (value.text.trim().isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF0056D2)),
                  onPressed: () => _submitQuery(_textController.text),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Big Pulsating Microphone Button
          GestureDetector(
            onTap: () {
              if (_isListening) {
                _stopListening(autoSubmit: true);
              } else {
                _startListening();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isListening
                      ? [Colors.redAccent, Colors.red]
                      : [const Color(0xFF0056D2), const Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? Colors.red : const Color(0xFF0056D2)).withValues(alpha: 0.35),
                    blurRadius: _isListening ? 14 : 8,
                    spreadRadius: _isListening ? 3 : 1,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}