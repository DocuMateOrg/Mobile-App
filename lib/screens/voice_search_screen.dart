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
  String _lastWords = 'Tap the microphone and start speaking...';

  // Controller for the waveform animation
  late final IOS7SiriWaveformController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = IOS7SiriWaveformController(
      amplitude: 0.0, // Starts flat (not listening)
      color: const Color(0xFF0056D2),
    );
    _initSpeech();
  }

  /// Initialize the Speech-to-Text engine
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _stopWaveform();
        }
      },
      onError: (errorNotification) => _stopWaveform(),
    );
    setState(() {});
  }

  /// Start listening and animate the waveform
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {
      _waveController.amplitude = 1.0; // Make the wave bounce!
    });
  }

  /// Stop listening and flatten the waveform
  void _stopListening() async {
    await _speechToText.stop();
    _stopWaveform();
  }

  void _stopWaveform() {
    if (mounted) {
      setState(() {
        _waveController.amplitude = 0.0; // Flatten the wave
      });
    }
  }

  /// Callback for every word recognized
  void _onSpeechResult(result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isListening = _speechToText.isListening;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Voice Search", style: GoogleFonts.poppins(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. The Real-time Text Display
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(30),
              alignment: Alignment.center,
              child: Text(
                _lastWords,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: isListening ? Colors.black : Colors.grey,
                ),
              ),
            ),
          ),

          // 2. The STT Visualizer (UPDATED FOR NEW PACKAGE VERSION)
          SizedBox(
            height: 150,
            width: double.infinity,
            child: SiriWaveform.ios7(
              controller: _waveController,
              options: const IOS7SiriWaveformOptions(
                height: 150,
              ),
            ),
          ),

          // 3. The Microphone Action Button
          Padding(
            padding: const EdgeInsets.only(bottom: 60, top: 20),
            child: GestureDetector(
              onTap: _speechToText.isNotListening ? _startListening : _stopListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isListening ? Colors.redAccent : const Color(0xFF0056D2),
                  boxShadow: [
                    BoxShadow(
                      color: (isListening ? Colors.redAccent : const Color(0xFF0056D2)).withOpacity(0.4),
                      blurRadius: isListening ? 20 : 10,
                      spreadRadius: isListening ? 10 : 2,
                    )
                  ],
                ),
                child: Icon(
                  isListening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}