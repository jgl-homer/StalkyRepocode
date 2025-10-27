// Archivo: lib/login.dart (FINAL CON ÍCONO EN LA ESQUINA DEL CONTENEDOR)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register.dart';
import 'dashboard.dart';
import 'fcm_service.dart'; // 🚀 IMPORTACIÓN NECESARIA PARA LA FUNCIÓN

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String? _error;
  bool _isLoading = false;

  // Login con email y contraseña
  Future<void> _tryLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    _formKey.currentState?.save();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: _email, password: _password);

      final user = userCredential.user;

      if (user != null) {
        await user.reload();

        if (!user.emailVerified) {
          setState(
            () => _error =
                'Debes verificar tu correo para acceder. Revisa tu bandeja de entrada.',
          );

          await user.sendEmailVerification();
          await FirebaseAuth.instance.signOut();
          return;
        }

        // Se asume que saveFCMToken() está definido en fcm_service.dart
        // ignore: todo
        // TODO: Descomenta la siguiente línea si la función existe y es necesaria.
        // await saveFCMToken();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          _error = 'Credenciales incorrectas.';
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Restablecer contraseña
  Future<void> _resetPassword() async {
    if (_email.isEmpty) {
      setState(
        () => _error = 'Ingresa tu correo para restablecer la contraseña',
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Correo de recuperación enviado')),
        );
        setState(() => _error = null);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Estilo de input unificado
    const inputDecorationStyle = InputDecoration(
      filled: true,
      fillColor: Color.fromRGBO(255, 255, 255, 0.1),
      contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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

    return Scaffold(
      // 💡 Eliminamos el AppBar y colocamos todo en el body
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 47, 211, 233),
              Color.fromARGB(255, 0, 0, 0),
              Color.fromARGB(255, 238, 92, 151),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          // 💡 El SingleChildScrollView simulará la tarjeta
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            decoration: BoxDecoration(
              color:
                  Colors.black.withOpacity(0.5), // Fondo de la "tarjeta" oscura
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Stack(
                // Usamos Stack para posicionar el ícono en la esquina
                children: [
                  // 1. Ícono de la App en la esquina superior derecha
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Image.asset(
                      'assets/logo/icon.png', // 🚀 Tu logo de la app
                      height: 25,
                      width: 25,
                    ),
                  ),

                  // 2. Contenido principal (centrado)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔑 ÍCONO DE CANDADO GRANDE (similar a la imagen)
                      const Icon(Icons.lock_open,
                          size: 60, color: Colors.white),
                      const SizedBox(height: 10),
                      const Text(
                        'Bienvenido',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Iniciar Sesión', // Muestra la acción (opcional)
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // CAMPO CORREO
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: inputDecorationStyle.copyWith(
                                labelText: 'Correo electrónico',
                                prefixIcon: const Icon(Icons.mail_outline,
                                    color: Colors.white70),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'El correo es obligatorio';
                                }
                                final emailRegExp = RegExp(
                                  r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                                );
                                if (!emailRegExp.hasMatch(v.trim())) {
                                  return 'Correo inválido';
                                }
                                return null;
                              },
                              onSaved: (v) => _email = v!.trim(),
                            ),
                            const SizedBox(height: 16),
                            // CAMPO CONTRASEÑA
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: inputDecorationStyle.copyWith(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: Colors.white70),
                              ),
                              obscureText: true,
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Mínimo 6 caracteres'
                                  : null,
                              onSaved: (v) => _password = v!,
                            ),
                            const SizedBox(height: 30),
                            // Botón de Entrar
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors
                                    .amber, // Botón amarillo como en la imagen
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: _isLoading ? null : _tryLogin,
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
                                      'Entrar',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              ),
                              child: const Text(
                                'Crear cuenta nueva', // Texto similar a la imagen
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            // Se elimina el TextButton de '¿Olvidaste tu contraseña?' para simplificar y acercarnos a la imagen.
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
