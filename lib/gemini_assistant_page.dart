import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/ai_service.dart';

class GeminiAssistantPage extends StatefulWidget {
  const GeminiAssistantPage({super.key});

  @override
  State<GeminiAssistantPage> createState() => _GeminiAssistantPageState();
}

class _GeminiAssistantPageState extends State<GeminiAssistantPage> {
  final AIService _aiService = AIService();
  final ImagePicker _imagePicker = ImagePicker();

  final Color _bg = const Color(0xFF000000);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _cardBg = const Color(0xFF1E1E1E);

  Uint8List? _imageBytes;
  bool _isLoading = false;
  List<String> _analysisLogs = [];

  // ── Selección de imagen ───────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _imageBytes = bytes;
          _analysisLogs.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Seleccionar Origen',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold, color: _gold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sourceButton(
                  icon: Icons.camera_alt,
                  label: 'Cámara',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _sourceButton(
                  icon: Icons.photo_library,
                  label: 'Galería',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sourceButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.black, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: _gold, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  // ── Análisis IA ───────────────────────────────────────────────────────────

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    // Obtener uid (con anónimo como respaldo)
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[GEMINI_UI] No hay usuario activo. Intentando login anónimo...');
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
        print('[GEMINI_UI] Login anónimo exitoso. UID: ${user?.uid}');
      } catch (e) {
        print('[GEMINI_UI_ERROR] Falló login anónimo: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de autenticación específico: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _analysisLogs.clear();
    });

    try {
      final result = await _aiService.processNotesImage(
        imageBytes: _imageBytes!,
        userId: user!.uid,
      );

      if (!mounted) return;

      setState(() {
        _analysisLogs = List<String>.from(result['logs'] ?? []);
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Análisis completado!',
              style: TextStyle(color: Colors.black)),
          backgroundColor: _gold,
        ),
      );
    } catch (e) {
      print('[GEMINI_UI_ERROR] Excepción atrapada durante el análisis: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _analysisLogs = ['❌ Error en análisis: $e'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error específico al procesar apunte: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          'Asistente de Estudio IA',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _buildAnalysisTab(),
      ),
    );
  }

  // ── Pestaña 1: Análisis ───────────────────────────────────────────────────

  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sube una imagen de tus apuntes, libreta o pizarrón para detectar tareas de forma automática.',
            style: GoogleFonts.inter(
                color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),

          // ── Zona de imagen ──
          if (_imageBytes == null)
            GestureDetector(
              onTap: _showImageSourceOptions,
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _gold.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: 56, color: _gold.withValues(alpha: 0.8)),
                    const SizedBox(height: 16),
                    Text('Toca para tomar o subir una foto',
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Formatos soportados: JPG, PNG',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.white38)),
                  ],
                ),
              ),
            )
          else
            _buildImagePreview(),

          const SizedBox(height: 30),

          // ── Estado / Resultados ──
          if (_isLoading)
            _buildLoadingState()
          else if (_analysisLogs.isNotEmpty)
            _buildResultsCard(),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold, width: 2),
                image: DecorationImage(
                    image: MemoryImage(_imageBytes!), fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => setState(() {
                  _imageBytes = null;
                  _analysisLogs.clear();
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.delete,
                      color: Colors.redAccent, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showImageSourceOptions,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Cambiar Foto',
                    style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyzeImage,
                icon: const Icon(Icons.auto_awesome, color: Colors.black),
                label: const Text('Analizar con IA',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircularProgressIndicator(color: _gold),
          const SizedBox(height: 16),
          Text('Gemini está analizando la imagen...',
              style: GoogleFonts.outfit(
                  color: _gold, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Esto puede tardar unos segundos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: _gold),
              const SizedBox(width: 8),
              Text('Resultados del Análisis',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          ..._analysisLogs.map((log) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: Colors.white54, fontSize: 16)),
                    Expanded(
                      child: Text(log,
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 14, height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
