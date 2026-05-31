import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  bool _googleInitialized = false;

  static const String _webClientId =
      '540678482428-5944vjcao704ts8ijidli241ooj9n0la.apps.googleusercontent.com';

  Future<UserCredential> signInWithGoogle() async {
    try {
      await _initializeGoogleSignIn();

      final googleAccount = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleAccount.authentication;

      if (googleAuth.idToken == null) {
        throw AuthServiceException(
          'No se pudo obtener el token de Google. Intenta de nuevo.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw AuthServiceException(
          'Google inició sesión, pero Firebase no devolvió usuario.',
        );
      }

      await _saveUserProfile(user);
      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthServiceException(
          e.description?.trim().isNotEmpty == true
              ? 'Google canceló el inicio: ${e.description}'
              : 'Google canceló el inicio. Revisa que el SHA-1/SHA-256 de esta APK esté agregado en Firebase.',
        );
      }
      if (e.code == GoogleSignInExceptionCode.uiUnavailable) {
        throw AuthServiceException(
          'Google Sign-In no está disponible en este dispositivo.',
        );
      }
      throw AuthServiceException(
        e.description ?? 'No se pudo iniciar sesión con Google.',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_firebaseMessage(e));
    }
  }

  Future<void> signOut() async {
    await _initializeGoogleSignIn();
    await Future.wait([
      GoogleSignIn.instance.signOut(),
      _auth.signOut(),
    ]);
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) return;
    final options = DefaultFirebaseOptions.currentPlatform;
    final appleClientId = options.iosClientId;

    await GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS
          ? appleClientId
          : null,
      serverClientId:
          defaultTargetPlatform == TargetPlatform.android ? _webClientId : null,
    );
    _googleInitialized = true;
  }

  Future<void> _saveUserProfile(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final existingDoc = await userDoc.get();
    final displayName = user.displayName?.trim();
    final fallbackName = user.email?.split('@').first.trim();
    final name = displayName?.isNotEmpty == true
        ? displayName!
        : (fallbackName?.isNotEmpty == true ? fallbackName! : 'Usuario');

    await userDoc.set({
      'name': name,
      'email': user.email,
      'photoURL': user.photoURL,
      'provider': 'google',
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existingDoc.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _firebaseMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Ya existe una cuenta con ese correo usando otro método de inicio.';
      case 'invalid-credential':
        return 'La credencial de Google no es válida. Intenta otra vez.';
      case 'network-request-failed':
        return 'Revisa tu conexión a internet e intenta de nuevo.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      default:
        return e.message ?? 'No se pudo iniciar sesión con Google.';
    }
  }
}

class AuthServiceException implements Exception {
  AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
