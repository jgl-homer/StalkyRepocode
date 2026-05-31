import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceDictationButton extends StatefulWidget {
  const VoiceDictationButton({
    super.key,
    required this.controller,
    required this.gold,
    this.backgroundColor = Colors.black,
    this.tooltip = 'Dictar por voz',
    this.onTextChanged,
    this.onListeningChanged,
  });

  final TextEditingController controller;
  final Color gold;
  final Color backgroundColor;
  final String tooltip;
  final ValueChanged<String>? onTextChanged;
  final ValueChanged<bool>? onListeningChanged;

  @override
  State<VoiceDictationButton> createState() => _VoiceDictationButtonState();
}

class _VoiceDictationButtonState extends State<VoiceDictationButton> {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _baseText = '';

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
      return;
    }

    final available = _isAvailable ||
        await _speech.initialize(
          onStatus: _handleStatus,
          onError: _handleError,
        );

    if (!mounted) return;

    if (!available) {
      _showMessage('No se pudo activar el dictado de voz.');
      return;
    }

    _baseText = widget.controller.text.trim();
    setState(() {
      _isAvailable = true;
      _isListening = true;
    });
    widget.onListeningChanged?.call(true);

    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'es_MX',
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (result) {
        final dictatedText = result.recognizedWords.trim();
        final nextText = _baseText.isEmpty
            ? dictatedText
            : dictatedText.isEmpty
                ? _baseText
                : '$_baseText $dictatedText';

        widget.controller.value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(offset: nextText.length),
        );
        widget.onTextChanged?.call(nextText);
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
      widget.onListeningChanged?.call(false);
    }
  }

  void _handleStatus(String status) {
    if (!mounted) return;
    if (status == 'done' || status == 'notListening') {
      setState(() => _isListening = false);
      widget.onListeningChanged?.call(false);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() => _isListening = false);
    widget.onListeningChanged?.call(false);
    if (!error.permanent) return;
    _showMessage('Permiso de microfono no disponible.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.black)),
        backgroundColor: widget.gold,
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color activeColor = _isListening ? Colors.redAccent : widget.gold;

    return Tooltip(
      message: _isListening ? 'Detener dictado' : widget.tooltip,
      child: InkWell(
        onTap: _toggleListening,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _isListening
                ? activeColor.withValues(alpha: 0.16)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: activeColor.withValues(alpha: 0.65)),
          ),
          child: Icon(
            _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
            color: activeColor,
          ),
        ),
      ),
    );
  }
}
