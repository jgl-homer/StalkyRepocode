// 📁 lib/pending_tasks_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:diacritic/diacritic.dart';
import 'edit_task_page.dart' as editPage;
import 'pomodoro_page.dart';

// --- COLORES CYBERPUNK ---
const Color _primaryGold = Color(0xFFFFD700);
const Color _accentCyan = Colors.cyanAccent;
// -------------------------

// --- Lista de Materias ---
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

class PendingTasksPage extends StatefulWidget {
  final User user;
  final Function(String) deleteTask;
  final Function(String, Map<String, dynamic>) editTask;
  final Function(String, bool) toggleTaskCompleted;
  final Function(Rect) tornasolGradient;

  const PendingTasksPage({
    super.key,
    required this.user,
    required this.deleteTask,
    required this.editTask,
    required this.toggleTaskCompleted,
    required this.tornasolGradient,
  });

  @override
  State<PendingTasksPage> createState() => _PendingTasksPageState();
}

class _PendingTasksPageState extends State<PendingTasksPage> {
  String _selectedMateriaFilter = 'Todas';
  late List<String> _filterList;

  @override
  void initState() {
    super.initState();
    _filterList = ['Todas', ...kMateriasList];
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

  Widget _buildFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedMateriaFilter,
        items: _filterList.map((String materia) {
          return DropdownMenuItem<String>(
            value: materia,
            child: Text(materia, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedMateriaFilter = newValue;
            });
          }
        },
        decoration: _getInputDecoration('Filtrar por Materia'),
        dropdownColor: Colors.grey[900],
        style: const TextStyle(color: Colors.white, fontSize: 16),
        isExpanded: true,
        icon: const Icon(Icons.filter_list, color: _primaryGold),
      ),
    );
  }

  void _startPomodoro(BuildContext navContext, String taskTitle) {
    Navigator.push(
      navContext,
      MaterialPageRoute(
        builder: (context) => PomodoroPage(taskTitle: taskTitle),
      ),
    );
  }

  // ⬇️ WIDGET: Estado Vacío (Copiado del Dashboard para consistencia)
  Widget _buildEmptyState(String message) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.white12),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.arrow_downward, color: _accentCyan, size: 40),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .collection('tasks')
        .where('completed', isEqualTo: false)
        .orderBy('dueDate')
        .snapshots();
    
    return StreamBuilder<QuerySnapshot>(
      stream: tasksStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SelectableText( 
                'Error: ${snapshot.error}\n\n⚠️ Copia este link para crear índice (Pendientes):',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        List<QueryDocumentSnapshot> allTasks = snapshot.data?.docs ?? [];

        if (allTasks.isEmpty) {
          return Column(
            children: [
              _buildFilterDropdown(), 
              _buildEmptyState('¡No tienes tareas pendientes!\nToca el botón para agregar una.'),
            ],
          );
        }

        final List<QueryDocumentSnapshot> filteredTasks;
        if (_selectedMateriaFilter == 'Todas') {
          filteredTasks = allTasks;
        } else {
          filteredTasks = allTasks.where((doc) {
            final taskData = doc.data() as Map<String, dynamic>? ?? {};
            return (taskData['materia'] ?? 'General') == _selectedMateriaFilter;
          }).toList();
        }

        if (filteredTasks.isEmpty) {
          return Column(
            children: [
              _buildFilterDropdown(),
              _buildEmptyState('No tienes pendientes en esta materia.'),
            ],
          );
        }

        // ... (Agrupación y Listado idéntico al Dashboard) ...
        final Map<String, List<QueryDocumentSnapshot>> groupedTasks = {};
        for (var doc in filteredTasks) {
          final taskData = doc.data() as Map<String, dynamic>? ?? {};
          final String rawMateria = taskData['materia'] ?? 'General';
          final String materiaKey = removeDiacritics(rawMateria.trim().toLowerCase());
          if (groupedTasks[materiaKey] == null) groupedTasks[materiaKey] = [];
          groupedTasks[materiaKey]!.add(doc);
        }
        final sortedMaterias = groupedTasks.keys.toList()..sort();

        return Column(
          children: [
            _buildFilterDropdown(), 
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: sortedMaterias.length,
                itemBuilder: (context, index) {
                  final materiaKey = sortedMaterias[index];
                  final tasksInMateria = groupedTasks[materiaKey]!;
                  String displayMateria = (tasksInMateria[0].data() as Map<String, dynamic>? ?? {})['materia'] ?? 'General';
                  if (displayMateria.isEmpty) displayMateria = 'General';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                        child: Text(
                          displayMateria.toUpperCase(),
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),
                      ...List.generate(tasksInMateria.length, (taskIndex) {
                        final doc = tasksInMateria[taskIndex];
                        final docId = doc.id;
                        final task = doc.data() as Map<String, dynamic>? ?? {};
                        // ... (Campos idénticos) ...
                        final title = task['title'] ?? 'Sin título';
                        final priority = task['priority'] ?? 'media';
                        final materia = task['materia'] ?? 'General';
                        final description = task['description'] as String?;
                        final bool hasDescription = description != null && description.isNotEmpty;
                        final bool isCompleted = task['completed'] ?? false;
                        final List<dynamic>? subtasks = task['subtasks'];
                        int completedCount = 0;
                        int totalCount = 0;
                        bool hasSubtasks = false;
                        if (subtasks != null && subtasks.isNotEmpty) {
                          hasSubtasks = true;
                          totalCount = subtasks.length;
                          completedCount = subtasks.where((s) => (s as Map)['completed'] == true).length;
                        }
                        DateTime? dueDate;
                        String dueDateFormatted = '';
                        bool isOverdue = false;
                        if (task['dueDate'] != null && task['dueDate'] is Timestamp) {
                          dueDate = (task['dueDate'] as Timestamp).toDate();
                          if (dueDate.year == 3000) { dueDate = null; } else {
                            dueDateFormatted = DateFormat('dd/MM/yyyy h:mm a').format(dueDate);
                            if (dueDate.isBefore(DateTime.now())) { isOverdue = true; }
                          }
                        }
                        Color priorityColor;
                        switch (priority) {
                          case 'alta': priorityColor = Colors.redAccent; break;
                          case 'media': priorityColor = const Color(0xFFFFD700); break;
                          case 'baja': priorityColor = Colors.greenAccent; break;
                          default: priorityColor = Colors.white;
                        }
                        final Color cardBorderColor = isOverdue ? Colors.redAccent : priorityColor;

                        return Dismissible(
                          key: Key(docId),
                          direction: DismissDirection.endToStart,
                          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20.0), child: const Icon(Icons.delete, color: Colors.white)),
                          confirmDismiss: (direction) async {
                             return await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: Colors.black87,
                                  title: ShaderMask(
                                    shaderCallback: (bounds) => widget.tornasolGradient(bounds),
                                    child: const Text("Confirmar Eliminación", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  content: Text("¿Deseas eliminar la tarea: $title?", style: const TextStyle(color: Colors.white70)),
                                  actions: <Widget>[
                                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar", style: TextStyle(color: Colors.white70))),
                                    TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Eliminar", style: TextStyle(color: Colors.redAccent))),
                                  ],
                                );
                              },
                            );
                          },
                          onDismissed: (direction) => widget.deleteTask(docId), 
                          child: Card(
                            color: Colors.black54,
                            shadowColor: Colors.purpleAccent.withOpacity(0.4),
                            elevation: 6,
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            shape: RoundedRectangleBorder(side: BorderSide(width: 4, color: cardBorderColor), borderRadius: BorderRadius.circular(18)),
                            child: ListTile(
                              onTap: () => widget.editTask(docId, task), 
                              leading: Checkbox(
                                value: isCompleted,
                                onChanged: (bool? value) { widget.toggleTaskCompleted(docId, isCompleted); },
                                checkColor: Colors.black,
                                activeColor: _accentCyan,
                                side: const BorderSide(color: Colors.white70),
                              ),
                              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Materia: $materia', style: const TextStyle(color: Colors.cyan, fontSize: 14, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  if (hasDescription) Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Text(description!, style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                  dueDate != null ? Text(isOverdue ? 'VENCIDA: $dueDateFormatted' : 'Vence: $dueDateFormatted', style: TextStyle(color: isOverdue ? Colors.redAccent : Colors.white70, fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal)) : const Text('Sin fecha', style: TextStyle(color: Colors.white70)),
                                  if (hasSubtasks) Padding(padding: const EdgeInsets.only(top: 8.0), child: LinearProgressIndicator(value: totalCount > 0 ? completedCount / totalCount : 0, backgroundColor: Colors.grey[800], valueColor: const AlwaysStoppedAnimation<Color>(_accentCyan))),
                                ],
                              ),
                              trailing: Wrap(
                                spacing: 0,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  IconButton(icon: const Icon(Icons.play_circle_outline, color: _accentCyan), onPressed: () => _startPomodoro(context, title), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                  if (hasSubtasks) Text('($completedCount/$totalCount)', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                  Text(priority.toUpperCase(), style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}