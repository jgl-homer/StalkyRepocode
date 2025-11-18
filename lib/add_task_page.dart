// 📁 lib/add_task_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/notification_service.dart';
import 'package:flutter/services.dart'; 

// --- COLORES CYBERPUNK ---
const Color _primaryGold = Color(0xFFFFD700);
const Color _accentCyan = Colors.cyanAccent;
const Color _darkBackground = Colors.black;
// -------------------------

// ⬇️ 1. Tu lista de materias predeterminada
final List<String> kMateriasList = [
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

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage>
    with SingleTickerProviderStateMixin {
  
  // --- Controladores ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController(); 
  final TextEditingController _subtaskController = TextEditingController(); 

  // --- Estado ---
  String? _selectedMateria = 'General'; 
  String _selectedPriority = 'media';
  DateTime? _selectedDueDate;
  bool _isSaving = false;
  List<Map<String, dynamic>> _subtasks = []; 

  final NotificationService _notificationService = NotificationService();
  late AnimationController _controller;

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
    _subtaskController.dispose(); 
    super.dispose();
  }

  int _determineIntervalMinutes(DateTime dueDate) {
    final totalDuration = dueDate.difference(DateTime.now());
    if (totalDuration.isNegative) return 0;
    if (totalDuration.inHours >= 8) return 240;
    else if (totalDuration.inHours >= 4) return 120;
    else if (totalDuration.inHours >= 1) return 30;
    else return 15;
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
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
        initialTime: _selectedDueDate != null
            ? TimeOfDay.fromDateTime(_selectedDueDate!)
            : TimeOfDay.now(),
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
        if (newDueDate.isAfter(now)) {
          setState(() => _selectedDueDate = newDueDate);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La fecha no puede ser pasada.')),
          );
        }
      }
    }
  }

  Future<void> _saveTask() async {
    if (_isSaving) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor escribe un título.')),
      );
      return;
    }
    setState(() => _isSaving = true);

    final String materia = _selectedMateria ?? 'General';
    final String description = _descriptionController.text.trim();

    final newTask = {
      'title': title,
      'materia': materia, 
      'description': description, 
      'priority': _selectedPriority,
      'dueDate': _selectedDueDate != null
          ? Timestamp.fromDate(_selectedDueDate!)
          : Timestamp.fromDate(DateTime(3000)), 
      'createdAt': Timestamp.now(),
      'completed': false, 
      'subtasks': _subtasks, 
    };

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .add(newTask);
      
      if (_selectedDueDate != null) {
        final Duration totalDuration =
            _selectedDueDate!.difference(DateTime.now());
        final String taskIdString = docRef.id;
        final int baseNotificationId = taskIdString.hashCode.abs() % 1000000;
        if (totalDuration.inMinutes < 15) {
          final int notificationId = baseNotificationId + 0;
          await _notificationService.scheduleNotification(
            notificationId,
            '🚨 ¡Último Recordatorio!',
            'Tu tarea "$title" vence AHORA. ¡Es hora de completarla!',
            _selectedDueDate!,
          );
        } else {
          final int intervalInMinutes =
              _determineIntervalMinutes(_selectedDueDate!);
          if (intervalInMinutes > 0) {
            DateTime currentTime = DateTime.now();
            final DateTime finalDueDate = _selectedDueDate!;
            int notificationCounter = 0;
            while (currentTime.isBefore(finalDueDate)) {
              final int notificationId =
                  baseNotificationId + notificationCounter;
              final Duration remainingTime = finalDueDate.difference(
                currentTime,
              );
              final String remainingTimeString = remainingTime.inMinutes > 60
                  ? '${remainingTime.inHours} horas'
                  : '${remainingTime.inMinutes} minutos';
              await _notificationService.scheduleNotification(
                notificationId,
                '🔔 Recordatorio Constante: $title',
                '¡Faltan $remainingTimeString! (Recordatorio cada $intervalInMinutes min.)',
                currentTime,
              );
              currentTime = currentTime.add(
                Duration(minutes: intervalInMinutes),
              );
              notificationCounter++;
            }
          }
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }
  
  void _addSubtask() {
    final String title = _subtaskController.text.trim();
    if (title.isNotEmpty) {
      setState(() {
        _subtasks.add({"title": title, "completed": false});
        _subtaskController.clear();
      });
    }
  }

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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white38, width: 1),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      appBar: AppBar(
        title: const Text(
          'Agregar Tarea',
          style: TextStyle(color: _accentCyan, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _darkBackground,
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
                  decoration: _getInputDecoration('Título de la tarea'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _getInputDecoration(
                    'Descripción (Opcional)',
                    hint: 'Detalles, links, etc.',
                  ),
                  minLines: 1, 
                  maxLines: 3, 
                  maxLength: 500, 
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                    Text(
                      '$currentLength/$maxLength',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[<>]')),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedMateria,
                  items: kMateriasList.map((String materia) { 
                    return DropdownMenuItem<String>(
                      value: materia,
                      child: Text(materia, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _isSaving ? null : (value) {
                    setState(() {
                      _selectedMateria = value;
                    });
                  },
                  decoration: _getInputDecoration('Materia'),
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: _primaryGold),
                ),
                const SizedBox(height: 30),
                DropdownButtonFormField<String>(
                  value: _selectedPriority,
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
                            color: itemColor, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: _isSaving ? null : (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedPriority = newValue;
                      });
                    }
                  },
                  decoration: _getInputDecoration('Prioridad'),
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: _primaryGold),
                ),
                const SizedBox(height: 30),
                animatedCalendarButton(),
                const SizedBox(height: 30),

                const Text(
                  'SUB-TAREAS (Opcional)',
                  style: TextStyle(color: _accentCyan, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subtaskController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _getInputDecoration('Nueva sub-tarea', hint: 'Ej: Leer capítulo 1'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: _accentCyan, size: 30),
                      onPressed: _addSubtask,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                
                // ⬇️ MODIFICADO: Lista de sub-tareas con confirmación de borrado
                ListView.builder(
                  shrinkWrap: true, 
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _subtasks.length,
                  itemBuilder: (context, index) {
                    final subtask = _subtasks[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.arrow_right, color: _primaryGold),
                      title: Text(
                        subtask['title'],
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () async {
                          // ⬇️ NUEVA ALERTA DE CONFIRMACIÓN
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: Colors.grey[900],
                                title: const Text('¿Eliminar sub-tarea?', style: TextStyle(color: Colors.white)),
                                content: Text('Se borrará "${subtask['title']}".', style: const TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              );
                            },
                          );
                          
                          if (confirm == true) {
                            setState(() {
                              _subtasks.removeAt(index);
                            });
                          }
                          // ⬆️ FIN ALERTA
                        },
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 50),
                animatedButton(
                  text: _isSaving ? 'GUARDANDO...' : 'GUARDAR TAREA',
                  onTap: _isSaving ? () {} : _saveTask,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}