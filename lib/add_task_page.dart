// 📁 lib/add_task_page.dart
// ✨ Diseño Tornasol + Lógica avanzada del add + Dropdown del edit + SnackBars visuales con íconos coloridos

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/notification_service.dart';

// 🎨 COLORES CYBERPUNK TORNASOL
const Color _primaryGold = Color(0xFFFFD700);
const Color _accentPurple = Color(0xFFB300FF);
const Color _accentCyan = Colors.cyanAccent;
const Color _darkBackground = Colors.black;

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedMateria = 'General';
  String _selectedPriority = 'media';
  DateTime? _selectedDueDate;
  bool _isSaving = false;

  final NotificationService _notificationService = NotificationService();
  late AnimationController _controller;

  final List<String> _materiasList = [
    'General',
    'CONCIENCIA HISTORICA 2. MEXICO DURANTE',
    'INGLES V',
    'METODOS DE INVESTIGACION II',
    'TEMAS SELECTOS DE MATEMATICAS II',
    'LA ENERGIA EN LOS PROCESOS DE LA VIDA DIARIA',
    'IMPLEMETA APLICACIONES WEB',
    'CONSTRUYE BASE DE DATOS',
    'FORMACION SOCIOEMOCIONAL V',
    'APLICA A LA ADMINISTRACION',
  ];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 🚨 SnackBar de error personalizado
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ SnackBar de éxito con ícono verde
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Determina el intervalo automático de notificaciones
  int _determineIntervalMinutes(DateTime dueDate) {
    final totalDuration = dueDate.difference(DateTime.now());
    if (totalDuration.isNegative) return 0;
    if (totalDuration.inHours >= 8) return 240;
    if (totalDuration.inHours >= 4) return 120;
    if (totalDuration.inHours >= 1) return 30;
    return 15;
  }

  // 📅 Selector de fecha y hora
  Future<void> _selectDateTime(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: today,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accentCyan,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: _darkBackground,
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: _accentCyan,
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: _darkBackground,
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        final newDueDate =
            DateTime(date.year, date.month, date.day, time.hour, time.minute);
        if (newDueDate.isBefore(now)) {
          _showErrorSnackBar(
              'La fecha y hora de vencimiento no puede ser en el pasado.');
          return;
        }
        setState(() => _selectedDueDate = newDueDate);
      }
    }
  }

  // 💾 Guarda la tarea en Firestore y programa notificaciones
  Future<void> _saveTask() async {
    if (_isSaving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showErrorSnackBar('El título de la tarea no puede estar vacío.');
      return;
    }

    if (_selectedDueDate == null) {
      _showErrorSnackBar('Debes seleccionar una fecha y hora de vencimiento.');
      return;
    }

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('No se pudo identificar al usuario.');
      return;
    }

    final description = _descriptionController.text.trim();

    final taskData = {
      'title': title,
      'materia': _selectedMateria,
      'description': description,
      'priority': _selectedPriority,
      'dueDate': Timestamp.fromDate(_selectedDueDate!),
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      final taskRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .add(taskData);

      final int baseNotificationId = taskRef.id.hashCode.abs() % 1000000;

      final Duration totalDuration =
          _selectedDueDate!.difference(DateTime.now());
      if (totalDuration.inMinutes >= 15) {
        final int intervalInMinutes =
            _determineIntervalMinutes(_selectedDueDate!);
        DateTime currentTime = DateTime.now().add(const Duration(minutes: 1));
        int counter = 0;

        while (currentTime.isBefore(_selectedDueDate!) && counter < 10) {
          final notificationId = baseNotificationId + counter;
          final remaining = _selectedDueDate!.difference(currentTime).inMinutes;
          final String timeStr = remaining > 60
              ? '${(remaining / 60).floor()} horas'
              : '$remaining minutos';

          await _notificationService.scheduleNotification(
            notificationId,
            '🔔 Recordatorio de "$title"',
            'Faltan $timeStr para el vencimiento.',
            currentTime,
          );

          currentTime = currentTime.add(Duration(minutes: intervalInMinutes));
          counter++;
        }
      } else {
        await _notificationService.scheduleNotification(
          baseNotificationId,
          '🚨 Último Recordatorio',
          'Tu tarea "$title" vence ahora.',
          _selectedDueDate!,
        );
      }

      _showSuccessSnackBar('✅ Tarea guardada correctamente.');

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('Error al guardar la tarea: $e');
      setState(() => _isSaving = false);
    }
  }

  // 🎨 DECORACIÓN DE CAMPOS CYBERPUNK
  InputDecoration _inputStyle(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _accentCyan),
      hintStyle: const TextStyle(color: Colors.white38),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white38),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accentCyan, width: 2),
      ),
    );
  }

  // ✨ BOTÓN ANIMADO
  Widget _animatedButton(String text, VoidCallback onTap) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color1 =
            Color.lerp(_primaryGold, _accentPurple, _controller.value)!;
        final color2 =
            Color.lerp(_accentPurple, _primaryGold, _controller.value)!;
        return InkWell(
          onTap: _isSaving ? null : onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color1, color2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _accentCyan, width: 2),
            ),
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ),
        );
      },
    );
  }

  // 📅 BOTÓN DE CALENDARIO ANIMADO
  Widget _animatedCalendarButton() {
    String formatDate(DateTime? date) {
      if (date == null) return 'Seleccionar Fecha y Hora';
      return DateFormat('dd/MM/yyyy h:mm a').format(date);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color1 =
            Color.lerp(_accentPurple, _primaryGold, _controller.value)!;
        final color2 =
            Color.lerp(_primaryGold, _accentPurple, _controller.value)!;
        return InkWell(
          onTap: _isSaving ? null : () => _selectDateTime(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color1, color2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentCyan, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDate(_selectedDueDate),
                  style: TextStyle(
                      color: _selectedDueDate == null
                          ? Colors.white70
                          : Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.calendar_today, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      appBar: AppBar(
        backgroundColor: _darkBackground,
        title: const Text('Agregar Tarea',
            style: TextStyle(color: _accentCyan, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _accentCyan),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: Center(
                  child: Image.asset(
                    'assets/logo/icon.png',
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width * 0.7,
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputStyle('Título de la tarea'),
                ),
                const SizedBox(height: 20),

                // 🎓 Dropdown de materia
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white38, width: 1),
                    borderRadius: BorderRadius.circular(10),
                    color: _darkBackground.withOpacity(0.5),
                  ),
                  child: Row(
                    children: [
                      const Text('Materia:',
                          style: TextStyle(color: _accentCyan, fontSize: 16)),
                      const SizedBox(width: 20),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedMateria,
                          dropdownColor: Colors.grey[900],
                          underline: Container(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: _primaryGold),
                          isExpanded: true,
                          items: _materiasList.map((value) {
                            return DropdownMenuItem(
                              value: value,
                              child: Text(value,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: _isSaving
                              ? null
                              : (newValue) =>
                                  setState(() => _selectedMateria = newValue!),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                TextField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: _inputStyle('Descripción (opcional)'),
                ),
                const SizedBox(height: 30),

                // Dropdown de prioridad
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white38, width: 1),
                    borderRadius: BorderRadius.circular(10),
                    color: _darkBackground.withOpacity(0.5),
                  ),
                  child: Row(
                    children: [
                      const Text('Prioridad:',
                          style: TextStyle(color: _accentCyan, fontSize: 16)),
                      const SizedBox(width: 20),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedPriority,
                          dropdownColor: Colors.grey[900],
                          underline: Container(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: _primaryGold),
                          isExpanded: true,
                          items: ['baja', 'media', 'alta'].map((value) {
                            Color itemColor = Colors.white;
                            if (value == 'alta') itemColor = Colors.redAccent;
                            if (value == 'media') itemColor = _primaryGold;
                            if (value == 'baja') itemColor = Colors.greenAccent;
                            return DropdownMenuItem(
                              value: value,
                              child: Text(value.toUpperCase(),
                                  style: TextStyle(
                                      color: itemColor,
                                      fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: _isSaving
                              ? null
                              : (newValue) =>
                                  setState(() => _selectedPriority = newValue!),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                _animatedCalendarButton(),
                const SizedBox(height: 50),
                _animatedButton(
                    _isSaving ? 'GUARDANDO...' : 'AGREGAR TAREA', _saveTask),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
