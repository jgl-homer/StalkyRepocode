import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'services/notification_service.dart';
import 'tutorial/tutorial_controller.dart';
import 'tutorial/tutorial_overlay.dart';
import 'tutorial/tutorial_step.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final NotificationService _notificationService = NotificationService();
  final GlobalKey _titleHelpKey = GlobalKey();
  final GlobalKey _categoryHelpKey = GlobalKey();
  final GlobalKey _dateHelpKey = GlobalKey();
  final GlobalKey _reminderHelpKey = GlobalKey();
  final GlobalKey _saveHelpKey = GlobalKey();
  late final TutorialController _helpController;

  final Color _bg = const Color(0xFF000000);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _cardBg = const Color(0xFF1E1E1E);

  String _selectedCategory = 'Trabajo';
  ReminderLevel _selectedReminderLevel = ReminderLevel.normal;
  final List<String> _categories = [
    'Escuela',
    'Trabajo',
    'Pagos',
    'Personal',
    'General'
  ];

  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _helpController = TutorialController(steps: _buildHelpSteps());
  }

  @override
  void dispose() {
    _helpController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<TutorialStep> _buildHelpSteps() {
    return [
      TutorialStep(
        id: 'task_title_help',
        title: 'Tarea',
        description:
            'Escribe lo que necesitas recordar. Puedes ponerlo corto, como "Entregar proyecto" o "Pagar inscripción".',
        targetKey: _titleHelpKey,
        spriteAsset: 'assets/stalky/stalky_pointing.png',
        stepNumber: 1,
      ),
      TutorialStep(
        id: 'task_category_help',
        title: 'Categoría',
        description:
            'Elige dónde pertenece para encontrarla rápido después: escuela, trabajo, pagos, personal o general.',
        targetKey: _categoryHelpKey,
        spriteAsset: 'assets/stalky/stalky_thinking.png',
        stepNumber: 2,
      ),
      TutorialStep(
        id: 'task_date_help',
        title: 'Fecha y hora',
        description:
            'Marca cuándo vence. Con esa hora puedo programar el recordatorio sin que tengas que estar pendiente.',
        targetKey: _dateHelpKey,
        spriteAsset: 'assets/stalky/stalky_reminder.png',
        stepNumber: 3,
      ),
      TutorialStep(
        id: 'task_reminder_help',
        title: 'Recordatorio',
        description:
            'Escoge qué tanto quieres que te avise. Normal es tranquilo; urgente avisa con más anticipación.',
        targetKey: _reminderHelpKey,
        spriteAsset: 'assets/stalky/stalky_alert.png',
        stepNumber: 4,
      ),
      TutorialStep(
        id: 'task_save_help',
        title: 'Guardar',
        description:
            'Cuando todo esté listo, guarda el recordatorio y yo me encargo de acompañarlo en tu lista.',
        targetKey: _saveHelpKey,
        spriteAsset: 'assets/stalky/stalky_success.png',
        stepNumber: 5,
      ),
    ];
  }

  void _startHelpTutorial() {
    _helpController.startTutorial();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime.isBefore(now) ? now : _selectedDateTime,
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

    setState(() {
      _selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
  }

  Future<void> _selectTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
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

    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  void _showPastDateError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'La fecha y hora no pueden estar en el pasado.',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: _gold,
      ),
    );
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

    final finalDueDate = _selectedDateTime;
    if (!finalDueDate.isAfter(DateTime.now())) {
      _showPastDateError();
      return;
    }

    setState(() => _isSaving = true);
    final String description = _descriptionController.text.trim();
    var shouldShowFirstTaskTip = false;

    final newTask = {
      'title': title,
      'materia': _selectedCategory,
      'description': description,
      'priority': 'media', // Defaulting to media for STAKLY simple flow
      'dueDate': Timestamp.fromDate(finalDueDate),
      'createdAt': Timestamp.now(),
      'completed': false,
      'reminderLevel': _selectedReminderLevel.firestoreValue,
      'subtasks':
          [], // Subtasks hidden for simpler STAKLY flow, but kept in DB struct
    };

    try {
      final tasksCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks');
      final previousTasks = await tasksCollection.limit(1).get();
      shouldShowFirstTaskTip = previousTasks.docs.isEmpty;

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .add(newTask);

      // Notification scheduling
      if (finalDueDate.isAfter(DateTime.now())) {
        await _notificationService.scheduleTaskReminders(
          userId: user.uid,
          taskId: docRef.id,
          title: title,
          dueDate: finalDueDate,
          level: _selectedReminderLevel,
        );
      }

      if (mounted) Navigator.pop(context, shouldShowFirstTaskTip);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            title: const Text('Crear Recordatorio',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: _bg,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                tooltip: 'Ayuda',
                onPressed: _startHelpTutorial,
                icon: Icon(Icons.help_outline_rounded, color: _gold),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Image.asset(
                  'assets/logo/icon.png',
                  height: 40,
                  width: 40,
                  errorBuilder: (_, __, ___) => Icon(Icons.star, color: _gold),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextField(
                  key: _titleHelpKey,
                  controller: _titleController,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '¿Qué necesitas hacer?',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 20),

                // Category
                const Text('Categoría',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  key: _categoryHelpKey,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = category);
                            }
                          },
                          backgroundColor: _cardBg,
                          selectedColor: _gold,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          side: BorderSide.none,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 30),

                // Date
                const Text('Fecha',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _PickerField(
                  key: _dateHelpKey,
                  icon: Icons.calendar_month,
                  label: DateFormat('dd/MM/yyyy').format(_selectedDateTime),
                  onTap: _selectDate,
                  cardBg: _cardBg,
                  gold: _gold,
                ),
                const SizedBox(height: 30),

                // Time
                const Text('Hora',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _PickerField(
                  icon: Icons.schedule,
                  label: DateFormat('h:mm a').format(_selectedDateTime),
                  onTap: _selectTime,
                  cardBg: _cardBg,
                  gold: _gold,
                ),
                const SizedBox(height: 30),

                const Text('Tipo de recordatorio',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Column(
                  key: _reminderHelpKey,
                  children: ReminderLevel.values.map((level) {
                    final isSelected = _selectedReminderLevel == level;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedReminderLevel = level),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _gold.withValues(alpha: 0.14)
                                : _cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? _gold
                                  : _gold.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.notifications_active
                                    : Icons.notifications_none,
                                color: _gold,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  level.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),

                // Description
                const Text('Nota adicional (Opcional)',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Detalles...',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: _cardBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 50),

                // Submit Button
                SizedBox(
                  key: _saveHelpKey,
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            'Guardar Recordatorio',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        TutorialOverlay(controller: _helpController),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color cardBg;
  final Color gold;

  const _PickerField({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cardBg,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: gold, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: gold),
          ],
        ),
      ),
    );
  }
}
