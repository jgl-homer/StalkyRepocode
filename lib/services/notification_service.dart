import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;

import '../firebase_options.dart';

enum ReminderLevel {
  soft,
  normal,
  insistent,
}

extension ReminderLevelLabel on ReminderLevel {
  String get firestoreValue {
    switch (this) {
      case ReminderLevel.soft:
        return 'soft';
      case ReminderLevel.normal:
        return 'normal';
      case ReminderLevel.insistent:
        return 'insistent';
    }
  }

  String get label {
    switch (this) {
      case ReminderLevel.soft:
        return 'Recordatorio suave';
      case ReminderLevel.normal:
        return 'Recordatorio normal';
      case ReminderLevel.insistent:
        return 'Recordatorio insistente';
    }
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  await NotificationService.handleNotificationResponse(response);
}

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int _maxNotificationsPerTask = 8;
  static const String _taskGroupKey = 'com.taskingtech.stalky.TASK_REMINDERS';

  Future<void> initNotifications() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _initialized = true;
    await requestNotificationPermission();
  }

  Future<bool> requestNotificationPermission() async {
    if (!_isAndroid) return true;

    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final granted =
        await androidPlugin?.requestNotificationsPermission() ?? true;
    if (kDebugMode) {
      print('Permiso de notificaciones: $granted');
    }
    return granted;
  }

  Future<bool> canScheduleExactNotifications() async {
    if (!_isAndroid) return true;

    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    return await androidPlugin?.canScheduleExactNotifications() ?? true;
  }

  Future<bool> requestExactAlarmPermission() async {
    if (!_isAndroid) return true;

    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidPlugin?.requestExactAlarmsPermission() ?? true;
    if (kDebugMode) {
      print('Permiso de alarmas exactas: $granted');
    }
    return granted;
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (!_isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;

    if (await canScheduleExactNotifications()) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    final granted = await requestExactAlarmPermission();
    if (granted || await canScheduleExactNotifications()) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // Programa un recordatorio generico opcional. No se activa automaticamente.
  Future<void> scheduleConstantReminder() async {
    await initNotifications();

    const int constantReminderId = 999999; // ID único y fijo

    // Título y cuerpo genéricos para revisión de tareas:
    const String title = '⏰ Recordatorio Constante: Revisa tus Tareas';
    const String body =
        '¡Tienes tareas pendientes! Revisa tu lista y prioridades.';

    // 1. Cancelamos cualquier recordatorio constante anterior para evitar duplicados.
    await flutterLocalNotificationsPlugin.cancel(constantReminderId);

    // 2. Usamos periodicallyShow para la recurrencia (cada hora).
    await flutterLocalNotificationsPlugin.periodicallyShow(
      constantReminderId,
      title,
      body,
      RepeatInterval.hourly, // Repetición cada hora (60 minutos)
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'constant_reminder_channel_id',
          'Recordatorio Constante', // Nombre visible en ajustes de Android
          channelDescription:
              'Canal para el recordatorio constante de revisión de tareas.',
          importance: Importance.low,
          priority: Priority.low,
          ongoing:
              true, // Esto la hace PERSISTENTE en la barra de notificaciones
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _resolveAndroidScheduleMode(),
    );

    if (kDebugMode) {
      print('Recordatorio constante programado con ID: $constantReminderId');
    }
  }

  // 🚀 MÉTODO PRINCIPAL: Programa UNA SOLA Notificación para una Tarea (Específico)
  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
  ) async {
    await initNotifications();

    final notificationsGranted = await requestNotificationPermission();
    if (!notificationsGranted) {
      if (kDebugMode) {
        print('No se programo notificacion: permiso denegado.');
      }
      return;
    }

    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    final scheduleMode = await _resolveAndroidScheduleMode();

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel_id',
          'Recordatorios de Tareas',
          channelDescription:
              'Canal para las notificaciones programadas de tareas.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
    );
  }

  Future<void> scheduleTaskReminders({
    required String userId,
    required String taskId,
    required String title,
    required DateTime dueDate,
    required ReminderLevel level,
  }) async {
    await initNotifications();
    await cancelTaskNotifications(taskId);

    if (!dueDate.isAfter(DateTime.now())) return;

    final notificationsGranted = await requestNotificationPermission();
    if (!notificationsGranted) return;

    final scheduleMode = await _resolveAndroidScheduleMode();
    final reminders = _remindersFor(level);

    for (var i = 0; i < reminders.length; i++) {
      final reminder = reminders[i];
      final scheduledDate = dueDate.add(reminder.offset);
      final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

      if (!scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) continue;

      await flutterLocalNotificationsPlugin.zonedSchedule(
        _notificationIdFor(taskId, i),
        reminder.titleFor(title),
        reminder.bodyFor(dueDate),
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel_id',
            'Recordatorios de Tareas',
            channelDescription:
                'Canal para las notificaciones programadas de tareas.',
            importance: reminder.isFollowUp
                ? Importance.defaultImportance
                : Importance.high,
            priority:
                reminder.isFollowUp ? Priority.defaultPriority : Priority.high,
            groupKey: _taskGroupKey,
            actions: const [
              AndroidNotificationAction(
                'complete_task',
                'Completar',
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'snooze_10',
                'Posponer 10 min',
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'snooze_30',
                'Posponer 30 min',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: scheduleMode,
        payload: jsonEncode({
          'userId': userId,
          'taskId': taskId,
          'title': title,
          'dueDate': dueDate.toIso8601String(),
          'level': level.firestoreValue,
        }),
      );
    }
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    for (var i = 0; i < _maxNotificationsPerTask; i++) {
      await flutterLocalNotificationsPlugin
          .cancel(_notificationIdFor(taskId, i));
    }
  }

  Future<void> rescheduleTaskReminderFromData({
    required String userId,
    required String taskId,
    required Map<String, dynamic> task,
  }) async {
    final dueDateValue = task['dueDate'];
    final dueDate = dueDateValue is Timestamp ? dueDateValue.toDate() : null;
    final title = (task['title'] ?? 'Tarea').toString();
    final level = reminderLevelFromValue(task['reminderLevel']);

    if (dueDate == null || task['completed'] == true) {
      await cancelTaskNotifications(taskId);
      return;
    }

    await scheduleTaskReminders(
      userId: userId,
      taskId: taskId,
      title: title,
      dueDate: dueDate,
      level: level,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> showNotification({
    required int id,
    required String? title,
    required String? body,
    String? payload,
  }) async {
    await initNotifications();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'task_channel_id',
      'Recordatorios de Tareas',
      channelDescription: 'Canal para notificaciones inmediatas y de Firebase.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  static ReminderLevel reminderLevelFromValue(Object? value) {
    switch (value?.toString()) {
      case 'soft':
        return ReminderLevel.soft;
      case 'insistent':
        return ReminderLevel.insistent;
      case 'normal':
      default:
        return ReminderLevel.normal;
    }
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final data = jsonDecode(payload) as Map<String, dynamic>;
    final userId = data['userId']?.toString();
    final taskId = data['taskId']?.toString();
    if (userId == null || taskId == null) return;

    await _ensureFirebaseInitialized();

    final taskRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId);

    if (response.actionId == 'complete_task') {
      await taskRef.update({'completed': true});
      await NotificationService().cancelTaskNotifications(taskId);
      return;
    }

    if (response.actionId == 'snooze_10' || response.actionId == 'snooze_30') {
      final minutes = response.actionId == 'snooze_10' ? 10 : 30;
      await NotificationService()._scheduleSnooze(
        payload: data,
        minutes: minutes,
      );
    }
  }

  static Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }

  Future<void> _scheduleSnooze({
    required Map<String, dynamic> payload,
    required int minutes,
  }) async {
    await initNotifications();

    final userId = payload['userId']?.toString();
    final taskId = payload['taskId']?.toString();
    final title = payload['title']?.toString() ?? 'Tarea';
    if (userId == null || taskId == null) return;

    final taskDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .get();
    final taskData = taskDoc.data();
    if (taskData == null || taskData['completed'] == true) return;

    final scheduledTime =
        tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    await flutterLocalNotificationsPlugin.zonedSchedule(
      _notificationIdFor(taskId, _maxNotificationsPerTask - 1),
      'Pospuesto: $title',
      'Te lo recuerdo de nuevo en $minutes minutos.',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel_id',
          'Recordatorios de Tareas',
          channelDescription:
              'Canal para las notificaciones programadas de tareas.',
          importance: Importance.high,
          priority: Priority.high,
          groupKey: _taskGroupKey,
          actions: [
            AndroidNotificationAction(
              'complete_task',
              'Completar',
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'snooze_10',
              'Posponer 10 min',
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'snooze_30',
              'Posponer 30 min',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _resolveAndroidScheduleMode(),
      payload: jsonEncode(payload),
    );
  }

  List<_TaskReminder> _remindersFor(ReminderLevel level) {
    switch (level) {
      case ReminderLevel.soft:
        return const [
          _TaskReminder(Duration(hours: -1), '1 hora antes'),
          _TaskReminder(Duration.zero, 'hora exacta'),
        ];
      case ReminderLevel.normal:
        return const [
          _TaskReminder(Duration(hours: -2), '2 horas antes'),
          _TaskReminder(Duration(minutes: -30), '30 minutos antes'),
          _TaskReminder(Duration.zero, 'hora exacta'),
        ];
      case ReminderLevel.insistent:
        return const [
          _TaskReminder(Duration(hours: -2), '2 horas antes'),
          _TaskReminder(Duration(hours: -1), '1 hora antes'),
          _TaskReminder(Duration(minutes: -30), '30 minutos antes'),
          _TaskReminder(Duration(minutes: -10), '10 minutos antes'),
          _TaskReminder(Duration.zero, 'hora exacta'),
          _TaskReminder(Duration(minutes: 10), 'seguimiento'),
          _TaskReminder(Duration(minutes: 30), 'seguimiento'),
          _TaskReminder(Duration(hours: 1), 'seguimiento'),
        ];
    }
  }

  int _notificationIdFor(String taskId, int index) {
    final base = taskId.hashCode.abs() % 1000000;
    return (base * 10) + index;
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

class _TaskReminder {
  const _TaskReminder(this.offset, this.label);

  final Duration offset;
  final String label;

  bool get isFollowUp => offset > Duration.zero;

  String titleFor(String taskTitle) {
    if (offset == Duration.zero) return 'Ahora: $taskTitle';
    if (isFollowUp) return 'Seguimiento: $taskTitle';
    return 'Recordatorio: $taskTitle';
  }

  String bodyFor(DateTime dueDate) {
    if (offset == Duration.zero) {
      return 'Es la hora programada para esta tarea.';
    }
    if (isFollowUp) {
      return 'Esta tarea vencio hace $label. Puedes completarla o posponerla.';
    }
    return 'Esta tarea vence en $label.';
  }
}
