// Archivo: lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
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
  }

  // 🔔 NUEVO MÉTODO: PROGRAMA EL RECORDATORIO CONSTANTE (GENÉRICO Y RECURRENTE)
  Future<void> scheduleConstantReminder() async {
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
}
