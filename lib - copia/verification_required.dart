// Archivo: lib/verification_required_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';

class VerificationRequiredPage extends StatelessWidget {
  const VerificationRequiredPage({super.key});

  // Función para reenviar el correo
  Future<void> _resendVerification(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correo de verificación reenviado.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al reenviar el correo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación Requerida'),
        backgroundColor: Colors.pink,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread,
                size: 100,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 30),
              const Text(
                'Confirma tu Correo Electrónico',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              const Text(
                'Hemos enviado un enlace de verificación al correo que registraste. Por favor, revísalo para activar tu cuenta. Si no lo encuentras, revisa tu carpeta de Spam.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => _resendVerification(context),
                icon: const Icon(Icons.send),
                label: const Text('Reenviar Correo de Verificación'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  // Volver al login para intentar de nuevo
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text('Ya verifiqué, ir a Iniciar Sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
