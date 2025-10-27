import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// 💡 CORRECCIÓN DE IMPORTACIÓN: Usar la ruta relativa para archivos locales
import 'services/notification_service.dart';

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

class _EditTaskPageState extends State<EditTaskPage> {
  late TextEditingController _titleController;
  late String _selectedPriority;
  late DateTime? _selectedDueDate;

  // 💡 Instancia del servicio de notificaciones
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialData['title'] ?? '',
    );
    _selectedPriority = widget.initialData['priority'] ?? 'media';

    if (widget.initialData['dueDate'] != null &&
        widget.initialData['dueDate'] is Timestamp) {
      _selectedDueDate = (widget.initialData['dueDate'] as Timestamp).toDate();
    } else {
      _selectedDueDate = null;
    }
  }

  // Selector combinado de Fecha y Hora
  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate:
          _selectedDueDate ?? DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.cyanAccent,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _selectedDueDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _updateTask() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _titleController.text.trim().isEmpty) return;

    // Generamos el ID de notificación basado en el ID del documento
    final int notificationId = widget.taskId.hashCode.abs() % 1000000;

    final dataToUpdate = {
      'title': _titleController.text.trim(),
      'priority': _selectedPriority,
      'dueDate': _selectedDueDate != null
          ? Timestamp.fromDate(_selectedDueDate!)
          : null,
    };

    try {
      // 1. Actualización en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(widget.taskId)
          .update(dataToUpdate);

      // 2. CANCELAR NOTIFICACIÓN ANTIGUA (importante para evitar duplicados)
      await _notificationService.cancelNotification(notificationId);

      // 3. PROGRAMAR NUEVA NOTIFICACIÓN (si hay fecha de vencimiento válida)
      if (_selectedDueDate != null) {
        final reminderTime = _selectedDueDate!.subtract(
          const Duration(hours: 1),
        );

        if (reminderTime.isAfter(DateTime.now())) {
          await _notificationService.scheduleNotification(
            notificationId,
            '🔄 Tarea Modificada: ${_titleController.text.trim()}',
            '¡Tu tarea de prioridad ${_selectedPriority.toUpperCase()} vence en 1 hora!',
            reminderTime,
          );
        }
      }

      // 💡 CORRECCIÓN LINT: Usar if (mounted)
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // 💡 CORRECCIÓN LINT: Usar if (mounted)
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Editar Tarea'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo de Título
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Título de la tarea',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Selector de Prioridad
              const Text(
                'Prioridad:',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              DropdownButton<String>(
                value: _selectedPriority,
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.cyanAccent,
                ),
                items: ['baja', 'media', 'alta'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.toUpperCase()),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedPriority = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 30),

              // Selector de Fecha
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDueDate == null
                        ? 'Sin fecha de vencimiento'
                        : 'Vence: ${DateFormat('dd/MM/yyyy HH:mm').format(_selectedDueDate!)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  TextButton.icon(
                    icon: const Icon(
                      Icons.calendar_today,
                      color: Colors.cyanAccent,
                    ),
                    label: const Text(
                      'Cambiar Fecha',
                      style: TextStyle(color: Colors.cyanAccent),
                    ),
                    onPressed: () => _selectDateTime(context),
                  ),
                ],
              ),
              const SizedBox(height: 50),

              // Botón de Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _updateTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'GUARDAR CAMBIOS',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
