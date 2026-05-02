import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:siri_wave/siri_wave.dart';

class VoiceSearchScreen extends StatefulWidget {
  const VoiceSearchScreen({super.key});

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isPopping = false;
  
  final String _defaultPrompt = 'Ask me anything...';
  late String _lastWords;

  // Controller for the waveform animation
  late final IOS7SiriWaveformController _waveController;

  @override
  void initState() {
    super.initState();
    _lastWords = _defaultPrompt;
    _waveController = IOS7SiriWaveformController(
      amplitude: 0.0, // Starts flat (not listening)
      color: const Color(0xFF0056D2),
    );
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _stopWaveform();
          _returnResult();
        }
      },
      onError: (errorNotification) => _stopWaveform(),
    );
    setState(() {});
  }

  void _returnResult() {
    if (_isPopping) return;
    if (_lastWords != _defaultPrompt && _lastWords.trim().isNotEmpty && _lastWords != "Listening...") {
      _isPopping = true;
      if (mounted) Navigator.pop(context, _lastWords);
    }
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {
      _waveController.amplitude = 1.0; 
      _lastWords = "Listening...";
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    _stopWaveform();
    _returnResult();
  }

  void _stopWaveform() {
    if (mounted) {
      setState(() {
        _waveController.amplitude = 0.0;
      });
    }
  }

  void _onSpeechResult(result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isListening = _speechToText.isListening;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD4FC9B), // Light Green
              Color(0xFFCBE3FA), // Light Blue
              Color(0xFFE5D5BA), // Beige/Orange
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black),
                      onPressed: () {
                         Navigator.pop(context); // Go back to dashboard
                      },
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none, color: Colors.black, size: 28),
                          onPressed: () {},
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '2',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Greeting Text
              Text(
                "Hello User!\nHow can I help you today?",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.3,
                ),
              ),

              const Spacer(),

              // Center Icon / Waveform
              Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[400]!, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!isListening)
                      const Icon(Icons.graphic_eq, size: 80, color: Colors.black87),
                    Opacity(
                      opacity: isListening ? 1.0 : 0.0,
                      child: SiriWaveform.ios7(
                        controller: _waveController,
                        options: const IOS7SiriWaveformOptions(
                          height: 150,
                          width: 150,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Bottom Action Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Text(
                          _lastWords,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    GestureDetector(
                      onTap: _speechToText.isNotListening ? _startListening : _stopListening,
                      child: Container(
                        height: 65,
                        width: 65,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0056D2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0056D2).withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Icon(
                          isListening ? Icons.stop : Icons.mic_none,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}