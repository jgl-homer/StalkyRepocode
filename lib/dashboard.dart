import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'add_task_page.dart' as addPage;
import 'edit_task_page.dart' as editPage;
import 'profile.dart';
import 'agenda_page.dart';
import 'stats_page.dart';
import 'pomodoro_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  // Colors
  final Color _bg = const Color(0xFF000000);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _cardBg = const Color(0xFF1E1E1E);

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
        SnackBar(content: const Text('Tarea eliminada con éxito', style: TextStyle(color: Colors.black)), backgroundColor: _gold),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: _gold.withOpacity(0.5)),
          const SizedBox(height: 20),
          const Text(
            'Todo al día',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'No tienes tareas pendientes.\n¡Disfruta tu tiempo libre!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isPastOrToday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);
    return compareDate.isBefore(today) || compareDate.isAtSameMomentAs(today);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Usuario no autenticado', style: TextStyle(color: Colors.white))));
    }

    final screens = [
      _buildHomePage(user),
      const AgendaPage(),
      const StatsPage(),
      const ProfilePage()
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: screens[_selectedIndex]),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const addPage.AddTaskPage()),
                ).then((_) => setState(() {}));
              },
              backgroundColor: _gold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, color: Colors.black, size: 32),
            )
          : null,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: _bg,
          selectedItemColor: _gold,
          unselectedItemColor: Colors.grey.shade600,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Agenda'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Stats'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Ajustes'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage(User user) {
    final tasksStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .where('completed', isEqualTo: false) // Only show pending tasks
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: tasksStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _gold));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final tasks = snapshot.data?.docs ?? [];
        final totalTasks = tasks.length;

        // Grouping
        final List<QueryDocumentSnapshot> hoyTasks = [];
        final List<QueryDocumentSnapshot> proxTasks = [];

        for (var doc in tasks) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['dueDate'] != null && data['dueDate'] is Timestamp) {
            final date = (data['dueDate'] as Timestamp).toDate();
            if (_isPastOrToday(date)) {
              hoyTasks.add(doc);
            } else {
              proxTasks.add(doc);
            }
          } else {
            // No due date goes to upcoming
            proxTasks.add(doc);
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
                        builder: (context, userSnapshot) {
                          String name = user.displayName?.split(' ').first ?? 'Usuario';
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final data = userSnapshot.data!.data() as Map<String, dynamic>?;
                            if (data != null && data['name'] != null && data['name'].toString().trim().isNotEmpty) {
                              name = data['name'].toString().trim().split(' ').first;
                            }
                          }
                          return Text(
                            'Hola, $name',
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$totalTasks TAREAS PENDIENTES',
                        style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                  Image.asset(
                    'assets/logo/icon.png',
                    height: 64,
                    width: 64,
                    errorBuilder: (_, __, ___) => Icon(Icons.star, color: _gold, size: 32),
                  ),
                ],
              ),
              Expanded(
                child: totalTasks == 0
                    ? _buildEmptyState()
                    : ListView(
                        children: [
                          if (hoyTasks.isNotEmpty) ...[
                            _buildSectionHeader('Hoy', hoyTasks.length),
                            const SizedBox(height: 10),
                            ...hoyTasks.map((doc) => _buildTaskCard(doc)),
                            const SizedBox(height: 20),
                          ],
                          if (proxTasks.isNotEmpty) ...[
                            _buildSectionHeader('Próximamente', proxTasks.length),
                            const SizedBox(height: 10),
                            ...proxTasks.map((doc) => _buildTaskCard(doc)),
                            const SizedBox(height: 80), // Padding for FAB
                          ]
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(QueryDocumentSnapshot doc) {
    final task = doc.data() as Map<String, dynamic>;
    final docId = doc.id;
    final title = task['title'] ?? 'Sin título';
    final materia = task['materia'] ?? 'General';
    final bool isCompleted = task['completed'] ?? false;
    final String description = (task['description'] ?? '').toString().trim();
    final String priority = task['priority'] ?? 'media';
    final List subtasks = (task['subtasks'] as List?) ?? [];
    final int subtasksDone = subtasks.where((s) => s['completed'] == true).length;

    Color categoryColor = _gold;
    if (materia.toLowerCase().contains('escuela')) categoryColor = Colors.blueAccent;
    else if (materia.toLowerCase().contains('trabajo')) categoryColor = Colors.orangeAccent;
    else if (materia.toLowerCase().contains('pagos')) categoryColor = Colors.redAccent;
    else if (materia.toLowerCase().contains('personal')) categoryColor = Colors.greenAccent;

    String timeStr = '';
    if (task['dueDate'] != null && task['dueDate'] is Timestamp) {
      final d = (task['dueDate'] as Timestamp).toDate();
      if (d.year != 3000) timeStr = DateFormat('h:mm a').format(d);
    }

    Color priorityColor;
    String priorityLabel;
    switch (priority) {
      case 'alta': priorityColor = Colors.redAccent;  priorityLabel = 'ALTA';  break;
      case 'baja': priorityColor = Colors.greenAccent; priorityLabel = 'BAJA'; break;
      default:     priorityColor = _gold;              priorityLabel = 'MEDIA';
    }

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteTask(docId),
      child: GestureDetector(
        onTap: () => _editTask(docId, task),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: categoryColor, width: 3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Completion circle
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: GestureDetector(
                  onTap: () => _toggleTaskCompleted(docId, isCompleted),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _gold, width: 2),
                      color: isCompleted ? _gold : Colors.transparent,
                    ),
                    child: isCompleted ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + priority badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: priorityColor.withValues(alpha: 0.4), width: 1),
                          ),
                          child: Text(
                            priorityLabel,
                            style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    // Description preview
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Category · time · subtasks
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: categoryColor),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            materia,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.access_time, color: Colors.white54, size: 12),
                          const SizedBox(width: 3),
                          Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                        if (subtasks.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.checklist_rounded, color: Colors.white38, size: 13),
                          const SizedBox(width: 3),
                          Text('$subtasksDone/${subtasks.length}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Pomodoro button
              if (!isCompleted)
                GestureDetector(
                  onTap: () => _startPomodoro(context, title),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4, top: 2),
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white38, size: 24),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}