import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'delete_account.dart';
import 'dart:math';

// --- COLORES CYBERPUNK ---
const Color _primaryGold = Color(0xFFFFD700);
const Color _secondaryPurple = Color(0xFFB300FF);
const Color _accentCyan = Colors.cyanAccent;
const Color _darkBackground = Colors.black;
// -------------------------

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _initialName = '';

  String _name = '';
  String _email = '';
  String? _error;
  bool _loading = false;
  bool _hasChanges = false;

  String _currentPassword = '';
  String _newPassword = '';

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE CARGA DE DATOS ---
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      setState(() {
        _name = data?['name'] ?? '';
        _initialName = _name;
        _email = user.email ?? 'No disponible';

        _newPassword = '';
        _currentPassword = '';
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _hasChanges = false;
        _error = null;
      });
    }
  }

  // --- LÓGICA DE ACTUALIZACIÓN DE CONTRASEÑA ---
  Future<void> _updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado.');
    }
    if (_currentPassword.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-current-password',
        message: 'Debes ingresar tu contraseña actual para cambiarla.',
      );
    }
    try {
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada correctamente')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw FirebaseAuthException(
          code: 'wrong-password',
          message:
              'Contraseña actual incorrecta. No se pudo cambiar la contraseña.',
        );
      }
      rethrow;
    }
  }

  // --- FUNCIÓN PRINCIPAL DE ACTUALIZACIÓN ---
  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    _formKey.currentState?.save();

    final bool changingPassword = _newPassword.isNotEmpty;
    bool requiresUpdate = (_name != _initialName) || changingPassword;

    if (!requiresUpdate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay cambios para guardar.')),
        );
      }
      return;
    }

    setState(() => _loading = true);

    try {
      if (changingPassword) {
        await _updatePassword(_newPassword);
      }

      if (_name != _initialName) {
        final userDoc = _firestore.collection('users').doc(user.uid);
        await userDoc.set({
          'name': _name,
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nombre actualizado correctamente.')),
          );
        }
      }

      await _loadUserData();
    } on FirebaseAuthException catch (e) {
      String errorMessage = e.message ?? 'Error de autenticación: ${e.code}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- LÓGICA DE CERRAR SESIÓN ---
  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (Route<dynamic> route) => false,
      );
    }
  }

  // --- WIDGET PARA DECORACIÓN DE INPUT Cyberpunk ---
  InputDecoration _getInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _accentCyan),
      filled: true,
      fillColor: _darkBackground.withOpacity(0.5),
      prefixIcon: Icon(
        icon,
        color: _primaryGold,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white38, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _primaryGold, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 3),
      ),
      hintStyle: const TextStyle(color: Colors.white38),
    );
  }

  // --- WIDGET PERSONALIZADO: Botón estilo "Thumb" Cyberpunk ---
  Widget _buildThumbButton({
    required String text,
    required VoidCallback onPressed,
    bool gradient = false,
    Color? bgColor,
  }) {
    if (gradient) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
                padding: EdgeInsets.zero,
                backgroundColor: _darkBackground,
                shadowColor: _accentCyan.withOpacity(0.5),
                elevation: 8,
              ),
              onPressed: onPressed,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [_primaryGold, _secondaryPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    transform: GradientRotation(_controller.value * 2 * pi),
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: _accentCyan.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    text,
                    style: const TextStyle(
                        color: _darkBackground,
                        fontWeight: FontWeight.w900,
                        fontSize: 16),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: bgColor,
          side: BorderSide(color: bgColor ?? Colors.white70, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
              color: bgColor ?? Colors.white70, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: _darkBackground,
        foregroundColor: _accentCyan,
      ),
      body: Stack(
        children: [
          // 1. ICONO DE FONDO
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.15,
                child: Center(
                  child: Transform.rotate(
                    angle: -pi / 8,
                    child: Icon(
                      Icons.storage,
                      size: MediaQuery.of(context).size.width * 0.9,
                      color: _secondaryPurple,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 2. CONTENIDO PRINCIPAL
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _accentCyan))
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  color: _primaryGold,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(25, 20, 25, 30),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- MENSAJE DE ERROR ---
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold)),
                          ),

                        // --- HEADER DE PERFIL (SIN AVATAR) ---
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              width: 3,
                              color: _primaryGold,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ❌ Eliminado: CircleAvatar
                              const SizedBox(height: 5),

                              Text(
                                _name.isNotEmpty ? _name : 'Usuario',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _email,
                                style: const TextStyle(
                                    color: _accentCyan, fontSize: 16),
                              ),
                              const SizedBox(height: 5),

                              // Línea separadora
                              Container(
                                height: 1,
                                width: 150,
                                color: _primaryGold.withOpacity(0.5),
                                margin: const EdgeInsets.only(top: 10),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- Formulario de edición ---
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. CAMPO DE NOMBRE
                              TextFormField(
                                initialValue: _name,
                                style: const TextStyle(color: Colors.white),
                                decoration: _getInputDecoration(
                                    'Cambiar Nombre', Icons.person_outline),
                                onChanged: (v) {
                                  setState(() {
                                    final nameChanged =
                                        v.trim() != _initialName;
                                    _hasChanges =
                                        nameChanged || _newPassword.isNotEmpty;
                                  });
                                },
                                onSaved: (v) => _name = v!.trim(),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'El nombre no puede estar vacío';
                                  }
                                  final nameRegExp =
                                      RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$");
                                  if (!nameRegExp.hasMatch(v.trim())) {
                                    return 'Solo se permiten letras y espacios';
                                  }
                                  if (v.trim().length < 2) {
                                    return 'Mínimo 2 letras';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 25),

                              // 2. CAMPO DE CONTRASEÑA ACTUAL
                              TextFormField(
                                controller: _currentPasswordController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _getInputDecoration(
                                    'Contraseña Actual (Requerida si cambias la nueva)',
                                    Icons.lock_outline),
                                obscureText: true,
                                onChanged: (v) => _currentPassword = v.trim(),
                                validator: (v) {
                                  if (_newPassword.isNotEmpty &&
                                      (v == null || v.isEmpty)) {
                                    return 'Debes ingresar tu contraseña actual para cambiarla.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // 3. CAMBIAR CONTRASEÑA
                              TextFormField(
                                controller: _newPasswordController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _getInputDecoration(
                                    'Nueva Contraseña (Dejar vacío para no cambiar)',
                                    Icons.vpn_key_outlined),
                                obscureText: true,
                                onChanged: (v) {
                                  setState(() {
                                    _newPassword = v.trim();
                                    _hasChanges = (_name != _initialName) ||
                                        _newPassword.isNotEmpty;
                                  });
                                },
                                onSaved: (v) => _newPassword = v!,
                                validator: (v) {
                                  if (v != null &&
                                      v.isNotEmpty &&
                                      v.length < 6) {
                                    return 'La contraseña debe tener al menos 6 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 40),

                              // --- BOTONES DE ACCIÓN ---
                              _buildThumbButton(
                                  text: 'Guardar cambios',
                                  onPressed: _loading ? () {} : _updateProfile,
                                  gradient: true),

                              const SizedBox(height: 20),

                              _buildThumbButton(
                                  text: 'Cerrar Sesión',
                                  onPressed: _logout,
                                  bgColor: _accentCyan),

                              const SizedBox(height: 20),

                              _buildThumbButton(
                                text: 'Eliminar cuenta',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const DeleteAccountPage()),
                                  );
                                },
                                bgColor: Colors.redAccent,
                              ),
                            ],
                          ),
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
