import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'delete_account.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String _name = '';
  String _email = '';
  String _photoUrl = '';
  String? _error;
  File? _imageFile;
  bool _loading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      setState(() {
        _name = data?['name'] ?? '';
        _email = user.email ?? '';
        _photoUrl =
            (data != null && data['photoUrl'] != null && data['photoUrl'] != '')
                ? data['photoUrl']
                : '';
        _imageFile = null;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _hasChanges = true;
      });
    }
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_imageFile == null) return null;
    final ref = _storage.ref().child('profile_images/$uid.jpg');
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  ImageProvider _getProfileImage() {
    if (_imageFile != null) return FileImage(_imageFile!);
    if (_photoUrl.isNotEmpty) return NetworkImage(_photoUrl);
    return const AssetImage('assets/avatar_placeholder.png');
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios que guardar.')),
      );
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    _formKey.currentState?.save();

    setState(() => _loading = true);

    try {
      String? downloadUrl;

      if (_imageFile != null) {
        downloadUrl = await _uploadProfileImage(user.uid);
      }

      final userDoc = _firestore.collection('users').doc(user.uid);
      await userDoc.set({
        'name': _name,
        if (downloadUrl != null) 'photoUrl': downloadUrl,
      }, SetOptions(merge: true));

      setState(() => _hasChanges = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente.')),
      );

      await _loadUserData();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Nota: Aquí se requiere una reautenticación para un entorno de producción,
      // pero para simplificar, a menudo se omite en ejemplos si el usuario está activo.
      // Aquí está el código para actualizar el email sin pedir la contraseña de nuevo
      // (solo se requiere si la sesión ha sido reciente, menos de 5 minutos):
      await user.verifyBeforeUpdateEmail(newEmail);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Correo de verificación enviado al nuevo email.')),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    }
  }

  Future<void> _updatePassword(String newPassword) async {
    try {
      // Similar al email, puede requerir reautenticación si la sesión no es reciente.
      await _auth.currentUser!.updatePassword(newPassword);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  // 🔑 FUNCIÓN PARA CERRAR SESIÓN
  Future<void> _logout() async {
    // 1. Cierra la sesión de Firebase
    await _auth.signOut();

    // 2. Navega al inicio (LoginPage a través del StreamBuilder en main.dart)
    if (mounted) {
      // Usar `pushReplacementNamed` o `pushAndRemoveUntil` es ideal,
      // pero si main.dart usa un StreamBuilder, un simple pop o push ya basta
      // porque el StreamBuilder detectará el cambio de estado.
      // Para mayor seguridad y limpiar el historial:
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (context) =>
                const Placeholder()), // Usamos un placeholder si el root es un StreamBuilder
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadUserData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),
                  ],
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundImage: _getProfileImage(),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.cyanAccent,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child:
                              const Icon(Icons.camera_alt, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          initialValue: _name,
                          decoration:
                              const InputDecoration(labelText: 'Nombre'),
                          onChanged: (_) => _hasChanges = true,
                          onSaved: (v) => _name = v!.trim(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _email,
                          decoration:
                              const InputDecoration(labelText: 'Correo'),
                          onFieldSubmitted: (value) {
                            if (value != _email) _updateEmail(value);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Nueva contraseña'),
                          obscureText: true,
                          onFieldSubmitted: _updatePassword,
                        ),
                        const SizedBox(height: 25),
                        ElevatedButton(
                          onPressed: _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('Guardar cambios'),
                        ),
                        const SizedBox(height: 25),

                        // 🔑 BOTÓN DE CERRAR SESIÓN
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white70),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _logout,
                          child: const Text('Cerrar Sesión',
                              style: TextStyle(color: Colors.white70)),
                        ),

                        const SizedBox(height: 25),

                        // BOTÓN DE ELIMINAR CUENTA (manteniendo el estilo original)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DeleteAccountPage()),
                            );
                          },
                          child: const Text('Eliminar cuenta',
                              style: TextStyle(color: Colors.white)),
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
