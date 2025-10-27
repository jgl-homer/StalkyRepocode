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

  // 💡 ESTADO NUEVO: Bandera para controlar la doble pulsación
  bool _isSaving = false;

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

  // Selector combinado de Fecha y Hora (CORREGIDO)
  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime now = DateTime.now();
    // No permitir seleccionar fechas anteriores al inicio del día actual
    final DateTime todayStart = DateTime(now.year, now.month, now.day);

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      // 💡 CORRECCIÓN: No permitir fechas pasadas
      firstDate: todayStart,
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
      TimeOfDay initialTime;

      // Si la fecha seleccionada es HOY, la hora inicial debe ser la hora actual
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        initialTime = TimeOfDay.fromDateTime(now);
      } else {
        // Para días futuros, usar la hora que ya estaba seleccionada o la hora actual
        initialTime = TimeOfDay.fromDateTime(_selectedDueDate ?? now);
      }

      final TimeOfDay? time = await showTimePicker(
        context: context,
        // 💡 CORRECCIÓN: Usar la hora inicial ajustada para hoy.
        initialTime: initialTime,
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
        final DateTime newDueDate = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        // 💡 VERIFICACIÓN FINAL: Asegurarse de que el momento combinado no sea pasado.
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

  Future<void> _updateTask() async {
    // 💡 1. Evitar la doble pulsación y la doble navegación
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _titleController.text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isSaving = false; // Re-habilitar si falla la validación inicial
        });
      }
      return;
    }

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

      // 💡 Si todo es correcto, salimos.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // 💡 Si hay un error, mostramos mensaje y re-habilitamos el botón.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));

        setState(() {
          _isSaving = false; // 💡 Re-habilitar el botón
        });
      }
    }
    // NOTA: No es necesario poner _isSaving = false; aquí,
    // ya que en caso de éxito, la pantalla se cierra con Navigator.pop(context);
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
                  // 💡 CORRECCIÓN: Deshabilitar el botón si _isSaving es true
                  onPressed: _isSaving ? null : _updateTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    // Opcional: Cambiar el color si está deshabilitado
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    // Opcional: Mostrar un indicador de carga
                    _isSaving ? 'GUARDANDO...' : 'GUARDAR CAMBIOS',
                    style: const TextStyle(
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
