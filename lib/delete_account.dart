import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();
  String _password = '';
  String? _error;
  bool _loading = false;

  // --- LÓGICA DE ELIMINACIÓN ---
  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    _formKey.currentState?.save();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _password,
      );

      // Reautenticamos al usuario antes de eliminar
      await user.reauthenticateWithCredential(cred);

      // Eliminamos sus datos de Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // Eliminamos su cuenta de Firebase Auth
      await user.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta eliminada con éxito')),
        );
        // Navega a Login y elimina todas las rutas anteriores
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Error al eliminar cuenta';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Contraseña incorrecta. Por favor, inténtalo de nuevo.';
      } else if (e.code == 'requires-recent-login') {
        message =
            'Por favor, cierra sesión y vuelve a iniciarla para eliminar tu cuenta.';
      } else {
        message = e.message ?? 'Error desconocido';
      }

      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// EFECTO ROJO DE FONDO (Glows)
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            right: -120,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.12),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      /// BOTON ATRAS Y LOGO
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.cyan.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.cyanAccent.withOpacity(0.4),
                              ),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.cyanAccent,
                              ),
                            ),
                          ),
                          // Logo Stalky siempre visible
                          Image.asset(
                            'assets/logo/icon.png',
                            height: 60,
                            width: 60,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.star,
                              color: Color(0xFFD4AF37),
                              size: 30,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      /// TITULO
                      const Text(
                        "ELIMINAR CUENTA",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFF3B3B),
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: Colors.red,
                              blurRadius: 15,
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 35),

                      /// ICONO DE ADVERTENCIA
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
                          size: 95,
                          color: Color(0xFFFF4D4D),
                        ),
                      ),

                      const SizedBox(height: 35),

                      /// SUBTITULO
                      const Text(
                        "ELIMINACIÓN TOTAL",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFF5555),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "[PROTOCOLO CRÍTICO]",
                        style: TextStyle(
                          color: Color(0xFFFF8888),
                          fontSize: 17,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 30),

                      /// MENSAJE DE ERROR
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            border: Border.all(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      /// ALERTA (Texto informativo)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.12),
                              blurRadius: 15,
                            )
                          ],
                        ),
                        child: const Text(
                          "Esta acción es IRREVERSIBLE.\n\n"
                          "Todos tus datos, progreso, configuraciones "
                          "y acceso serán eliminados permanentemente "
                          "del sistema.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFFB3B3),
                            fontSize: 15,
                            height: 1.7,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      /// TEXTO DE CONFIRMACIÓN
                      const Text(
                        "Confirma tu contraseña para continuar.\n"
                        "Una vez eliminada la cuenta no podrás recuperarla.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.7,
                        ),
                      ),

                      const SizedBox(height: 35),

                      /// INPUT DE CONTRASEÑA
                      TextFormField(
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Confirmar contraseña",
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF111111),
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFFFF4D4D),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: Colors.red.withOpacity(0.4),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          errorStyle: const TextStyle(color: Colors.redAccent),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Contraseña requerida'
                            : null,
                        onSaved: (v) => _password = v!.trim(),
                      ),

                      const SizedBox(height: 40),

                      /// BOTON ELIMINAR
                      SizedBox(
                        width: double.infinity,
                        height: 65,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _deleteAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF2E2E),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.red.withOpacity(0.5),
                            elevation: 15,
                            shadowColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  "ELIMINAR CUENTA\nPERMANENTEMENTE",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    height: 1.4,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      /// CANCELAR
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancelar y regresar",
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 15,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
