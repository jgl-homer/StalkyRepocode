// Archivo: lib/add_task_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz; // Importación necesaria
import 'package:intl/intl.dart';
import 'services/notification_service.dart';

// Definición simple del Enum (Si no lo tienes en un archivo de modelo)
enum Priority { baja, media, alta }

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Priority _selectedPriority = Priority.media;
  String? _error;

  bool _isSaving = false;
  final NotificationService _notificationService = NotificationService();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // FUNCIÓN CLAVE: Determinar el intervalo de repetición automáticamente
  int _determineIntervalMinutes(DateTime dueDate) {
    final totalDuration = dueDate.difference(DateTime.now());

    if (totalDuration.isNegative) {
      return 0; // No programar si ya venció
    }

    // Si la duración total es mayor o igual a 8 horas
    if (totalDuration.inHours >= 8) {
      return 240; // 4 horas de intervalo
    }
    // Si la duración total es mayor o igual a 4 horas
    else if (totalDuration.inHours >= 4) {
      return 120; // 2 horas de intervalo
    }
    // Si la duración total es mayor o igual a 1 hora
    else if (totalDuration.inHours >= 1) {
      return 30; // 30 minutos de intervalo
    }
    // Si la duración total es menor a 1 hora (debe ser manejado por la lógica de un solo aviso)
    else {
      return 15;
    }
  }

  Future<void> _saveTask() async {
    if (_isSaving) return;

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      setState(() => _error = 'El título es obligatorio.');
      return;
    }

    if ((_selectedDate != null && _selectedTime == null) ||
        (_selectedDate == null && _selectedTime != null)) {
      setState(
        () => _error =
            'Debes seleccionar tanto la fecha como la hora, o dejar ambas vacías.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Usuario no autenticado.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    DateTime? dueDate;
    if (_selectedDate != null && _selectedTime != null) {
      dueDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    if (dueDate != null && dueDate.isBefore(DateTime.now())) {
      setState(
        () => _error = 'La fecha de vencimiento no puede ser en el pasado.',
      );
      _isSaving = false;
      return;
    }

    try {
      final tasksRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks');

      final taskData = {
        'title': _titleController.text.trim(),
        'userId': user.uid,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
        'priority': _selectedPriority.name,
        'createdAt': FieldValue.serverTimestamp(),
        'completed': false,
      };

      final docRef = await tasksRef.add(taskData);

      // 2. CREACIÓN DE NOTIFICACIONES CON LÓGICA DE INTERVALO
      if (dueDate != null) {
        final Duration totalDuration = dueDate.difference(DateTime.now());
        final String taskIdString = docRef.id;
        final int baseNotificationId = taskIdString.hashCode.abs() % 1000000;

        // 🔑 CORRECCIÓN: Si la duración es menor a 15 minutos, solo programamos UNA alarma final.
        if (totalDuration.inMinutes < 15) {
          final int notificationId = baseNotificationId + 0;

          await _notificationService.scheduleNotification(
            notificationId,
            '🚨 ¡Último Recordatorio!',
            'Tu tarea "${taskData['title']}" vence AHORA. ¡Es hora de completarla!',
            dueDate, // Alarma programada exactamente a la hora de vencimiento
          );
        } else {
          // Si la duración es de 15 minutos o más, usamos la lógica de lotes (constancia)

          final int intervalInMinutes = _determineIntervalMinutes(dueDate);

          if (intervalInMinutes > 0) {
            DateTime currentTime = DateTime.now();
            final DateTime finalDueDate = dueDate;

            int notificationCounter = 0;

            // BUCLE DE PROGRAMACIÓN POR LOTE
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
                '🔔 Recordatorio Constante: ${taskData['title']}',
                '¡Faltan $remainingTimeString! (Recordatorio cada $intervalInMinutes min.)',
                currentTime,
              );

              // Avanzar al próximo recordatorio
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
      setState(() => _error = 'Error al guardar la tarea: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usar DateFormat para manejar el formato de hora AM/PM correctamente
    String formatDate(DateTime? date, TimeOfDay? time) {
      if (date == null || time == null) return 'Seleccionar Fecha y Hora';
      final combined = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      return DateFormat('dd/MM/yyyy h:mm a').format(combined);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nueva Tarea'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título de la Tarea',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'El título es obligatorio'
                    : null,
              ),
              const SizedBox(height: 20),
              // Selector de Fecha y Hora
              Card(
                color: Colors.white10,
                child: ListTile(
                  title: Text(
                    formatDate(_selectedDate, _selectedTime),
                    style: TextStyle(
                      color: _selectedDate == null
                          ? Colors.white54
                          : Colors.white,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.calendar_today,
                    color: Colors.cyanAccent,
                  ),
                  onTap: () async {
                    await _pickDate();
                    if (mounted && _selectedDate != null) {
                      await _pickTime();
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Prioridad:',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              // Selector de Prioridad
              Column(
                children: Priority.values.map((priority) {
                  return RadioListTile<Priority>(
                    title: Text(
                      priority.name.toUpperCase(),
                      style: TextStyle(
                        color: priority == Priority.alta
                            ? Colors.redAccent
                            : Colors.white,
                      ),
                    ),
                    value: priority,
                    groupValue: _selectedPriority,
                    onChanged: (value) =>
                        setState(() => _selectedPriority = value!),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              // Botón de Guardar
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _isSaving ? null : _saveTask,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Guardar Tarea',
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
