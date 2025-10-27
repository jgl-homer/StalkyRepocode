import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_task_page.dart';
import 'profile.dart';
import 'edit_task_page.dart';
import 'package:intl/intl.dart'; // Añadido para formato de fecha/hora

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  // 🗑️ FUNCIÓN PARA ELIMINAR TAREA EN FIRESTORE
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea eliminada con éxito')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  // 📝 FUNCIÓN PARA EDITAR TAREA (CONECTA CON EditTaskPage)
  void _editTask(String docId, Map<String, dynamic> currentTaskData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditTaskPage(taskId: docId, initialData: currentTaskData),
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Taskify'),
        backgroundColor: Colors.black,
        // 🚀 AÑADIR EL ÍCONO A LA DERECHA
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Image.asset(
              // Asegúrate de crear la carpeta assets/logo y el archivo
              'assets/logo/icon.png',
              height: 32,
              width: 32,
            ),
          ),
        ],
      ),
      body: screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              backgroundColor: Colors.cyanAccent,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddTaskPage()),
                ).then((_) => setState(() {}));
              },
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Mis Tareas',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  /// Página de tareas del usuario autenticado
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
            child: CircularProgressIndicator(color: Colors.cyanAccent),
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

        final tasks = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final docId = tasks[index].id;
            final task = tasks[index].data() as Map<String, dynamic>;
            final title = task['title'] ?? 'Sin título';
            final priority = task['priority'] ?? 'media';

            DateTime? dueDate;
            String dueDateFormatted = '';
            if (task['dueDate'] != null && task['dueDate'] is Timestamp) {
              dueDate = (task['dueDate'] as Timestamp).toDate();
              dueDateFormatted = DateFormat(
                'dd/MM/yyyy h:mm a',
              ).format(dueDate);
            }

            Color priorityColor;
            switch (priority) {
              case 'alta':
                priorityColor = Colors.redAccent;
                break;
              case 'media':
                priorityColor = Colors.orangeAccent;
                break;
              case 'baja':
                priorityColor = Colors.greenAccent;
                break;
              default:
                priorityColor = Colors.white;
            }

            // 🗑️ IMPLEMENTACIÓN DE DISMISSIBLE PARA ELIMINAR (SWIPE)
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
                      title: const Text("Confirmar Eliminación"),
                      content: Text(
                        "¿Estás seguro de que quieres eliminar la tarea: $title?",
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text("Cancelar"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text(
                            "Eliminar",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              onDismissed: (direction) {
                _deleteTask(docId);
              },
              child: Card(
                color: Colors.white10,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                  subtitle: dueDate != null
                      ? Text(
                          'Vence: $dueDateFormatted',
                          style: const TextStyle(color: Colors.white70),
                        )
                      : const Text(
                          'Sin fecha',
                          style: TextStyle(color: Colors.white70),
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
          },
        );
      },
    );
  }
}
