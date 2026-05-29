import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class FlashcardsStudyPage extends StatefulWidget {
  final String setId;
  final String title;
  final String materia;
  final List<Map<String, dynamic>> cards;

  const FlashcardsStudyPage({
    super.key,
    required this.setId,
    required this.title,
    required this.materia,
    required this.cards,
  });

  @override
  State<FlashcardsStudyPage> createState() => _FlashcardsStudyPageState();
}

class _FlashcardsStudyPageState extends State<FlashcardsStudyPage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showFront = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final Color _bg = const Color(0xFF000000);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _cardBg = const Color(0xFF1E1E1E);

  // Historial de respuestas en la sesión (correctas/incorrectas)
  final Map<int, bool> _sessionProgress = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0, end: pi).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Voltea la tarjeta con una animación 3D
  void _flipCard() {
    if (_showFront) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    setState(() {
      _showFront = !_showFront;
    });
  }

  /// Avanza a la siguiente tarjeta
  void _nextCard() {
    if (_currentIndex < widget.cards.length - 1) {
      // Si la tarjeta actual está volteada, la regresamos al frente antes de pasar a la siguiente
      if (!_showFront) {
        _animationController.reverse();
        setState(() {
          _showFront = true;
        });
      }
      setState(() {
        _currentIndex++;
      });
    } else {
      // Mostrar pantalla de finalización
      _showCompletionDialog();
    }
  }

  /// Regresa a la tarjeta anterior
  void _prevCard() {
    if (_currentIndex > 0) {
      if (!_showFront) {
        _animationController.reverse();
        setState(() {
          _showFront = true;
        });
      }
      setState(() {
        _currentIndex--;
      });
    }
  }

  /// Elimina este set de flashcards de Firestore u offline
  Future<void> _deleteFlashcardSet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Eliminar Colección', style: TextStyle(color: _gold)),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta colección de flashcards? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (widget.setId.startsWith('local_')) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = 'offline_flashcard_sets_${user.uid}';
          final list = prefs.getStringList(key) ?? [];
          list.removeWhere((item) {
            final map = jsonDecode(item) as Map;
            return map['id'] == widget.setId;
          });
          await prefs.setStringList(key, list);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Colección local eliminada', style: TextStyle(color: Colors.black)),
              backgroundColor: _gold,
            ),
          );
          Navigator.pop(context); // Regresa a la pantalla anterior
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error local al eliminar: $e')),
          );
        }
        return;
      }
      
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('flashcard_sets')
            .doc(widget.setId)
            .delete();
            
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Colección eliminada', style: TextStyle(color: Colors.black)),
            backgroundColor: _gold,
          ),
        );
        Navigator.pop(context); // Regresa a la pantalla anterior
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  void _showCompletionDialog() {
    final correctCount = _sessionProgress.values.where((v) => v == true).length;
    final totalCount = widget.cards.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text(
            '¡Sesión Completada! 🎉',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _gold, fontSize: 22),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              'Has repasado todas las tarjetas del set.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Tarjetas', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('$totalCount', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(width: 1, height: 30, color: Colors.white12),
                  Column(
                    children: [
                      Text('Aprendidas', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('$correctCount', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cierra diálogo
                  Navigator.pop(context); // Regresa al listado
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Volver al menú', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('Este set no tiene tarjetas.')),
      );
    }

    final currentCard = widget.cards[_currentIndex];
    final String pregunta = currentCard['pregunta'] ?? '';
    final String respuesta = currentCard['respuesta'] ?? '';
    final double progress = (_currentIndex + 1) / widget.cards.length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.title,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            Text(
              widget.materia.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 10, color: _gold, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteFlashcardSet,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Indicador de progreso
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tarjeta ${_currentIndex + 1} de ${widget.cards.length}',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: GoogleFonts.inter(color: _gold, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: _cardBg,
                  color: _gold,
                ),
              ),
              const SizedBox(height: 40),

              // Área del flip card 3D
              Expanded(
                child: GestureDetector(
                  onTap: _flipCard,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      // Construir transformación de perspectiva 3D
                      final transform = Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // Valor de perspectiva
                        ..rotateY(_animation.value);

                      return Transform(
                        transform: transform,
                        alignment: Alignment.center,
                        child: _animation.value < pi / 2
                            ? _buildCardSide(
                                title: 'PREGUNTA / CONCEPTO',
                                content: pregunta,
                                color: _cardBg,
                                icon: Icons.help_outline,
                              )
                            : Transform(
                                // Voltear horizontalmente el reverso de la tarjeta
                                transform: Matrix4.identity()..rotateY(pi),
                                alignment: Alignment.center,
                                child: _buildCardSide(
                                  title: 'RESPUESTA / DEFINICIÓN',
                                  content: respuesta,
                                  color: _gold.withOpacity(0.08),
                                  borderColor: _gold.withOpacity(0.4),
                                  icon: Icons.check_circle_outline,
                                  isBack: true,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Feedback rápido (Sólo si está volteada la tarjeta)
              if (!_showFront) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _sessionProgress[_currentIndex] = false;
                        });
                        _nextCard();
                      },
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      label: const Text('Aún no', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _sessionProgress[_currentIndex] = true;
                        });
                        _nextCard();
                      },
                      icon: const Icon(Icons.check, color: Colors.black, size: 18),
                      label: const Text('¡La sé!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ] else ...[
                // Ayuda visual para indicar que se puede hacer tap
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_outlined, color: _gold.withOpacity(0.6), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Toca la tarjeta para ver la respuesta',
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48), // Mantener altura uniforme
              ],

              // Botones de navegación base
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _currentIndex > 0 ? _prevCard : null,
                    icon: Icon(Icons.arrow_back_ios, color: _currentIndex > 0 ? Colors.white : Colors.white24),
                  ),
                  Text(
                    '${_currentIndex + 1} / ${widget.cards.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  IconButton(
                    onPressed: _nextCard,
                    icon: Icon(
                      _currentIndex < widget.cards.length - 1 ? Icons.arrow_forward_ios : Icons.done_all,
                      color: _gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardSide({
    required String title,
    required String content,
    required Color color,
    Color? borderColor,
    required IconData icon,
    bool isBack = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor ?? Colors.white12, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _gold, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isBack ? 20 : 24,
                    color: Colors.white,
                    fontWeight: isBack ? FontWeight.w500 : FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
