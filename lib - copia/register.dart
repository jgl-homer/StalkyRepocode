// 📁 lib/register.dart (LOGIN STYLE COLORES LOGIN)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verification_required.dart'; // 🔹 Pantalla de verificación
import 'dart:math';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
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
        await user.sendEmailVerification();
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _name,
          'email': _email,
        });

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
            () => _error = 'Este correo ya está registrado. Inicia sesión.');
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color marco = Colors.amberAccent;
    const Color boton = Color(0xFFFFC107);

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
              // 💠 Tarjeta de registro
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 330),
                child: Card(
                  color: Colors.black.withOpacity(0.65),
                  elevation: 20,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side:
                          BorderSide(color: marco.withOpacity(0.5), width: 2)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 90, color: Colors.white70),
                        const SizedBox(height: 10),
                        const Text(
                          'Crear Cuenta',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Regístrate para continuar',
                          style: TextStyle(color: Colors.white54, fontSize: 15),
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
                              _buildTextField(
                                'Nombre de usuario',
                                Icons.person_outline,
                                onSaved: (v) => _name = v!.trim(),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Nombre requerido'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                'Correo electrónico',
                                Icons.email_outlined,
                                onSaved: (v) => _email = v!.trim(),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Correo requerido'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                'Contraseña',
                                Icons.lock_outline,
                                obscure: true,
                                onSaved: (v) => _password = v!,
                                validator: (v) => v == null || v.length < 6
                                    ? 'Mínimo 6 caracteres'
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: boton,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                  ),
                                  onPressed: _isLoading ? null : _tryRegister,
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
                                          'REGISTRARSE',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Ya tienes cuenta? Inicia sesión',
                                  style: TextStyle(color: marco),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),

              // 🌟 Icono en la esquina superior derecha
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

  Widget _buildTextField(String label, IconData icon,
      {bool obscure = false,
      String? Function(String?)? validator,
      void Function(String?)? onSaved}) {
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
