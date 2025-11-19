// 📁 lib/edit_task_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/notification_service.dart';

// --- COLORES CYBERPUNK ---
const Color _primaryGold = Color(0xFFFFD700);
const Color _accentCyan = Colors.cyanAccent;
const Color _darkBackground = Colors.black;
// -------------------------

class EditTaskPage extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> initialData;

  const EditTaskPage({
    super.key,
    required this.taskId,
    required this.initialData,
  });

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

// 🔥 AGREGAR: SingleTickerProviderStateMixin para animaciones
class _EditTaskPageState extends State<EditTaskPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _materiaController;
  late String _selectedPriority;
  late DateTime? _selectedDueDate;

  bool _isSaving = false;

  final NotificationService _notificationService = NotificationService();

  // 🔥 AGREGAR: Controlador de animación
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 🔥 INICIALIZAR: Controlador de animación para los botones
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();

    _titleController = TextEditingController(
      text: widget.initialData['title'] ?? '',
    );
    _materiaController = TextEditingController(
      text: widget.initialData['materia'] ?? 'General',
    );
    _selectedPriority = widget.initialData['priority'] ?? 'media';

    if (widget.initialData['dueDate'] != null &&
        widget.initialData['dueDate'] is Timestamp) {
      _selectedDueDate = (widget.initialData['dueDate'] as Timestamp).toDate();
    } else {
      _selectedDueDate = null;
    }
  }

  @override
  void dispose() {
    // 🔥 LIMPIAR: Liberar controlador de animación
    _controller.dispose();
    _titleController.dispose();
    _materiaController.dispose();
    super.dispose();
  }

  // 🔥 LÓGICA AGREGADA: Determina el intervalo de repetición automáticamente
  int _determineIntervalMinutes(DateTime dueDate) {
    final totalDuration = dueDate.difference(DateTime.now());

    if (totalDuration.isNegative) return 0;

    if (totalDuration.inHours >= 8) {
      return 240; // 4 horas
    } else if (totalDuration.inHours >= 4) {
      return 120; // 2 horas
    } else if (totalDuration.inHours >= 1) {
      return 30; // 30 minutos
    } else {
      return 15; // 15 minutos
    }
  }

  // Selector combinado de Fecha y Hora (CON TEMA CYBERPUNK)
  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: todayStart,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accentCyan, // Aplicar color
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: _darkBackground, // Aplicar color
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      TimeOfDay initialTime = _selectedDueDate != null
          ? TimeOfDay.fromDateTime(_selectedDueDate!)
          : TimeOfDay.now();

      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: _accentCyan, // Aplicar color
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: _darkBackground, // Aplicar color
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        final DateTime newDueDate = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        if (newDueDate.isBefore(now)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'La fecha y hora de vencimiento no puede ser en el pasado.')),
            );
          }
          return;
        }

        setState(() {
          _selectedDueDate = newDueDate;
        });
      }
    }
  }

  // 🔥 MÉTODO _updateTask CON LÓGICA DE NOTIFICACIONES MÚLTIPLES
  Future<void> _updateTask() async {
    if (_isSaving) return;

    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('El título de la tarea no puede estar vacío.')),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
      return;
    }

    final String rawMateria = _materiaController.text.trim();
    final String materia = rawMateria.isEmpty ? 'General' : rawMateria;

    final dataToUpdate = {
      'title': title,
      'materia': materia,
      'priority': _selectedPriority,
      'dueDate': _selectedDueDate != null
          ? Timestamp.fromDate(_selectedDueDate!)
          : null,
    };

    // 1. Obtener la ID base para las notificaciones
    final int baseNotificationId = widget.taskId.hashCode.abs() % 1000000;

    try {
      // 2. CANCELAR TODAS LAS NOTIFICACIONES ANTIGUAS RELACIONADAS CON ESTA TAREA
      // Cancelamos hasta 10 posibles IDs usados en la recurrencia anterior.
      for (int i = 0; i < 10; i++) {
        await _notificationService.cancelNotification(baseNotificationId + i);
      }

      // 3. Actualización en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(widget.taskId)
          .update(dataToUpdate);

      // 4. PROGRAMAR NUEVAS NOTIFICACIONES MÚLTIPLES
      if (_selectedDueDate != null) {
        final Duration totalDuration =
            _selectedDueDate!.difference(DateTime.now());

        if (totalDuration.inMinutes >= 15) {
          final int intervalInMinutes =
              _determineIntervalMinutes(_selectedDueDate!);

          if (intervalInMinutes > 0) {
            DateTime currentTime = DateTime.now().add(
                const Duration(minutes: 1)); // Empezar 1 min después de ahora
            final DateTime finalDueDate = _selectedDueDate!;
            int notificationCounter = 0;

            // Bucle que programa notificaciones espaciadas hasta la fecha de vencimiento
            // Limitamos a 10 notificaciones como máximo para evitar problemas de límite
            while (currentTime.isBefore(finalDueDate) &&
                notificationCounter < 10) {
              final int notificationId =
                  baseNotificationId + notificationCounter;

              final Duration remainingTime =
                  finalDueDate.difference(currentTime);
              final String remainingTimeString = remainingTime.inMinutes > 60
                  ? '${remainingTime.inHours} horas'
                  : '${remainingTime.inMinutes} minutos';

              await _notificationService.scheduleNotification(
                notificationId,
                '🔄 Recordatorio Constante (Editado): $title',
                '¡Faltan $remainingTimeString! (Recordatorio cada $intervalInMinutes min.)',
                currentTime,
              );

              // Avanzamos al siguiente intervalo
              currentTime = currentTime.add(
                Duration(minutes: intervalInMinutes),
              );
              notificationCounter++;
            }
          }
        } else if (totalDuration.inSeconds > 0) {
          // Si faltan menos de 15 minutos, solo se programa la notificación final
          await _notificationService.scheduleNotification(
            baseNotificationId,
            '🚨 ¡Último Recordatorio (Editado)!',
            'Tu tarea "$title" vence AHORA. ¡Es hora de completarla!',
            _selectedDueDate!,
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));

        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // 🔥 WIDGET: InputDecoration con estilo Cyberpunk
  InputDecoration _getInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _accentCyan),
      hintStyle: const TextStyle(color: Colors.white30),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white38, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accentCyan, width: 2),
      ),
    );
  }

  // 🔥 WIDGET: Botón animado con degradado dorado/morado
  Widget animatedButton({required String text, required VoidCallback onTap}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color1 = Color.lerp(const Color(0xFFFFD700),
            const Color(0xFFB300FF), _controller.value)!;
        final color2 = Color.lerp(const Color(0xFFB300FF),
            const Color(0xFFFFD700), _controller.value)!;
        return InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _isSaving ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  // 🔥 WIDGET: Botón de calendario animado con degradado
  Widget animatedCalendarButton() {
    String formatDate(DateTime? date) {
      if (date == null) return 'Seleccionar Fecha y Hora';
      return DateFormat('dd/MM/yyyy h:mm a').format(date);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color1 = Color.lerp(const Color(0xFF9C27B0),
            const Color(0xFFB300FF), _controller.value)!;
        final color2 = Color.lerp(const Color(0xFFB300FF),
            const Color(0xFF9C27B0), _controller.value)!;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isSaving ? null : () => _selectDateTime(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color1, color2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.calendar_today, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
  // 🔥 FIN DE WIDGETS CYBERPUNK

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground, // Aplicar color
      appBar: AppBar(
        title: const Text(
          'Editar Tarea',
          style: TextStyle(
              color: _accentCyan, fontWeight: FontWeight.bold), // Aplicar color
        ),
        backgroundColor: _darkBackground, // Aplicar color
        iconTheme: const IconThemeData(color: _accentCyan), // Aplicar color
      ),
      body: Stack(
        children: [
          // Fondo con el logo (similar a AddTaskPage)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: Center(
                  child: Image.asset(
                    'assets/logo/icon.png', // Asumiendo que esta ruta existe
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
                // Campo de Título con estilo Cyberpunk
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _getInputDecoration('Título de la tarea'),
                ),
                const SizedBox(height: 20),

                // Campo de Materia con estilo Cyberpunk
                TextField(
                  controller: _materiaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _getInputDecoration(
                    'Materia',
                    hint: 'Ej: Matemáticas, Inglés, General',
                  ),
                ),
                const SizedBox(height: 30),

                // Selector de Prioridad con estilo Cyberpunk
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
                      const Text(
                        'Prioridad:',
                        style: TextStyle(color: _accentCyan, fontSize: 16),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedPriority,
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          underline: Container(),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: _primaryGold,
                          ),
                          isExpanded: true,
                          items: ['baja', 'media', 'alta'].map((String value) {
                            Color itemColor = Colors.white;
                            if (value == 'alta') itemColor = Colors.redAccent;
                            if (value == 'media') itemColor = _primaryGold;
                            if (value == 'baja') itemColor = Colors.greenAccent;

                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value.toUpperCase(),
                                style: TextStyle(
                                    color: itemColor,
                                    fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: _isSaving
                              ? null
                              : (String? newValue) {
                                  if (newValue != null)
                                    setState(
                                        () => _selectedPriority = newValue);
                                },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Botón de calendario animado
                animatedCalendarButton(),

                const SizedBox(height: 50),

                // Botón de Guardar animado
                animatedButton(
                  text: _isSaving ? 'GUARDANDO...' : 'GUARDAR CAMBIOS',
                  onTap: _isSaving ? () {} : _updateTask,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
