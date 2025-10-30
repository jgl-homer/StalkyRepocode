// 📁 lib/login.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'register.dart';
import 'dashboard.dart';

// ==================== LOGIN PAGE ====================
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

  // ==================== FUNCIÓN LOGIN ====================
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

  // ==================== RESET PASSWORD ====================
  Future<void> _resetPassword() async {
    if (_email.isEmpty) {
      // Si no hay correo en el formulario, pedimos que lo escriba
      final emailController = TextEditingController();
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Recuperar contraseña'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Ingresa tu correo',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  try {
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: email);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Correo de recuperación enviado.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.message ?? 'Error al enviar correo'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      );
    } else {
      // Si ya escribió un correo en el formulario, usarlo directamente
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Correo de recuperación enviado.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'Error al enviar correo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ==================== INTERFAZ ====================
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          body: CustomPaint(
            painter: MovingGradientPainter(_controller.value),
            child: child,
          ),
        );
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 💠 Tarjeta del login (más pequeña)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 330,
                ),
                child: Card(
                  color: Colors.black.withOpacity(0.65),
                  elevation: 20,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: Colors.amberAccent.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 90,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Bienvenido',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Inicia sesión para continuar',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 14.5),
                        ),
                        const SizedBox(height: 16),

                        // ⚠️ Error
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // 📋 Formulario
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTextField(
                                'Correo electrónico',
                                Icons.email_outlined,
                                onSaved: (v) => _email = v!.trim(),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Correo requerido'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                'Contraseña',
                                Icons.lock_outline,
                                obscure: true,
                                onSaved: (v) => _password = v!,
                                validator: (v) => v == null || v.length < 6
                                    ? 'Mínimo 6 caracteres'
                                    : null,
                              ),
                              const SizedBox(height: 22),

                              // 🔘 Botón login
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFC107),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
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
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                              ),

                              // 🔐 Olvidé mi contraseña
                              Center(
                                child: TextButton(
                                  onPressed: _isLoading ? null : _resetPassword,
                                  child: const Text(
                                    'Olvidé mi contraseña',
                                    style: TextStyle(color: Colors.amberAccent),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // 🪪 Crear cuenta
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                ),
                                child: const Text(
                                  'Crear cuenta nueva',
                                  style: TextStyle(color: Colors.amberAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 🌟 Ícono en esquina superior derecha (más grande)
              Positioned(
                top: 8,
                right: 8,
                child: Image.asset(
                  'assets/logo/icon.png',
                  height: 95,
                  width: 95,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.star,
                    color: Colors.amberAccent,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== CAMPO DE TEXTO ====================
  Widget _buildTextField(
    String label,
    IconData icon, {
    bool obscure = false,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return TextFormField(
      style: const TextStyle(color: Colors.white),
      obscureText: obscure,
      validator: validator,
      onSaved: onSaved,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.amberAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ==================== FONDO ANIMADO ====================
class MovingGradientPainter extends CustomPainter {
  final double progress;
  MovingGradientPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = Offset.zero & size;

    final double x = 0.5 + 0.5 * cos(progress * 2 * pi);
    final double y = 0.5 + 0.5 * sin(progress * 2 * pi);

    final gradient = RadialGradient(
      center: Alignment(x * 2 - 1, y * 2 - 1),
      radius: 1.2,
      colors: [
        const Color(0xFFFFD54F),
        const Color(0xFF512DA8),
        Colors.black,
      ],
      stops: const [0.2, 0.6, 1.0],
    );

    paint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
