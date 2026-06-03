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
import 'services/theme_controller.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
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
    providerAndroid: const AndroidDebugProvider(),
    providerWeb: ReCaptchaV3Provider(
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
  final themeController = ThemeController();
  await themeController.loadThemeMode();

  // 🔔 7. CONFIGURAR LISTENERS DE MENSAJES EN PRIMER PLANO (Foreground)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

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
        ? MyApp(themeController: themeController)
        : DevicePreview(
            enabled: true,
            builder: (context) => MyApp(themeController: themeController),
          ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      controller: themeController,
      child: AnimatedBuilder(
        animation: themeController,
        builder: (context, _) {
          return MaterialApp(
            title: 'Stalky',
            debugShowCheckedModeBanner: false,
            locale: kReleaseMode ? null : DevicePreview.locale(context),
            builder: kReleaseMode ? null : DevicePreview.appBuilder,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: themeController.themeMode,
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasData && snapshot.data?.isAnonymous == false) {
                  return const DashboardPage();
                }

                return const LoginPage();
              },
            ),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const gold = Color(0xFFD4AF37);
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: brightness,
    ).copyWith(
      primary: gold,
      onPrimary: Colors.black,
      surface: isDark ? const Color(0xFF000000) : const Color(0xFFF8F7FB),
      onSurface: isDark ? Colors.white : const Color(0xFF111111),
      surfaceContainerHighest:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF),
      outline: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E1EA),
      error: Colors.redAccent,
    );
    final base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      primaryColor: gold,
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor:
            isDark ? Colors.grey.shade600 : Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
      ),
      cardColor: scheme.surfaceContainerHighest,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
        helperStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.45)),
        prefixIconColor: scheme.onSurface.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
