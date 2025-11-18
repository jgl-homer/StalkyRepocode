// Archivo: lib/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:diacritic/diacritic.dart';

import 'add_task_page.dart' as addPage;
import 'edit_task_page.dart' as editPage;
import 'profile.dart';
import 'pending_tasks_page.dart';
import 'pomodoro_page.dart';

// --- COLORES CYBERPUNK ---
const Color _primaryGold = Color(0xFFFFD700);
const Color _accentCyan = Colors.cyanAccent;
// -------------------------

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    
    // Opcional: Mostrar el tutorial automáticamente la primera vez
    // (Requeriría SharedPreferences, por ahora lo dejamos manual en el botón ?)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _showHelpDialog(); // Descomenta si quieres que salga al iniciar siempre
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Shader _tornasolGradient(Rect bounds) {
    return LinearGradient(
      colors: const [Color(0xFFFFD700), Color(0xFFB300FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: GradientRotation(_controller.value * 2 * pi),
    ).createShader(bounds);
  }

  // --- LÓGICA (Delete, Edit, Toggle, Pomodoro) ---
  Future<void> _deleteTask(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea eliminada con éxito')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _editTask(String docId, Map<String, dynamic> currentTaskData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => editPage.EditTaskPage(
          taskId: docId,
          initialData: currentTaskData,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Future<void> _toggleTaskCompleted(String docId, bool currentStatus) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(docId)
          .update({'completed': !currentStatus});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _startPomodoro(BuildContext navContext, String taskTitle) {
    Navigator.push(
      navContext,
      MaterialPageRoute(
        builder: (context) => PomodoroPage(taskTitle: taskTitle),
      ),
    );
  }

  // ⬇️ NUEVA FUNCIÓN: Diálogo de Ayuda / Tutorial
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Guía Rápida', style: TextStyle(color: _accentCyan)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpItem(Icons.add_circle, 'Botón +', 'Crea una nueva tarea.'),
              _buildHelpItem(Icons.check_box, 'Checkbox', 'Marca una tarea como completada.'),
              _buildHelpItem(Icons.play_circle_outline, 'Play', 'Inicia el modo concentración (Pomodoro).'),
              _buildHelpItem(Icons.delete, 'Borrar', 'Desliza una tarea hacia la izquierda para eliminarla.'),
              _buildHelpItem(Icons.filter_list, 'Filtro', 'En "Pendientes", usa el filtro superior para ver por materia.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('¡Entendido!', style: TextStyle(color: _primaryGold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: Estado Vacío Mejorado ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.rocket_launch, size: 80, color: Colors.white12),
          const SizedBox(height: 20),
          const Text(
            '¡Tu misión comienza aquí!',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'No tienes tareas asignadas.\nToca el botón para empezar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 40),
          // Flecha señalando al FAB
          const Icon(Icons.arrow_downward, color: _accentCyan, size: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Usuario no autenticado', style: TextStyle(color: Colors.white))));
    }

    final screens = [
      _buildAllTasksPage(user), 
      PendingTasksPage(        
        user: user,
        deleteTask: _deleteTask,
        editTask: _editTask,
        toggleTaskCompleted: _toggleTaskCompleted,
        tornasolGradient: _tornasolGradient,
      ),
      const ProfilePage()        
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: ShaderMask(
              shaderCallback: (bounds) => _tornasolGradient(bounds),
              child: const Text(
                'Taskify',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
              ),
            ),
            backgroundColor: Colors.black,
            actions: [
              // ⬇️ Botón de Ayuda
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.white70),
                onPressed: _showHelpDialog,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: Image.asset('assets/logo/icon.png', height: 32, width: 32),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.35,
                  child: Center(
                    child: Image.asset(
                      'assets/logo/icon.png',
                      fit: BoxFit.contain,
                      width: MediaQuery.of(context).size.width * 0.8,
                    ),
                  ),
                ),
              ),
              screens[_selectedIndex],
            ],
          ),
          floatingActionButton: _selectedIndex < 2 
              ? AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return FloatingActionButton(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const addPage.AddTaskPage()),
                        ).then((_) => setState(() {}));
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: const [Color(0xFFFFD700), Color(0xFFB300FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            transform: GradientRotation(_controller.value * 2 * pi),
                          ),
                        ),
                        child: const Center(child: Icon(Icons.add, size: 36, color: Colors.black)),
                      ),
                    );
                  },
                )
              : null,
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: Colors.black,
            selectedItemColor: const Color(0xFFFFD700),
            unselectedItemColor: Colors.white70,
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: [
              BottomNavigationBarItem(
                icon: ShaderMask(shaderCallback: (bounds) => _tornasolGradient(bounds), child: const Icon(Icons.list_alt, color: Colors.white)),
                label: 'Todas',
              ),
              BottomNavigationBarItem(
                icon: ShaderMask(shaderCallback: (bounds) => _tornasolGradient(bounds), child: const Icon(Icons.checklist, color: Colors.white)),
                label: 'Pendientes',
              ),
              BottomNavigationBarItem(
                icon: ShaderMask(shaderCallback: (bounds) => _tornasolGradient(bounds), child: const Icon(Icons.person, color: Colors.white)),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllTasksPage(User user) {
    final tasksStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .orderBy('completed') 
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
                'Error: ${snapshot.error}\n\n⚠️ Copia este link para crear índice (Todas):',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // ⬇️ AQUI SE USA EL NUEVO ESTADO VACÍO
          return _buildEmptyState(); 
        }

        // --- AGRUPACIÓN POR MATERIA ---
        final tasks = snapshot.data!.docs;
        final Map<String, List<QueryDocumentSnapshot>> groupedTasks = {};

        for (var doc in tasks) {
          final taskData = doc.data() as Map<String, dynamic>? ?? {};
          final String rawMateria = taskData['materia'] ?? 'General';
          final String materiaKey = removeDiacritics(rawMateria.trim().toLowerCase());
          if (groupedTasks[materiaKey] == null) groupedTasks[materiaKey] = [];
          groupedTasks[materiaKey]!.add(doc);
        }
        final sortedMaterias = groupedTasks.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sortedMaterias.length,
          itemBuilder: (context, index) {
            final materiaKey = sortedMaterias[index];
            final tasksInMateria = groupedTasks[materiaKey]!
              ..sort((a, b) {
                bool aCompleted = (a.data() as Map<String, dynamic>? ?? {})['completed'] ?? false;
                bool bCompleted = (b.data() as Map<String, dynamic>? ?? {})['completed'] ?? false;
                return aCompleted ? 1 : (bCompleted ? -1 : 0); 
              });

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
                    if (dueDate.year == 3000) {
                      dueDate = null; 
                    } else {
                      dueDateFormatted = DateFormat('dd/MM/yyyy h:mm a').format(dueDate);
                      if (dueDate.isBefore(DateTime.now()) && !isCompleted) {
                        isOverdue = true;
                      }
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
                  final double cardOpacity = isCompleted ? 0.4 : 1.0;
                  final Color cardShadow = isCompleted ? Colors.transparent : Colors.purpleAccent.withOpacity(0.4);
                  final TextDecoration titleDecoration = isCompleted ? TextDecoration.lineThrough : TextDecoration.none;
                  final Color titleColor = isCompleted ? Colors.white54 : Colors.white;

                  return Opacity(
                    opacity: cardOpacity,
                    child: Dismissible(
                      key: Key(docId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                         return await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: Colors.black87,
                                  title: ShaderMask(
                                    shaderCallback: (bounds) => _tornasolGradient(bounds),
                                    child: const Text("Confirmar Eliminación", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  content: Text("¿Deseas eliminar la tarea: $title?", style: const TextStyle(color: Colors.white70)),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text("Cancelar", style: TextStyle(color: Colors.white70)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text("Eliminar", style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                );
                              },
                            );
                      },
                      onDismissed: (direction) => _deleteTask(docId),
                      child: Card(
                        color: Colors.black54,
                        shadowColor: cardShadow,
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 4, color: isCompleted ? Colors.grey.shade800 : cardBorderColor),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          onTap: () => _editTask(docId, task),
                          leading: Checkbox(
                            value: isCompleted,
                            onChanged: (bool? value) {
                              _toggleTaskCompleted(docId, isCompleted);
                            },
                            checkColor: Colors.black,
                            activeColor: _accentCyan, 
                            side: const BorderSide(color: Colors.white70),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold, decoration: titleDecoration),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Materia: $materia',
                                style: TextStyle(color: isCompleted ? Colors.cyan.withOpacity(0.5) : Colors.cyan, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              if (hasDescription)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    description!,
                                    style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              dueDate != null
                                  ? Text(
                                      isOverdue ? 'VENCIDA: $dueDateFormatted' : 'Vence: $dueDateFormatted',
                                      style: TextStyle(
                                        color: isOverdue ? Colors.redAccent : Colors.white70,
                                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    )
                                  : const Text('Sin fecha', style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                          trailing: Wrap(
                            spacing: 0,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (!isCompleted)
                                IconButton(
                                  icon: const Icon(Icons.play_circle_outline, color: _accentCyan),
                                  onPressed: () => _startPomodoro(context, title),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              if (hasSubtasks)
                                Text('($completedCount/$totalCount)', style: TextStyle(color: isCompleted ? Colors.white54 : Colors.white70, fontSize: 14)),
                              Text(
                                priority.toUpperCase(),
                                style: TextStyle(color: isCompleted ? priorityColor.withOpacity(0.5) : priorityColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}