// 📁 lib/login.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register.dart';
import 'dashboard.dart';

const Color dorado = Color(0xFFFFD400); // Amarillo-dorado brillante
const Color fondoNegro = Color(0xFF0A0A0A);
const Color fondoMorado = Color(0xFF2B0A4A);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String? _error;
  bool _isLoading = false;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              () => _error = 'Verifica tu correo antes de iniciar sesión.');
          await user.sendEmailVerification();
          await FirebaseAuth.instance.signOut();
          return;
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.code == 'user-not-found' || e.code == 'wrong-password'
            ? 'Credenciales incorrectas.'
            : e.message;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const inputDecorationStyle = InputDecoration(
      filled: true,
      fillColor: Color.fromRGBO(255, 255, 255, 0.1),
      contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      labelStyle: TextStyle(color: Colors.white70, fontSize: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: dorado, width: 2),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
    );

    return Scaffold(
      body: Stack(
        children: [
          // 🌌 Fondo con gradiente morado-amarillo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  fondoMorado,
                  fondoNegro,
                  Color(0xFFFFD400),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ✨ Círculo girando (efecto neón dorado)
          Center(
            child: RotationTransition(
              turns: _controller,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      dorado.withOpacity(0.6),
                      Colors.transparent,
                    ],
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 🖤 Panel principal
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: dorado.withOpacity(0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: dorado.withOpacity(0.25),
                    blurRadius: 15,
                    spreadRadius: 3,
                  )
                ],
              ),
              child: Stack(
                children: [
                  // 🔷 Ícono en la esquina superior derecha
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Image.asset(
                      'assets/logo/icon.png',
                      height: 28,
                      width: 28,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.star,
                        color: dorado,
                        size: 24,
                      ),
                    ),
                  ),

                  // Contenido principal
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 60, color: dorado),
                      const SizedBox(height: 8),
                      const Text(
                        'Bienvenido',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Inicia sesión para continuar',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: inputDecorationStyle.copyWith(
                                labelText: 'Correo electrónico',
                                prefixIcon: const Icon(Icons.mail_outline,
                                    color: Colors.white70),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Correo requerido'
                                  : null,
                              onSaved: (v) => _email = v!.trim(),
                            ),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: dorado,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _tryLogin,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : const Text(
                                        'Entrar',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
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
        ],
      ),
    );
  }
}
