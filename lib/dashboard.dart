import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'add_task_page.dart' as add_page;
import 'edit_task_page.dart' as edit_page;
import 'profile.dart';
import 'agenda_page.dart';
import 'stats_page.dart';
import 'pomodoro_page.dart';
import 'gemini_assistant_page.dart';
import 'services/ai_service.dart';
import 'services/notification_service.dart';
import 'tutorial/tutorial_controller.dart';
import 'tutorial/tutorial_overlay.dart';
import 'tutorial/tutorial_step.dart';
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
  final GlobalKey _scanNotesKey = GlobalKey();
  final GlobalKey _microphoneFabKey = GlobalKey();
  final GlobalKey _addTaskFabKey = GlobalKey();
  final GlobalKey _bottomNavigationKey = GlobalKey();
  final GlobalKey _agendaCalendarKey = GlobalKey();
  final GlobalKey _agendaEventsKey = GlobalKey();
  final GlobalKey _statsSummaryKey = GlobalKey();
  final GlobalKey _statsKpiKey = GlobalKey();
  final GlobalKey _settingsThemeKey = GlobalKey();
  late final TutorialController _tutorialController;
  bool _isVoiceListening = false;
  bool _isAiVoiceSaving = false;

  Color get _bg => Theme.of(context).colorScheme.surface;
  Color get _gold => Theme.of(context).colorScheme.primary;
  Color get _cardBg => Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _mutedTextColor =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

  @override
  void initState() {
    super.initState();
    _tutorialController = TutorialController(steps: _buildTutorialSteps());
    _tutorialController.addListener(_syncTutorialTab);
    _loadLocalTasks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (mounted) {
          _tutorialController.startTutorialIfNeeded();
        }
      });
    });
  }

  @override
  void dispose() {
    _tutorialController.removeListener(_syncTutorialTab);
    _tutorialController.dispose();
    _voiceController.dispose();
    super.dispose();
  }

  List<TutorialStep> _buildTutorialSteps() {
    return [
      const TutorialStep(
        id: 'welcome',
        title: 'Bienvenida',
        description:
            'Hola, soy Stalky. Te acompañaré en un recorrido rápido para que sepas dónde está cada función importante.',
        targetKey: null,
        spriteAsset: 'assets/stalky/stalky_welcome.png',
        stepNumber: 1,
        tabIndex: 0,
      ),
      TutorialStep(
        id: 'scan_notes',
        title: 'Escanea tus Apuntes',
        description:
            'Escanea tus apuntes o pizarrones y yo detectaré automáticamente tareas, fechas y actividades importantes.',
        targetKey: _scanNotesKey,
        spriteAsset: 'assets/stalky/stalky_thinking.png',
        stepNumber: 2,
        tabIndex: 0,
      ),
      TutorialStep(
        id: 'voice_button',
        title: 'Botón de micrófono',
        description:
            'Usa dictado por voz para crear tareas rápidamente sin escribir.',
        targetKey: _microphoneFabKey,
        spriteAsset: 'assets/stalky/stalky_reminder.png',
        stepNumber: 3,
        tabIndex: 0,
      ),
      TutorialStep(
        id: 'add_button',
        title: 'Botón +',
        description: 'Pulsa aquí para crear una nueva tarea manualmente.',
        targetKey: _addTaskFabKey,
        spriteAsset: 'assets/stalky/stalky_pointing.png',
        stepNumber: 4,
        tabIndex: 0,
      ),
      TutorialStep(
        id: 'bottom_navigation',
        title: 'Navegación',
        description:
            'Desde aquí puedes moverte entre Inicio, Agenda, Estadísticas y Ajustes.',
        targetKey: _bottomNavigationKey,
        spriteAsset: 'assets/stalky/stalky_pointing.png',
        stepNumber: 5,
      ),
      TutorialStep(
        id: 'agenda_calendar',
        title: 'Agenda',
        description:
            'Aquí ves tu calendario. Los días marcados te ayudan a ubicar tareas y actividades por fecha.',
        targetKey: _agendaCalendarKey,
        spriteAsset: 'assets/stalky/stalky_reminder.png',
        stepNumber: 6,
        tabIndex: 1,
      ),
      TutorialStep(
        id: 'agenda_events',
        title: 'Eventos del día',
        description:
            'En esta zona aparecen las tareas programadas para el día que selecciones en el calendario.',
        targetKey: _agendaEventsKey,
        spriteAsset: 'assets/stalky/stalky_pointing.png',
        stepNumber: 7,
        tabIndex: 1,
      ),
      TutorialStep(
        id: 'stats_summary',
        title: 'Estadísticas',
        description:
            'Aquí revisas tu avance general y tu productividad para saber cómo vas con tus tareas.',
        targetKey: _statsSummaryKey,
        spriteAsset: 'assets/stalky/stalky_analyzing.png',
        stepNumber: 8,
        tabIndex: 2,
      ),
      TutorialStep(
        id: 'stats_kpis',
        title: 'Indicadores rápidos',
        description:
            'Estos números resumen tus tareas totales, completadas, pendientes y productividad.',
        targetKey: _statsKpiKey,
        spriteAsset: 'assets/stalky/stalky_analyzing.png',
        stepNumber: 9,
        tabIndex: 2,
      ),
      TutorialStep(
        id: 'settings_theme',
        title: 'Ajustes',
        description:
            'Desde aquí puedes cambiar el tema de la app entre Sistema, Claro y Oscuro.',
        targetKey: _settingsThemeKey,
        spriteAsset: 'assets/stalky/stalky_thinking.png',
        stepNumber: 10,
        tabIndex: 3,
      ),
      const TutorialStep(
        id: 'success',
        title: 'Listo',
        description:
            '¡Perfecto! Ya conoces las funciones principales de Stalky. Ahora estás listo para comenzar.',
        targetKey: null,
        spriteAsset: 'assets/stalky/stalky_success.png',
        stepNumber: 11,
        tabIndex: 0,
      ),
    ];
  }

  void _syncTutorialTab() {
    final targetTab = _tutorialController.currentStep?.tabIndex;
    if (!_tutorialController.isActive ||
        targetTab == null ||
        targetTab == _selectedIndex) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || targetTab == _selectedIndex) return;
      setState(() => _selectedIndex = targetTab);
    });
  }

  void _startManualTutorial() {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tutorialController.startTutorial();
      }
    });
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
      debugPrint('Error al cargar tareas locales: $e');
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
              content: Text('Tarea local eliminada con éxito',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
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
      await NotificationService().cancelTaskNotifications(docId);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Tarea eliminada con éxito',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
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
        builder: (context) => edit_page.EditTaskPage(
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
        if (!currentStatus) {
          await NotificationService().cancelTaskNotifications(docId);
        }
        await _loadLocalTasks();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error local: $e')));
      }
      return;
    }

    try {
      final taskRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(docId);
      final nextStatus = !currentStatus;
      await taskRef.update({'completed': nextStatus});

      if (nextStatus) {
        await NotificationService().cancelTaskNotifications(docId);
      } else {
        final snapshot = await taskRef.get();
        final task = snapshot.data();
        if (task != null) {
          await NotificationService().rescheduleTaskReminderFromData(
            userId: user.uid,
            taskId: docId,
            task: task,
          );
        }
      }
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
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
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
                      Expanded(
                        child: Text(
                          'Dictado con IA',
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      VoiceDictationButton(
                        controller: _voiceController,
                        gold: _gold,
                        backgroundColor: _bg,
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
                    style: TextStyle(color: _textColor),
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText:
                          'Ej. Recuerdame entregar historia mañana a las 6 pm',
                      hintStyle: TextStyle(
                        color: _mutedTextColor.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: _bg,
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
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.bolt,
                              color: Theme.of(context).colorScheme.onPrimary),
                      label: Text(
                        _isVoiceListening
                            ? 'Escuchando...'
                            : _isAiVoiceSaving
                                ? 'Creando...'
                                : 'Guardar automatico con IA',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
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
              size: 80, color: _gold.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Text(
            'Todo al día',
            style: TextStyle(
                color: _textColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'No tienes tareas pendientes.\n¡Disfruta tu tiempo libre!',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedTextColor),
          ),
        ],
      ),
    );
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
      return Scaffold(
          body: Center(
              child: Text('Usuario no autenticado',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface))));
    }

    final screens = [
      _buildHomePage(user),
      AgendaPage(
        calendarTutorialKey: _agendaCalendarKey,
        eventsTutorialKey: _agendaEventsKey,
      ),
      StatsPage(
        summaryTutorialKey: _statsSummaryKey,
        kpiTutorialKey: _statsKpiKey,
      ),
      ProfilePage(themeTutorialKey: _settingsThemeKey),
    ];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: _bg,
          body: SafeArea(child: screens[_selectedIndex]),
          floatingActionButton: _selectedIndex == 0
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      key: _microphoneFabKey,
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
                      key: _addTaskFabKey,
                      heroTag: 'add_task_fab',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const add_page.AddTaskPage()),
                        ).then((_) => setState(() {}));
                      },
                      backgroundColor: _gold,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 32,
                      ),
                    ),
                  ],
                )
              : null,
          bottomNavigationBar: Container(
            key: _bottomNavigationKey,
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: BottomNavigationBar(
                backgroundColor: _bg,
                selectedItemColor: _gold,
                unselectedItemColor: _mutedTextColor,
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
          ),
        ),
        TutorialOverlay(controller: _tutorialController),
      ],
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
          debugPrint(
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
                            style: TextStyle(
                                color: _textColor,
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
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Ver tutorial',
                        onPressed: _startManualTutorial,
                        icon: Icon(Icons.help_outline_rounded, color: _gold),
                      ),
                      const SizedBox(width: 4),
                      Image.asset(
                        'assets/logo/icon.png',
                        height: 64,
                        width: 64,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.star, color: _gold, size: 32),
                      ),
                    ],
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
          style: TextStyle(
              color: _textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
                color: _mutedTextColor,
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
                        ? Icon(Icons.check,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimary)
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
                              color: _textColor,
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
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.4),
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
                        style: TextStyle(
                            color: _mutedTextColor.withValues(alpha: 0.65),
                            fontSize: 12),
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
                            style:
                                TextStyle(color: _mutedTextColor, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.access_time,
                              color: _mutedTextColor, size: 12),
                          const SizedBox(width: 3),
                          Text(timeStr,
                              style: TextStyle(
                                  color: _mutedTextColor, fontSize: 12)),
                        ],
                        if (subtasks.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.checklist_rounded,
                              color: _mutedTextColor.withValues(alpha: 0.65),
                              size: 13),
                          const SizedBox(width: 3),
                          Text('$subtasksDone/${subtasks.length}',
                              style: TextStyle(
                                  color:
                                      _mutedTextColor.withValues(alpha: 0.65),
                                  fontSize: 12)),
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
                  child: Padding(
                    padding: EdgeInsets.only(left: 4, top: 2),
                    child: Icon(Icons.play_arrow_rounded,
                        color: _mutedTextColor.withValues(alpha: 0.65),
                        size: 24),
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
      key: _scanNotesKey,
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
            color: const Color(0xFF673AB7).withValues(alpha: 0.3),
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
