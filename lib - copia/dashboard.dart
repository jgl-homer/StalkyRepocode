// Archivo: lib/dashboard_page.dart (Diseño: Tornasol, Lógica: Agrupación por Materia)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';
// Importación de lógica para agrupación por materia
import 'package:diacritic/diacritic.dart';

// Importaciones con alias para evitar conflicto de nombres
import 'add_task_page.dart' as addPage;
import 'edit_task_page.dart' as editPage;
import 'profile.dart';

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🎨 Gradiente tornasol dorado-morado (animado)
  Shader _tornasolGradient(Rect bounds) {
    return LinearGradient(
      colors: const [Color(0xFFFFD700), Color(0xFFB300FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: GradientRotation(_controller.value * 2 * pi),
    ).createShader(bounds);
  }

  // 🗑️ ELIMINAR TAREA
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  // 📝 EDITAR TAREA — usa el alias editPage
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Usuario no autenticado',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final screens = [_buildTasksPage(user), const ProfilePage()];

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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            backgroundColor: Colors.black,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: Image.asset(
                  'assets/logo/icon.png',
                  height: 32,
                  width: 32,
                ),
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
          floatingActionButton: _selectedIndex == 0
              ? AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return FloatingActionButton(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const addPage.AddTaskPage()),
                        ).then((_) => setState(() {}));
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: const [
                              Color(0xFFFFD700),
                              Color(0xFFB300FF)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            transform:
                                GradientRotation(_controller.value * 2 * pi),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add,
                            size: 36,
                            color: Colors.black,
                          ),
                        ),
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
                icon: ShaderMask(
                  shaderCallback: (bounds) => _tornasolGradient(bounds),
                  child: const Icon(Icons.list_alt, color: Colors.white),
                ),
                label: 'Mis Tareas',
              ),
              BottomNavigationBarItem(
                icon: ShaderMask(
                  shaderCallback: (bounds) => _tornasolGradient(bounds),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTasksPage(User user) {
    final tasksStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .orderBy('dueDate')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: tasksStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD700)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay tareas disponibles',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        // --- AGRUPACIÓN POR MATERIA ---
        final tasks = snapshot.data!.docs;
        final Map<String, List<QueryDocumentSnapshot>> groupedTasks = {};

        for (var doc in tasks) {
          final taskData = doc.data() as Map<String, dynamic>? ?? {};
          final String rawMateria = taskData['materia'] ?? 'General';
          final String materiaKey =
              removeDiacritics(rawMateria.trim().toLowerCase());

          if (groupedTasks[materiaKey] == null) {
            groupedTasks[materiaKey] = [];
          }
          groupedTasks[materiaKey]!.add(doc);
        }

        final sortedMaterias = groupedTasks.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sortedMaterias.length,
          itemBuilder: (context, index) {
            final materiaKey = sortedMaterias[index];
            final tasksInMateria = groupedTasks[materiaKey]!;

            String displayMateria =
                (tasksInMateria[0].data() as Map<String, dynamic>? ??
                        {})['materia'] ??
                    'General';
            if (displayMateria.isEmpty) displayMateria = 'General';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Text(
                    displayMateria.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...List.generate(tasksInMateria.length, (taskIndex) {
                  final doc = tasksInMateria[taskIndex];
                  final docId = doc.id;
                  final task = doc.data() as Map<String, dynamic>? ?? {};

                  final title = task['title'] ?? 'Sin título';
                  final priority = task['priority'] ?? 'media';
                  final materia = task['materia'] ?? 'General';

                  DateTime? dueDate;
                  String dueDateFormatted = '';
                  if (task['dueDate'] != null && task['dueDate'] is Timestamp) {
                    dueDate = (task['dueDate'] as Timestamp).toDate();
                    dueDateFormatted =
                        DateFormat('dd/MM/yyyy h:mm a').format(dueDate);
                  }

                  Color priorityColor;
                  switch (priority) {
                    case 'alta':
                      priorityColor = Colors.redAccent;
                      break;
                    case 'media':
                      priorityColor = const Color(0xFFFFD700);
                      break;
                    case 'baja':
                      priorityColor = Colors.greenAccent;
                      break;
                    default:
                      priorityColor = Colors.white;
                  }

                  return Dismissible(
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
                              shaderCallback: (bounds) =>
                                  _tornasolGradient(bounds),
                              child: const Text(
                                "Confirmar Eliminación",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            content: Text(
                              "¿Deseas eliminar la tarea: $title?",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text("Cancelar",
                                    style: TextStyle(color: Colors.white70)),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text(
                                  "Eliminar",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    onDismissed: (direction) => _deleteTask(docId),
                    child: Card(
                      color: Colors.black54,
                      shadowColor: Colors.purpleAccent.withOpacity(0.4),
                      elevation: 6,
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 6),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                          width: 4,
                          color: Color(0xFFFFD700),
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        onTap: () => _editTask(docId, task),
                        title: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Materia: $materia',
                              style: const TextStyle(
                                color: Colors.cyan,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            dueDate != null
                                ? Text(
                                    'Vence: $dueDateFormatted',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  )
                                : const Text(
                                    'Sin fecha',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                          ],
                        ),
                        trailing: Text(
                          priority.toUpperCase(),
                          style: TextStyle(
                            color: priorityColor,
                            fontWeight: FontWeight.bold,
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
