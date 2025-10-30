import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

// --- COLORES CYBERPUNK ---
const Color _primaryGold = Color(0xFFFFD700); // Dorado
const Color _accentCyan = Colors.cyanAccent; // Cian
const Color _darkBackground = Colors.black; // Negro oscuro de fondo
// -------------------------

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

  // --- WIDGET PARA DECORACIÓN DE INPUT CYBERPUNK (Adaptado) ---
  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _accentCyan),
      hintStyle: const TextStyle(color: Colors.white30),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
      filled: true,
      fillColor: Colors.grey.withOpacity(0.1), // Fondo ligeramente visible
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white38, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accentCyan, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 3),
      ),
    );
  }

  // --- LÓGICA DE ELIMINACIÓN (SIN CAMBIOS) ---
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
      // Mapeo simple de errores, o mantienes el mensaje completo de Firebase
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
      setState(() => _loading = false);
    }
  }
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground, // Fondo totalmente negro
      appBar: AppBar(
        title: const Text(
          'Eliminar Cuenta',
          style: TextStyle(color: _primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _darkBackground,
        iconTheme: const IconThemeData(color: _accentCyan),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 80),
            const SizedBox(height: 20),
            const Text(
              'ELIMINACIÓN DE DATOS (Protocolo R3D)',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠️ ADVERTENCIA: Esta acción es permanente. Se eliminará tu cuenta de usuario y todos los datos (tareas) asociados a ella en Firestore. Debes reingresar tu contraseña.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // --- Mensaje de Error (Estilizado) ---
            if (_error != null)
              Container(
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
                      color: Colors.redAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            // --- Formulario de Contraseña ---
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _getInputDecoration(
                        'Contraseña'), // Usa el estilo Cyberpunk
                    validator: (v) => v == null || v.isEmpty
                        ? 'Ingresa tu contraseña para confirmar'
                        : null,
                    onSaved: (v) => _password = v!.trim(),
                  ),
                  const SizedBox(height: 40),

                  // --- Botón de ELIMINAR (Rojo intenso, resaltando el peligro) ---
                  _loading
                      ? const CircularProgressIndicator(color: Colors.redAccent)
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _deleteAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.redAccent, // Botón de PELIGRO
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                    color: Colors.red, width: 2),
                              ),
                              elevation: 8,
                              shadowColor: Colors.red.withOpacity(0.8),
                            ),
                            child: const Text(
                              'ELIMINAR CUENTA PERMANENTEMENTE',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: _darkBackground,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),

                  // --- Botón de Cancelar ---
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar / Regresar',
                        style: TextStyle(color: _accentCyan)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
