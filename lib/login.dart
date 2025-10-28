// Archivo: lib/login.dart (FINAL CORREGIDO Y COMPLETO)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register.dart';
import 'dashboard.dart';
// import 'fcm_service.dart'; // Importación comentada/eliminada

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

        // ignore: todo
        // TODO: Descomenta la siguiente línea si la función saveFCMToken() existe.
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
    // ⚠️ CORRECCIÓN del error use_of_void_result: Llamamos a save() como acción.
    _formKey.currentState?.save();

    // Verificamos si el email es válido después de llamar a save()
    if (_email.isEmpty ||
        !RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
            .hasMatch(_email.trim())) {
      setState(
        () => _error =
            'Ingresa un correo válido en el campo superior para restablecer la contraseña',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Correo de recuperación enviado a $_email. Revisa tu bandeja.')),
        );
        setState(() => _error = null);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
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
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            decoration: BoxDecoration(
              // ⚠️ CORRECCIÓN: Usando Color.fromARGB para reemplazar withOpacity.
              color: const Color.fromARGB(
                  128, 0, 0, 0), // Fondo oscuro con 50% de opacidad.
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  // 1. Ícono de la App en la esquina superior derecha (RESTAURADO EL IMAGE.ASSET)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Image.asset(
                      'assets/logo/icon.png', // ✅ ¡TU IMAGEN DE ASSET ORIGINAL RESTAURADA!
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
                        'Iniciar Sesión',
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
                              onChanged: (v) => _email = v.trim(),
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
                                backgroundColor: Colors.amber,
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

                            // 🔑 ENLACE DE OLVIDÉ MI CONTRASEÑA
                            TextButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Enlace para ir al Registro
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              ),
                              child: const Text(
                                'Crear cuenta nueva',
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
