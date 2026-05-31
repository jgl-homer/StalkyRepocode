import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
  List<_DetectedTaskDraft> _detectedTasks = [];

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
          _disposeDrafts();
          _detectedTasks = [];
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Seleccionar origen',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _gold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _sourceButton(
                  icon: Icons.camera_alt,
                  label: 'Camara',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _sourceButton(
                  icon: Icons.photo_library,
                  label: 'Galeria',
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

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _gold, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Future<User?> _ensureUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) return user;

    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      return cred.user;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de autenticacion: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return null;
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    final user = await _ensureUser();
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _analysisLogs.clear();
      _disposeDrafts();
      _detectedTasks = [];
    });

    try {
      final result = await _aiService.processNotesImage(
        imageBytes: _imageBytes!,
        userId: user.uid,
      );

      if (!mounted) return;

      final rawTasks = List<Map<String, dynamic>>.from(
        result['tasksDetected'] ?? const [],
      );

      setState(() {
        _analysisLogs = List<String>.from(result['logs'] ?? []);
        _detectedTasks = rawTasks
            .map(
              (task) => _DetectedTaskDraft(
                title: task['title']?.toString() ?? 'Nueva tarea',
                category: task['materia']?.toString() ?? 'Escuela',
              ),
            )
            .toList();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rawTasks.isEmpty
                ? 'Analisis completado sin tareas detectadas.'
                : 'Analisis completado. Asigna fecha y hora.',
            style: const TextStyle(color: Colors.black),
          ),
          backgroundColor: _gold,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _analysisLogs = ['Error en analisis: $e'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar apunte: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _selectDate(_DetectedTaskDraft task) async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: task.selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: _gold,
            onSurface: Colors.white,
            surface: _cardBg,
          ),
          dialogTheme: DialogThemeData(backgroundColor: _bg),
        ),
        child: child!,
      ),
    );

    if (selectedDate == null || !mounted) return;
    setState(() => task.selectedDate = selectedDate);
  }

  Future<void> _selectTime(_DetectedTaskDraft task) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: task.selectedTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: _gold,
            onSurface: Colors.white,
            surface: _cardBg,
          ),
          dialogTheme: DialogThemeData(backgroundColor: _bg),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      ),
    );

    if (selectedTime == null || !mounted) return;
    setState(() => task.selectedTime = selectedTime);
  }

  Future<void> _saveDetectedTask(_DetectedTaskDraft task) async {
    if (task.isSaving || task.isSaved) return;

    if (task.selectedDate == null || task.selectedTime == null) {
      _showSnack('Selecciona fecha y hora antes de guardar.');
      return;
    }

    final dueDate = DateTime(
      task.selectedDate!.year,
      task.selectedDate!.month,
      task.selectedDate!.day,
      task.selectedTime!.hour,
      task.selectedTime!.minute,
    );

    if (!dueDate.isAfter(DateTime.now())) {
      _showSnack('La fecha y hora no pueden estar en el pasado.');
      return;
    }

    final user = await _ensureUser();
    if (user == null) return;

    setState(() => task.isSaving = true);
    try {
      await _aiService.saveDetectedTask(
        userId: user.uid,
        title: task.title,
        materia: task.category,
        note: task.noteController.text.trim(),
        dueDate: dueDate,
      );

      if (!mounted) return;
      setState(() {
        task.isSaving = false;
        task.isSaved = true;
      });
      _showSnack('Recordatorio guardado y notificacion programada.');
    } catch (e) {
      if (!mounted) return;
      setState(() => task.isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar recordatorio: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.black)),
        backgroundColor: _gold,
      ),
    );
  }

  void _disposeDrafts() {
    for (final task in _detectedTasks) {
      task.dispose();
    }
  }

  @override
  void dispose() {
    _disposeDrafts();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          'Asistente de Estudio IA',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(child: _buildAnalysisTab()),
    );
  }

  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sube una imagen de tus apuntes, libreta o pizarron para detectar tareas. Tu eliges cuando recibir el recordatorio.',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
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
                    color: _gold.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 56,
                      color: _gold.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Toca para tomar o subir una foto',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Formatos soportados: JPG, PNG',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildImagePreview(),
          const SizedBox(height: 30),
          if (_isLoading)
            _buildLoadingState()
          else ...[
            if (_detectedTasks.isNotEmpty) _buildDetectedTasks(),
            if (_analysisLogs.isNotEmpty) ...[
              if (_detectedTasks.isNotEmpty) const SizedBox(height: 18),
              _buildResultsCard(),
            ],
          ],
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
                  image: MemoryImage(_imageBytes!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => setState(() {
                  _imageBytes = null;
                  _analysisLogs.clear();
                  _disposeDrafts();
                  _detectedTasks = [];
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.redAccent,
                    size: 20,
                  ),
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
                label: const Text(
                  'Cambiar Foto',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyzeImage,
                icon: const Icon(Icons.auto_awesome, color: Colors.black),
                label: const Text(
                  'Analizar con IA',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
          Text(
            'Gemini esta analizando la imagen...',
            style: GoogleFonts.outfit(
              color: _gold,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
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

  Widget _buildDetectedTasks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.task_alt, color: _gold),
            const SizedBox(width: 8),
            Text(
              'Tareas detectadas',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._detectedTasks.map(_buildTaskCard),
      ],
    );
  }

  Widget _buildTaskCard(_DetectedTaskDraft task) {
    final dateLabel = task.selectedDate == null
        ? 'Seleccionar fecha'
        : DateFormat('dd/MM/yyyy').format(task.selectedDate!);
    final timeLabel = task.selectedTime == null
        ? 'Seleccionar hora'
        : task.selectedTime!.format(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              task.isSaved ? Colors.greenAccent : _gold.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome, color: _gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.category,
                      style: GoogleFonts.inter(color: _gold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (task.isSaved)
                const Icon(Icons.check_circle, color: Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  icon: Icons.calendar_month,
                  label: dateLabel,
                  onTap: task.isSaved ? null : () => _selectDate(task),
                  cardBg: Colors.black,
                  gold: _gold,
                  isSelected: task.selectedDate != null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerField(
                  icon: Icons.schedule,
                  label: timeLabel,
                  onTap: task.isSaved ? null : () => _selectTime(task),
                  cardBg: Colors.black,
                  gold: _gold,
                  isSelected: task.selectedTime != null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: task.noteController,
            enabled: !task.isSaved,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Nota adicional (opcional)',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              filled: true,
              fillColor: Colors.black,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _gold, width: 1.5),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: task.isSaving || task.isSaved
                  ? null
                  : () => _saveDetectedTask(task),
              icon: task.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      task.isSaved ? Icons.check : Icons.notifications_active,
                      color: Colors.black,
                    ),
              label: Text(
                task.isSaved ? 'Recordatorio guardado' : 'Guardar Recordatorio',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: task.isSaved ? Colors.greenAccent : _gold,
                disabledBackgroundColor: task.isSaved
                    ? Colors.greenAccent
                    : _gold.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
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
              Text(
                'Resultados del analisis',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          ..._analysisLogs.map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '- ',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  Expanded(
                    child: Text(
                      log,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedTaskDraft {
  _DetectedTaskDraft({
    required this.title,
    required this.category,
  });

  final String title;
  final String category;
  final TextEditingController noteController = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool isSaving = false;
  bool isSaved = false;

  void dispose() {
    noteController.dispose();
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cardBg,
    required this.gold,
    required this.isSelected,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color cardBg;
  final Color gold;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? gold : gold.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
