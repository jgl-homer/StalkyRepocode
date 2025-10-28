import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:io'; // ❌ Eliminada
// import 'package:firebase_storage/firebase_storage.dart'; // ❌ Eliminada
// import 'package:image_picker/image_picker.dart'; // ❌ Eliminada
import 'delete_account.dart'; // Asegúrate de que este archivo exista

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  // final _storage = FirebaseStorage.instance; // ❌ Eliminada

  String _name = '';
  String _email = '';
  // String _photoUrl = ''; // ❌ Eliminada
  String? _error;
  // File? _imageFile; // ❌ Eliminada
  bool _loading = false;
  bool _hasChanges = false;

  // ESTADOS para la contraseña
  String _currentPassword = '';
  String _newPassword = '';

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
        _email = user.email ?? 'No disponible';
        // ❌ Eliminada la lógica de photoUrl
        // _imageFile = null; // ❌ Eliminada
        _newPassword = '';
        _currentPassword = '';
        _hasChanges = false;
      });
    }
  }

  // ❌ Eliminado: Future<void> _pickImage() async {...}
  // ❌ Eliminado: Future<String?> _uploadProfileImage(String uid) async {...}
  // ❌ Eliminado: ImageProvider? _getProfileImage() {...}

  // Función para actualizar la contraseña (se mantiene, es vital para Firebase Auth)
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
      // 1. Crear credencial para la re-autenticación
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPassword,
      );

      // 2. Re-autenticar al usuario
      await user.reauthenticateWithCredential(credential);

      // 3. Si la re-autenticación fue exitosa, actualiza la contraseña
      await user.updatePassword(newPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada correctamente')),
        );
      }
      _newPassword = ''; // Limpiar el estado
      _currentPassword = ''; // Limpiar el estado
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

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    _formKey.currentState?.save();

    final bool changingPassword = _newPassword.isNotEmpty;

    // Bandera para verificar si hay cambios de contraseña o nombre.
    // _hasChanges se actualiza en el onChanged del TextFormField
    bool requiresUpdate = _hasChanges || changingPassword;

    if (!requiresUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios para guardar.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Actualizar Contraseña (si se modificó)
      if (changingPassword) {
        await _updatePassword(_newPassword);
      }

      // 2. Actualizar Nombre en Firestore (si se modificó)
      if (_hasChanges) {
        final userDoc = _firestore.collection('users').doc(user.uid);
        await userDoc.set({
          'name': _name,
        }, SetOptions(merge: true));

        // Refrescar datos y notificar
        await _loadUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente.')),
        );
      }

      setState(() => _hasChanges = false); // Restablecer estado de cambios
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

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      // Navega a la ruta de inicio de sesión y elimina todas las rutas anteriores.
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login', // 👈 ASEGÚRATE DE QUE TU RUTA DE LOGIN SE LLAME ASÍ
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definimos el tema oscuro para los input
    final darkInputDecoration = const InputDecoration().copyWith(
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white54),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.cyanAccent),
      ),
      hintStyle: const TextStyle(color: Colors.white38),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.black, // O el color de tu tema
        foregroundColor: Colors.white,
      ),
      body: Container(
        // Contenedor para aplicar un fondo oscuro o gradiente si lo deseas
        decoration: const BoxDecoration(
          color: Colors.black, // Color de fondo oscuro para el perfil
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadUserData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24), // Aumentado el padding
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Text(_error!,
                            style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 15),
                      ],

                      // 1. ESTRUCTURA SUPERIOR: NOMBRE y CORREO (SIN FOTO)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('¡Hola!',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 18)),
                          // **Nombre que se muestra en la parte superior**
                          Text(
                            _name.isNotEmpty ? _name : 'Cargando...',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge!
                                .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),

                          // **Correo que se muestra en la parte superior**
                          Text(
                            _email,
                            style: const TextStyle(
                                color: Colors.cyanAccent, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white38, height: 40),

                      // 2. Formulario para campos de edición
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. CAMPO DE NOMBRE
                            TextFormField(
                              initialValue: _name,
                              style: const TextStyle(color: Colors.white),
                              decoration: darkInputDecoration.copyWith(
                                labelText: 'Cambiar Nombre',
                                prefixIcon: const Icon(Icons.person_outline,
                                    color: Colors.white70),
                              ),
                              onChanged: (v) {
                                // Esto permite capturar cambios en tiempo real
                                setState(() {
                                  // Marcamos cambios si el valor es diferente del valor inicial (al cargar)
                                  if (v.trim() != _name) {
                                    _hasChanges = true;
                                  } else {
                                    // Comprobación más rigurosa para desmarcar si vuelve al original
                                    _hasChanges = (v.trim() != _name) ||
                                        _newPassword.isNotEmpty;
                                  }
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
                                  return 'Solo se permiten letras y espacios en el nombre';
                                }
                                if (v.trim().length < 2) {
                                  return 'El nombre debe tener al menos 2 letras';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 25),

                            // 2. CAMPO DE CONTRASEÑA ACTUAL
                            TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: darkInputDecoration.copyWith(
                                labelText:
                                    'Contraseña Actual (Necesaria si cambias la nueva)',
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: Colors.white70),
                              ),
                              obscureText: true,
                              onChanged: (v) => _currentPassword =
                                  v.trim(), // 👈 Guardar la actual
                              validator: (v) {
                                // Se valida si hay algo en la nueva, entonces se pide la actual
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
                              style: const TextStyle(color: Colors.white),
                              decoration: darkInputDecoration.copyWith(
                                  labelText:
                                      'Nueva Contraseña (Dejar vacío para no cambiar)',
                                  prefixIcon: const Icon(Icons.vpn_key_outlined,
                                      color: Colors.white70)),
                              obscureText: true,
                              onChanged: (v) {
                                setState(() {
                                  // Marcamos o desmarcamos cambios según la nueva contraseña
                                  _hasChanges = _name != _name || v.isNotEmpty;
                                  _newPassword = v.trim();
                                });
                              },
                              onSaved: (v) => _newPassword =
                                  v!, // El onSaved actualiza el estado _newPassword
                              validator: (v) {
                                if (v != null && v.isNotEmpty && v.length < 6) {
                                  return 'La contraseña debe tener al menos 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 35),

                            // Botón GUARDAR CAMBIOS
                            ElevatedButton(
                              onPressed: _loading ? null : _updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.black)
                                  : const Text(
                                      'Guardar cambios',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                            const SizedBox(height: 25),

                            // Botón CERRAR SESIÓN
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

                            // Botón ELIMINAR CUENTA
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
                                      builder: (_) =>
                                          const DeleteAccountPage()),
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
              ),
      ),
    );
  }
}
