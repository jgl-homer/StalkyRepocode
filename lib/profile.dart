import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'delete_account.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final Color _bg = const Color(0xFF000000);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _cardBg = const Color(0xFF1E1E1E);

  String _initialName = '';
  String _name = '';
  String _email = '';
  String? _error;
  bool _loading = false;
  bool _hasChanges = false;

  String _currentPassword = '';
  String _newPassword = '';

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

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

  Future<void> _updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');
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
          SnackBar(content: const Text('Contraseña actualizada', style: TextStyle(color: Colors.black)), backgroundColor: _gold),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw FirebaseAuthException(
          code: 'wrong-password',
          message: 'Contraseña actual incorrecta.',
        );
      }
      rethrow;
    }
  }

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
      if (changingPassword) await _updatePassword(_newPassword);

      if (_name != _initialName) {
        final userDoc = _firestore.collection('users').doc(user.uid);
        await userDoc.set({'name': _name}, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Perfil actualizado', style: TextStyle(color: Colors.black)), backgroundColor: _gold),
          );
        }
      }
      await _loadUserData();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  InputDecoration _getInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: _cardBg,
      prefixIcon: Icon(icon, color: Colors.white54),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _gold, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }

  Widget _buildButton({required String text, required VoidCallback onPressed, Color? bgColor, Color? textColor}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor ?? _gold,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(color: textColor ?? Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Ajustes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo/icon.png',
              height: 40,
              width: 40,
              errorBuilder: (_, __, ___) => Icon(Icons.star, color: _gold),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _gold))
          : RefreshIndicator(
              onRefresh: _loadUserData,
              color: _gold,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ),

                    // User Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _gold.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.person_pin, size: 64, color: _gold),
                          const SizedBox(height: 10),
                          Text(
                            _name.isNotEmpty ? _name : 'Usuario',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(_email, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Edit Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            initialValue: _name,
                            style: const TextStyle(color: Colors.white),
                            decoration: _getInputDecoration('Nombre', Icons.person_outline),
                            onChanged: (v) {
                              setState(() => _hasChanges = v.trim() != _initialName || _newPassword.isNotEmpty);
                            },
                            onSaved: (v) => _name = v!.trim(),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'El nombre no puede estar vacío';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _currentPasswordController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _getInputDecoration('Contraseña Actual', Icons.lock_outline),
                            obscureText: true,
                            onChanged: (v) => _currentPassword = v.trim(),
                            validator: (v) {
                              if (_newPassword.isNotEmpty && (v == null || v.isEmpty)) {
                                return 'Requerida para cambiar contraseña';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _newPasswordController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _getInputDecoration('Nueva Contraseña', Icons.vpn_key_outlined),
                            obscureText: true,
                            onChanged: (v) {
                              setState(() {
                                _newPassword = v.trim();
                                _hasChanges = (_name != _initialName) || _newPassword.isNotEmpty;
                              });
                            },
                            onSaved: (v) => _newPassword = v!,
                            validator: (v) {
                              if (v != null && v.isNotEmpty && v.length < 6) return 'Mínimo 6 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 40),

                          _buildButton(
                            text: 'Guardar cambios',
                            onPressed: _loading ? () {} : _updateProfile,
                          ),
                          const SizedBox(height: 20),
                          _buildButton(
                            text: 'Cerrar Sesión',
                            bgColor: _cardBg,
                            textColor: Colors.white,
                            onPressed: _logout,
                          ),
                          const SizedBox(height: 20),
                          _buildButton(
                            text: 'Eliminar cuenta',
                            bgColor: Colors.redAccent.withOpacity(0.1),
                            textColor: Colors.redAccent,
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteAccountPage())),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
