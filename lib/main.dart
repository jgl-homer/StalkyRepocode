// Archivo: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart'
    as tz_package; // Importación para tz.local
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_preview/device_preview.dart';

import 'firebase_options.dart';
import 'login.dart';
import 'dashboard.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar Firebase Core
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔔 2. CONFIGURAR EL MANEJADOR DE MENSAJES EN SEGUNDO PLANO
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🧭 3. INICIALIZAR LA BASE DE DATOS DE ZONA HORARIA
  tz.initializeTimeZones();

  try {
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz_package.setLocalLocation(
      tz_package.getLocation(localTimezone.identifier),
    );
  } catch (e) {
    tz_package.setLocalLocation(tz_package.getLocation('America/Mexico_City'));
    if (kDebugMode) {
      print('No se pudo detectar zona horaria local: $e');
    }
  }

  // 🔒 4. INICIALIZACIÓN DE APP CHECK (debug para desarrollo/emulador)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    webProvider: ReCaptchaV3Provider(
      '6Lc1H_UrAAAAANltWq-pY11iXLcm83744gdTrbVn',
    ),
  );

  // 👤 4b. Autenticación anónima de respaldo (garantiza uid para Firestore)
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {}
  }

  // 🚀 5. Inicializar el Servicio de Notificaciones (para notificaciones locales)
  final notificationService = NotificationService(); // Almacenar la instancia
  await notificationService.initNotifications();

  // 🔔 7. CONFIGURAR LISTENERS DE MENSAJES EN PRIMER PLANO (Foreground)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      NotificationService().showNotification(
        id: message.hashCode,
        title: message.notification!.title,
        body: message.notification!.body,
        payload: message.data.toString(),
      );
    }
  });

  runApp(
    kReleaseMode
        ? const MyApp()
        : DevicePreview(
            enabled: true,
            builder: (context) => const MyApp(),
          ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stalky',
      debugShowCheckedModeBanner: false,
      locale: kReleaseMode ? null : DevicePreview.locale(context),
      builder: kReleaseMode ? null : DevicePreview.appBuilder,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFD4AF37),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
          background: Color(0xFF000000),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF000000),
          selectedItemColor: Color(0xFFD4AF37),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
            );
          }

          if (snapshot.hasData && snapshot.data?.isAnonymous == false) {
            return const DashboardPage();
          }

          return const LoginPage();
        },
      ),
    );
  }
}
