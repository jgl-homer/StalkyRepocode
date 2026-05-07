// 📁 lib/pomodoro_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// --- COLORES CYBERPUNK ---
const Color _primaryGold = Color(0xFFFFD700);
const Color _accentCyan = Colors.cyanAccent;
const Color _darkBackground = Colors.black;
// -------------------------

class PomodoroPage extends StatefulWidget {
  final String taskTitle;
  
  const PomodoroPage({super.key, required this.taskTitle});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> with TickerProviderStateMixin {
  static const int _focusDuration = 25 * 60; // 25 minutos
  static const int _breakDuration = 5 * 60;  // 5 minutos
  
  late AnimationController _controller;
  Timer? _timer;
  int _secondsRemaining = _focusDuration;
  bool _isPaused = true;
  String _currentState = 'CONCENTRACIÓN'; // 'CONCENTRACIÓN' o 'DESCANSO'
  
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _secondsRemaining),
    )..reverse(from: 1.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playSound() {
    // Asegúrate de tener 'alarm.mp3' en 'assets/sounds/'
    _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
  }

  void _startTimer() {
    setState(() {
      _isPaused = false;
    });
    _controller.duration = Duration(seconds: _secondsRemaining);
    _controller.reverse(from: _secondsRemaining / (_currentState == 'CONCENTRACIÓN' ? _focusDuration : _breakDuration));
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _playSound();
        _timer?.cancel();
        _toggleState();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _controller.stop();
    setState(() {
      _isPaused = true;
    });
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() {
      _secondsRemaining = _currentState == 'CONCENTRACIÓN' ? _focusDuration : _breakDuration;
      _controller.value = 1.0;
    });
  }

  void _toggleState() {
    _pauseTimer();
    setState(() {
      if (_currentState == 'CONCENTRACIÓN') {
        _currentState = 'DESCANSO';
        _secondsRemaining = _breakDuration;
      } else {
        _currentState = 'CONCENTRACIÓN';
        _secondsRemaining = _focusDuration;
      }
      _isPaused = true;
    });
    _controller.value = 1.0;
  }

  String _formatTime(int seconds) {
    final int min = (seconds / 60).floor();
    final int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      appBar: AppBar(
        title: Text(
          'Modo Foco',
          style: TextStyle(color: _accentCyan, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _darkBackground,
        iconTheme: const IconThemeData(color: _accentCyan),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Preguntar antes de salir si el timer está activo
            if (!_isPaused) {
              _showExitConfirmation();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo/icon.png',
              height: 40,
              width: 40,
              errorBuilder: (_, __, ___) => const Icon(Icons.star, color: _primaryGold),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _currentState,
              style: const TextStyle(
                color: _primaryGold,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.taskTitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey[900],
                    color: _currentState == 'CONCENTRACIÓN' ? _accentCyan : _primaryGold,
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CircularProgressIndicator(
                        value: _controller.value,
                        strokeWidth: 12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                      );
                    },
                  ),
                  Center(
                    child: Text(
                      _formatTime(_secondsRemaining),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón de Reset
                IconButton(
                  icon: const Icon(Icons.refresh, size: 40, color: Colors.white70),
                  onPressed: _resetTimer,
                ),
                // Botón de Play/Pausa
                IconButton(
                  icon: Icon(
                    _isPaused ? Icons.play_circle_fill_rounded : Icons.pause_circle_filled_rounded,
                    size: 80,
                    color: _accentCyan,
                  ),
                  onPressed: _isPaused ? _startTimer : _pauseTimer,
                ),
                // Botón de Siguiente (skip)
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, size: 40, color: Colors.white70),
                  onPressed: _toggleState,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation() async {
    final bool? exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('¿Salir del Modo Foco?', style: TextStyle(color: Colors.white)),
        content: const Text('El temporizador se detendrá. ¿Estás seguro?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Salir', style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (exit == true) {
      Navigator.pop(context);
    }
  }
}