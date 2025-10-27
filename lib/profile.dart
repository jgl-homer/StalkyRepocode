import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'delete_account.dart'; // Asegúrate de que este archivo exista
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

  // ESTADOS NUEVOS PARA LA CONTRASEÑA
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
        _photoUrl =
            (data != null && data['photoUrl'] != null && data['photoUrl'] != '')
                ? data['photoUrl']
                : '';
        _imageFile = null;
        _newPassword = '';
        _currentPassword = ''; // Limpiar la contraseña actual al cargar datos
        _hasChanges = false;
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

  ImageProvider? _getProfileImage() {
    if (_imageFile != null) return FileImage(_imageFile!);
    if (_photoUrl.isNotEmpty) return NetworkImage(_photoUrl);
    return null;
  }

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
      // 1. Crear credencial para la re-autenticación (PASO CLAVE)
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPassword,
      );

      // 2. Re-autenticar al usuario para una operación sensible
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

    // Si se está cambiando la contraseña, asigna el valor guardado antes de verificar requiresUpdate
    final bool changingPassword = _newPassword.isNotEmpty;

    // Bandera para verificar si hay cambios de contraseña, nombre o foto.
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

      // 2. Subir imagen y actualizar Firestore (si se modificó nombre o foto)
      if (_hasChanges) {
        String? downloadUrl;

        if (_imageFile != null) {
          downloadUrl = await _uploadProfileImage(user.uid);
        }

        final userDoc = _firestore.collection('users').doc(user.uid);
        await userDoc.set({
          'name': _name,
          if (downloadUrl != null) 'photoUrl': downloadUrl,
        }, SetOptions(merge: true));

        // Refrescar datos y notificar
        await _loadUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente.')),
        );
      }

      setState(() => _hasChanges = false); // Restablecer estado de cambios
    } on FirebaseAuthException catch (e) {
      // Manejo específico de errores de autenticación
      String errorMessage = e.message ?? 'Error de autenticación: ${e.code}';

      // Muestra un SnackBar con el error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Otros errores
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

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadUserData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),
                  ],

                  // 1. ESTRUCTURA SUPERIOR: NOMBRE, CORREO y FOTO
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // A. Columna para Nombre y Correo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nombre',
                                style: TextStyle(color: Colors.white70)),
                            // **Nombre que se muestra en la parte superior**
                            Text(
                              _name.isNotEmpty ? _name : 'Cargando nombre...',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall!
                                  .copyWith(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 20),

                            const Text('Correo (No Editable)',
                                style: TextStyle(color: Colors.white70)),
                            // **Correo que se muestra en la parte superior**
                            Text(
                              _email,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // B. Contenedor de la Foto (a la derecha)
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.grey.shade700,
                              backgroundImage: _getProfileImage(),
                              child: _getProfileImage() == null
                                  ? const Icon(Icons.person,
                                      size: 70, color: Colors.white)
                                  : null,
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.cyanAccent,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 2. Formulario para campos de edición
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. CAMPO DE NOMBRE
                        TextFormField(
                          initialValue: _name,
                          decoration: darkInputDecoration.copyWith(
                            labelText: 'Nombre',
                          ),
                          // Esto permite capturar cambios en tiempo real
                          onChanged: (v) {
                            setState(() {
                              // Solo marcamos cambios si el nuevo valor es diferente del original
                              if (v.trim() != _name) {
                                _hasChanges = true;
                              }
                              _name = v.trim();
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
                        const SizedBox(height: 16),

                        // 2. CORREO (NO editable)
                        TextFormField(
                          initialValue: _email,
                          decoration: const InputDecoration(
                            labelText: 'Correo (No Editable)',
                            border: OutlineInputBorder(),
                            enabled: false, // Deshabilita la edición
                            fillColor: Color.fromARGB(255, 30, 30, 30),
                            filled: true,
                          ),
                          style: const TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 16),

                        // 3. CAMPO DE CONTRASEÑA ACTUAL (NUEVO)
                        TextFormField(
                          decoration: darkInputDecoration.copyWith(
                            labelText:
                                'Contraseña Actual (Necesaria si cambias la nueva)',
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

                        // 4. CAMBIAR CONTRASEÑA
                        TextFormField(
                          decoration: darkInputDecoration.copyWith(
                              labelText:
                                  'Nueva Contraseña (Dejar vacío para no cambiar)'),
                          obscureText: true,
                          onSaved: (v) => _newPassword =
                              v!, // El onSaved actualiza el estado _newPassword
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length < 6) {
                              return 'La contraseña debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 25),

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
                              : const Text('Guardar cambios'),
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
