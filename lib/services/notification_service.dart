// Archivo: lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal() {
    // La inicialización de la zona horaria ahora se hace en main.dart para mayor seguridad
  }

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

  // 🚀 MÉTODO PRINCIPAL: Programa UNA SOLA Notificación (Sin Recurrencia)
  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
  ) async {
    // Convertir a TZDateTime usando la zona horaria local
    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    // 🛑 Cancelar si la hora ya pasó (una alarma única debe ser en el futuro)
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    // 🔑 NO se usa matchDateTimeComponents. La repetición la hace add_task_page.dart
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
          channelDescription:
              'Canal para notificaciones inmediatas y de Firebase.',
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
