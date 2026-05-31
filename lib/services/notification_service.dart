import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

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

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
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

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
