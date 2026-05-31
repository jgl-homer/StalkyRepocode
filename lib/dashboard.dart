import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'add_task_page.dart' as addPage;
import 'edit_task_page.dart' as editPage;
import 'profile.dart';
import 'agenda_page.dart';
import 'stats_page.dart';
import 'pomodoro_page.dart';
import 'gemini_assistant_page.dart';
import 'services/ai_service.dart';
import 'widgets/voice_dictation_button.dart';

class UnifiedTask {
  final String id;
  final Map<String, dynamic> data;
  UnifiedTask({required this.id, required this.data});
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _localTasks = [];
  final TextEditingController _voiceController = TextEditingController();
  final AIService _aiService = AIService();
  bool _isVoiceListening = false;
  bool _isAiVoiceSaving = false;

  // Colors
  final Color _bg = const Color(0xFF000000);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _cardBg = const Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _loadLocalTasks();
  }

  @override
  void dispose() {
    _voiceController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'offline_tasks_${user.uid}';
      final list = prefs.getStringList(key) ?? [];
      final parsed =
          list.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
      final pending = parsed.where((t) => t['completed'] == false).toList();
      if (mounted) {
        setState(() {
          _localTasks = pending;
        });
      }
    } catch (e) {
      print('Error al cargar tareas locales: $e');
    }
  }

  Future<void> _deleteTask(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (docId.startsWith('local_')) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'offline_tasks_${user.uid}';
        final list = prefs.getStringList(key) ?? [];
        list.removeWhere((item) {
          final map = jsonDecode(item) as Map;
          return map['id'] == docId;
        });
        await prefs.setStringList(key, list);
        await _loadLocalTasks();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Tarea local eliminada con éxito',
                  style: TextStyle(color: Colors.black)),
              backgroundColor: _gold),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error local: $e')));
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Tarea eliminada con éxito',
                style: TextStyle(color: Colors.black)),
            backgroundColor: _gold),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _editTask(String docId, Map<String, dynamic> currentTaskData) {
    if (docId.startsWith('local_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Las tareas guardadas localmente no se pueden editar en modo offline.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => editPage.EditTaskPage(
          taskId: docId,
          initialData: currentTaskData,
        ),
      ),
    ).then((_) => _loadLocalTasks());
  }

  Future<void> _toggleTaskCompleted(String docId, bool currentStatus) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (docId.startsWith('local_')) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'offline_tasks_${user.uid}';
        final list = prefs.getStringList(key) ?? [];
        final updatedList = list.map((item) {
          final map = jsonDecode(item) as Map<String, dynamic>;
          if (map['id'] == docId) {
            map['completed'] = !currentStatus;
          }
          return jsonEncode(map);
        }).toList();
        await prefs.setStringList(key, updatedList);
        await _loadLocalTasks();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error local: $e')));
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(docId)
          .update({'completed': !currentStatus});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
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

  void _showGoldSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.black)),
        backgroundColor: _gold,
      ),
    );
  }

  Future<void> _saveVoiceReminder(
    StateSetter setSheetState,
    BuildContext sheetContext,
  ) async {
    if (_isAiVoiceSaving || _isVoiceListening) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final transcript = _voiceController.text.trim();
    if (transcript.isEmpty) {
      _showGoldSnack('Dicta el recordatorio antes de guardarlo con IA.');
      return;
    }

    setState(() => _isAiVoiceSaving = true);
    setSheetState(() {});

    try {
      await _aiService.processVoiceReminder(
        transcript: transcript,
        userId: user.uid,
      );

      if (!mounted || !sheetContext.mounted) return;
      Navigator.of(sheetContext).pop();
      _voiceController.clear();
      setState(() => _isAiVoiceSaving = false);
      await _loadLocalTasks();
      _showGoldSnack('Recordatorio creado por dictado con IA.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAiVoiceSaving = false);
      setSheetState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _openVoiceReminderSheet() {
    _voiceController.clear();
    setState(() {
      _isVoiceListening = false;
      _isAiVoiceSaving = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: _gold.withValues(alpha: 0.45)),
                        ),
                        child: Icon(Icons.auto_awesome, color: _gold),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Dictado con IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      VoiceDictationButton(
                        controller: _voiceController,
                        gold: _gold,
                        backgroundColor: Colors.black,
                        tooltip: 'Dictar recordatorio',
                        onTextChanged: (_) => setSheetState(() {}),
                        onListeningChanged: (listening) {
                          setState(() => _isVoiceListening = listening);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _voiceController,
                    enabled: !_isAiVoiceSaving,
                    style: const TextStyle(color: Colors.white),
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText:
                          'Ej. Recuerdame entregar historia mañana a las 6 pm',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _gold, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isAiVoiceSaving || _isVoiceListening
                          ? null
                          : () =>
                              _saveVoiceReminder(setSheetState, sheetContext),
                      icon: _isAiVoiceSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.bolt, color: Colors.black),
                      label: Text(
                        _isVoiceListening
                            ? 'Escuchando...'
                            : _isAiVoiceSaving
                                ? 'Creando...'
                                : 'Guardar automatico con IA',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        disabledBackgroundColor: _gold.withValues(alpha: 0.55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isVoiceListening = false;
          _isAiVoiceSaving = false;
        });
      }
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 80, color: _gold.withOpacity(0.5)),
          const SizedBox(height: 20),
          const Text(
            'Todo al día',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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
      return const Scaffold(
          body: Center(
              child: Text('Usuario no autenticado',
                  style: TextStyle(color: Colors.white))));
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
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'voice_reminder_fab',
                  onPressed: _openVoiceReminderSheet,
                  backgroundColor: _cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _gold.withValues(alpha: 0.65)),
                  ),
                  child: Icon(Icons.mic_none_rounded, color: _gold),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'add_task_fab',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const addPage.AddTaskPage()),
                    ).then((_) => setState(() {}));
                  },
                  backgroundColor: _gold,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.add, color: Colors.black, size: 32),
                ),
              ],
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
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: Icon(Icons.calendar_today),
                label: 'Agenda'),
            BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Stats'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Ajustes'),
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
          print(
              '[DASHBOARD] [FIRESTORE_READ_ERROR] Error al leer tareas de Firestore: ${snapshot.error}');
        }

        final firestoreDocs = snapshot.data?.docs ?? [];

        // Unificar tareas locales y de Firestore
        final List<UnifiedTask> allTasks = [];
        for (var doc in firestoreDocs) {
          allTasks.add(UnifiedTask(
              id: doc.id, data: doc.data() as Map<String, dynamic>));
        }
        for (var localT in _localTasks) {
          allTasks.add(UnifiedTask(id: localT['id'].toString(), data: localT));
        }

        final totalTasks = allTasks.length;

        // Grouping
        final List<UnifiedTask> hoyTasks = [];
        final List<UnifiedTask> proxTasks = [];

        for (var ut in allTasks) {
          final data = ut.data;
          DateTime? date;
          if (data['dueDate'] != null) {
            if (data['dueDate'] is Timestamp) {
              date = (data['dueDate'] as Timestamp).toDate();
            } else if (data['dueDate'] is String) {
              date = DateTime.tryParse(data['dueDate']);
            }
          }

          if (date != null) {
            if (_isPastOrToday(date)) {
              hoyTasks.add(ut);
            } else {
              proxTasks.add(ut);
            }
          } else {
            // No due date goes to upcoming
            proxTasks.add(ut);
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
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .get(),
                        builder: (context, userSnapshot) {
                          String name =
                              user.displayName?.split(' ').first ?? 'Usuario';
                          if (userSnapshot.hasData &&
                              userSnapshot.data!.exists) {
                            final data = userSnapshot.data!.data()
                                as Map<String, dynamic>?;
                            if (data != null &&
                                data['name'] != null &&
                                data['name'].toString().trim().isNotEmpty) {
                              name = data['name']
                                  .toString()
                                  .trim()
                                  .split(' ')
                                  .first;
                            }
                          }
                          return Text(
                            'Hola, $name',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$totalTasks TAREAS PENDIENTES',
                        style: TextStyle(
                            color: _gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2),
                      ),
                    ],
                  ),
                  Image.asset(
                    'assets/logo/icon.png',
                    height: 64,
                    width: 64,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.star, color: _gold, size: 32),
                  ),
                ],
              ),
              _buildAIBanner(),
              Expanded(
                child: totalTasks == 0
                    ? _buildEmptyState()
                    : ListView(
                        children: [
                          if (hoyTasks.isNotEmpty) ...[
                            _buildSectionHeader('Hoy', hoyTasks.length),
                            const SizedBox(height: 10),
                            ...hoyTasks
                                .map((ut) => _buildTaskCard(ut.id, ut.data)),
                            const SizedBox(height: 20),
                          ],
                          if (proxTasks.isNotEmpty) ...[
                            _buildSectionHeader(
                                'Próximamente', proxTasks.length),
                            const SizedBox(height: 10),
                            ...proxTasks
                                .map((ut) => _buildTaskCard(ut.id, ut.data)),
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
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(String docId, Map<String, dynamic> task) {
    final title = task['title'] ?? 'Sin título';
    final materia = task['materia'] ?? 'General';
    final bool isCompleted = task['completed'] ?? false;
    final String description = (task['description'] ?? '').toString().trim();
    final String priority = task['priority'] ?? 'media';
    final List subtasks = (task['subtasks'] as List?) ?? [];
    final int subtasksDone =
        subtasks.where((s) => s['completed'] == true).length;

    Color categoryColor = _gold;
    if (materia.toLowerCase().contains('escuela')) {
      categoryColor = Colors.blueAccent;
    } else if (materia.toLowerCase().contains('trabajo')) {
      categoryColor = Colors.orangeAccent;
    } else if (materia.toLowerCase().contains('pagos')) {
      categoryColor = Colors.redAccent;
    } else if (materia.toLowerCase().contains('personal')) {
      categoryColor = Colors.greenAccent;
    }

    String timeStr = '';
    if (task['dueDate'] != null) {
      DateTime? d;
      if (task['dueDate'] is Timestamp) {
        d = (task['dueDate'] as Timestamp).toDate();
      } else if (task['dueDate'] is String) {
        d = DateTime.tryParse(task['dueDate']);
      }
      if (d != null && d.year != 3000) {
        timeStr = DateFormat('h:mm a').format(d);
      }
    }

    Color priorityColor;
    String priorityLabel;
    switch (priority) {
      case 'alta':
        priorityColor = Colors.redAccent;
        priorityLabel = 'ALTA';
        break;
      case 'baja':
        priorityColor = Colors.greenAccent;
        priorityLabel = 'BAJA';
        break;
      default:
        priorityColor = _gold;
        priorityLabel = 'MEDIA';
    }

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
            color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
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
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.black)
                        : null,
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
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (task['isOffline'] == true) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.4),
                                  width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off,
                                    color: Colors.amber, size: 10),
                                SizedBox(width: 4),
                                Text(
                                  'LOCAL',
                                  style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: priorityColor.withValues(alpha: 0.4),
                                width: 1),
                          ),
                          child: Text(
                            priorityLabel,
                            style: TextStyle(
                                color: priorityColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    // Description preview
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
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
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: categoryColor),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            materia,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.access_time,
                              color: Colors.white54, size: 12),
                          const SizedBox(width: 3),
                          Text(timeStr,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                        if (subtasks.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.checklist_rounded,
                              color: Colors.white38, size: 13),
                          const SizedBox(width: 3),
                          Text('$subtasksDone/${subtasks.length}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
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
                    child: Icon(Icons.play_arrow_rounded,
                        color: Colors.white38, size: 24),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 15, bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3F51B5), // Deep purple-blue
            Color(0xFF673AB7), // Purple
            Color(0xFFD4AF37), // Accent Gold
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF673AB7).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const GeminiAssistantPage()),
            ).then((_) {
              _loadLocalTasks();
              setState(() {});
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.auto_awesome,
                                    color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'ASISTENTE IA',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Escanea tus Apuntes',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sube fotos de apuntes o pizarrones para crear tareas automáticamente.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
