// Archivo: lib/fcm_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Obtiene el token de FCM del dispositivo y lo guarda en Firestore
/// asociado al usuario actual.
Future<void> saveFCMToken() async {
  final user = FirebaseAuth.instance.currentUser;

  // Si no hay usuario logueado, no hacemos nada.
  if (user == null) {
    print("FCM Service: No hay usuario logueado. Saliendo.");
    return;
  }

  try {
    // 1. Obtener el token de FCM del dispositivo actual
    final String? token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      print("FCM Service: Token obtenido: $token");

      // 2. Guardar o actualizar el campo 'fcmToken' en el documento del usuario
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmToken': token,
          'tokenTimestamp':
              FieldValue.serverTimestamp(), // Para saber cuándo se actualizó
        },
        SetOptions(
          merge: true,
        ), // Usa merge para no sobrescribir 'name', 'email', etc.
      );
      print("FCM Service: Token guardado en Firestore para ${user.email}");
    }
  } catch (e) {
    print("FCM Service: ERROR al guardar el token de FCM: $e");
  }
}
