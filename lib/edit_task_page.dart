import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
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
  final Color _bg = const Color(0xFF000000);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _cardBg = const Color(0xFF1E1E1E);

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  final TextEditingController _subtaskController = TextEditingController();

  String _selectedCategory = 'General';
  final List<String> _categories = ['Escuela', 'Trabajo', 'Pagos', 'Personal', 'General'];
  String _selectedPriority = 'media';
  DateTime? _selectedDueDate;
  bool _isSaving = false;
  List<Map<String, dynamic>> _subtasks = [];

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialData['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.initialData['description'] ?? '');

    final String rawMateria = widget.initialData['materia'] ?? 'General';
    _selectedCategory = _categories.contains(rawMateria) ? rawMateria : 'General';
    _selectedPriority = widget.initialData['priority'] ?? 'media';

    if (widget.initialData['dueDate'] != null && widget.initialData['dueDate'] is Timestamp) {
      final potentialDate = (widget.initialData['dueDate'] as Timestamp).toDate();
      if (potentialDate.year != 3000) _selectedDueDate = potentialDate;
    }

    if (widget.initialData['subtasks'] != null) {
      _subtasks = List<Map<String, dynamic>>.from(widget.initialData['subtasks']);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: _gold, onSurface: Colors.white, surface: _cardBg),
          dialogTheme: DialogThemeData(backgroundColor: _bg),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) {
      final TimeOfDay initial = _selectedDueDate != null
          ? TimeOfDay.fromDateTime(_selectedDueDate!)
          : TimeOfDay.now();
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: initial,
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: _gold, onSurface: Colors.white, surface: _cardBg),
            dialogTheme: DialogThemeData(backgroundColor: _bg),
          ),
          child: child!,
        ),
      );
      if (time != null) {
        final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        if (combined.isBefore(DateTime.now())) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('La fecha no puede ser en el pasado', style: TextStyle(color: Colors.black)),
              backgroundColor: _gold,
            ));
          }
          return;
        }
        setState(() => _selectedDueDate = combined);
      }
    }
  }

  Future<void> _updateTask() async {
    if (_isSaving) return;
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('El título no puede estar vacío', style: TextStyle(color: Colors.black)),
        backgroundColor: _gold,
      ));
      return;
    }
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _isSaving = false); return; }

    final dataToUpdate = {
      'title': title,
      'materia': _selectedCategory,
      'description': _descriptionController.text.trim(),
      'priority': _selectedPriority,
      'dueDate': _selectedDueDate != null
          ? Timestamp.fromDate(_selectedDueDate!)
          : Timestamp.fromDate(DateTime(3000)),
      'subtasks': _subtasks,
    };

    final int baseId = widget.taskId.hashCode.abs() % 1000000;
    try {
      for (int i = 0; i < 50; i++) {
        await _notificationService.cancelNotification(baseId + i);
      }
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('tasks').doc(widget.taskId)
          .update(dataToUpdate);
      if (_selectedDueDate != null && _selectedDueDate!.isAfter(DateTime.now())) {
        await _notificationService.scheduleNotification(
          baseId, 'Recordatorio: $title', '¡Es hora de completar tu tarea!', _selectedDueDate!);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  void _addSubtask() {
    final String t = _subtaskController.text.trim();
    if (t.isNotEmpty) {
      setState(() { _subtasks.add({'title': t, 'completed': false}); _subtaskController.clear(); });
    }
  }

  Color _priorityColor(String p) {
    if (p == 'alta') return Colors.redAccent;
    if (p == 'baja') return Colors.greenAccent;
    return _gold;
  }

  InputDecoration _inputDeco(String label, {String? hint}) => InputDecoration(
    labelText: label.isEmpty ? null : label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white70),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
    filled: true,
    fillColor: _cardBg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _gold, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Editar Tarea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
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
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
              decoration: InputDecoration(
                hintText: '¿Qué necesitas hacer?',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 22, fontWeight: FontWeight.bold),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 24),

            // Category chips
            const Text('Categoría', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (sel) { if (sel) setState(() => _selectedCategory = cat); },
                      backgroundColor: _cardBg,
                      selectedColor: _gold,
                      labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Priority
            const Text('Prioridad', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: ['baja', 'media', 'alta'].map((p) {
                final isSelected = _selectedPriority == p;
                final col = _priorityColor(p);
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPriority = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? col.withValues(alpha: 0.15) : _cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? col : Colors.transparent, width: 2),
                      ),
                      child: Text(
                        p.toUpperCase(),
                        style: TextStyle(color: isSelected ? col : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Date/Time
            const Text('Fecha y Hora', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: _selectedDueDate != null ? Border.all(color: _gold.withValues(alpha: 0.5), width: 1.5) : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, color: _gold, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDueDate != null
                          ? DateFormat('dd/MM/yyyy  h:mm a').format(_selectedDueDate!)
                          : 'Seleccionar fecha y hora',
                      style: TextStyle(color: _selectedDueDate != null ? Colors.white : Colors.white54, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (_selectedDueDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedDueDate = null),
                        child: const Icon(Icons.close, color: Colors.white38, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Description
            const Text('Nota adicional (Opcional)', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              maxLength: 500,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                  Text('$currentLength/$maxLength', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              decoration: _inputDeco('', hint: 'Detalles...'),
            ),
            const SizedBox(height: 24),

            // Subtasks
            const Text('Sub-tareas', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (_subtasks.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _subtasks.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, index) {
                    final sub = _subtasks[index];
                    final done = sub['completed'] ?? false;
                    return ListTile(
                      leading: GestureDetector(
                        onTap: () => setState(() => _subtasks[index]['completed'] = !done),
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _gold, width: 2), color: done ? _gold : Colors.transparent),
                          child: done ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
                        ),
                      ),
                      title: Text(sub['title'], style: TextStyle(color: done ? Colors.white38 : Colors.white, decoration: done ? TextDecoration.lineThrough : null)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: _cardBg,
                              title: const Text('¿Eliminar sub-tarea?', style: TextStyle(color: Colors.white)),
                              content: Text('Se borrará "${sub['title']}".', style: const TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
                              ],
                            ),
                          );
                          if (confirm == true) setState(() => _subtasks.removeAt(index));
                        },
                      ),
                    );
                  },
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskController,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _addSubtask(),
                    decoration: _inputDeco('', hint: 'Añadir sub-tarea...'),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addSubtask,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.add, color: Colors.black, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Actualizar Tarea', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}