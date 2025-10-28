// Archivo: lib/register.dart (FINAL - OPTIMIZADO PARA MOSTRAR TODO SIN SCROLL)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verification_required.dart'; // ✅ Importación de la página de verificación
// import 'fcm_service.dart'; // Importación comentada si no existe

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _password = '';
  String? _error;
  bool _isLoading = false;

  Future<void> _tryRegister() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    _formKey.currentState?.save();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: _email, password: _password);

      final user = userCred.user;

      if (user != null) {
        // 1. Enviar correo de verificación
        await user.sendEmailVerification();

        // 2. Guardar datos adicionales en Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _name,
          'email': _email,
        });

        // ✅ Bloque DESCOMENTADO para redirigir a la pantalla de verificación
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VerificationRequiredPage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(
          () => _error =
              'Este correo ya está registrado. Inicia sesión o revisa tu correo para verificar tu cuenta.',
        );
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔑 ESTILO DE INPUT UNIFICADO
    const inputDecorationStyle = InputDecoration(
      filled: true,
      fillColor: Color.fromRGBO(255, 255, 255, 0.1),
      contentPadding: EdgeInsets.symmetric(
          vertical: 16, horizontal: 16), // REDUCIDO de 20 a 16
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      labelStyle: TextStyle(color: Colors.white70, fontSize: 16),
    );

    // 🎨 COLORES DEL GRADIENTE
    const Color cian = Color.fromARGB(255, 47, 211, 233);
    const Color rosa = Color.fromARGB(255, 238, 92, 151);
    const Color negro = Color.fromARGB(255, 0, 0, 0);

    return Scaffold(
      body: Container(
        // 🌈 GRADIENTE
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [cian, negro, rosa],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          // 💳 CARD CENTRAL
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24), // REDUCIDO el padding vertical de 40 a 24
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  // 1. ÍCONO DE LA APP EN LA ESQUINA SUPERIOR DERECHA
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Image.asset(
                      'assets/logo/icon.png', // Asegúrate de que esta ruta sea correcta
                      height: 25,
                      width: 25,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.flash_on,
                          size: 25,
                          color: Colors.white70), // Fallback
                    ),
                  ),

                  // 2. Contenido principal (envuelto en Column)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔒 ÍCONO DE CANDADO CERRADO
                      const Icon(Icons.lock,
                          size: 48, color: Colors.white), // REDUCIDO de 60 a 48
                      const SizedBox(height: 5), // REDUCIDO de 10 a 5
                      const Text(
                        'Crear Cuenta',
                        style: TextStyle(
                          fontSize: 26, // REDUCIDO de 28 a 26
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Regístrate ahora',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20), // REDUCIDO de 30 a 20
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 10), // REDUCIDO de 20 a 10
                      ],
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // 🔑 CAMPO NOMBRE
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: inputDecorationStyle.copyWith(
                                labelText: 'Nombre',
                                prefixIcon: const Icon(Icons.person,
                                    color: Colors.white70),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Nombre obligatorio';
                                // ✅ VALIDACIÓN PARA NO PERMITIR NÚMEROS
                                if (RegExp(r'\d').hasMatch(v)) {
                                  return 'El nombre no debe contener números.';
                                }
                                return null;
                              },
                              onSaved: (v) => _name = v!.trim(),
                            ),
                            const SizedBox(height: 12), // REDUCIDO de 16 a 12

                            // 🔑 CAMPO CORREO
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: inputDecorationStyle.copyWith(
                                labelText: 'Correo electrónico',
                                prefixIcon: const Icon(Icons.mail_outline,
                                    color: Colors.white70),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Correo obligatorio';
                                return null;
                              },
                              onSaved: (v) => _email = v!.trim(),
                            ),
                            const SizedBox(height: 12), // REDUCIDO de 16 a 12

                            // 🔑 CAMPO CONTRASEÑA
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: inputDecorationStyle.copyWith(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: Colors.white70),
                              ),
                              obscureText: true,
                              validator: (v) => v == null || v.length < 6
                                  ? 'Mínimo 6 caracteres'
                                  : null,
                              onSaved: (v) => _password = v!,
                            ),

                            const SizedBox(height: 20), // REDUCIDO de 30 a 20

                            // 🔘 BOTÓN DE CREAR CUENTA (CIAN)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cian, // Botón cian
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: _isLoading ? null : _tryRegister,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Crear cuenta',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8), // REDUCIDO de 16 a 8
                            // Enlace para volver al Login
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Ya tienes cuenta? Inicia sesión',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}