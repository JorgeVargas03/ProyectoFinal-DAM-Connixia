import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:characters/characters.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../controllers/auth_controller.dart';
import '../services/image_upload_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authController = AuthController();
  final _displayNameCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  User? _user;
  bool _isUpdatingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    setState(() {
      _user = FirebaseAuth.instance.currentUser;
      _displayNameCtrl.text = _user?.displayName ?? '';
    });
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    super.dispose();
  }

  String _userInitial(User? u) {
    final name = (u?.displayName ?? '').trim();
    final email = (u?.email ?? '').trim();
    final src = name.isNotEmpty ? name : (email.isNotEmpty ? email : 'U');
    return src.characters.first.toUpperCase();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUpdatingImage = true);

      if (_user == null) {
        _showSnackBar('Error: Usuario no autenticado', isError: true);
        return;
      }

      final filename = 'profile_${_user!.uid}_${DateTime.now().millisecondsSinceEpoch}';

      final result = await ImageUploadService.uploadProfileImage(
        File(pickedFile.path),
        filename,
      );

      if (result['success']) {
        await _user!.updatePhotoURL(result['profileImageUrl']);
        await FirebaseAuth.instance.currentUser?.reload();

        _loadUser();

        _showSnackBar('Foto de perfil actualizada');
      } else {
        _showSnackBar(result['message'], isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isUpdatingImage = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            if (_user?.photoURL != null && _user!.photoURL!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar foto', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfileImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeProfileImage() async {
    if (_user == null) return;

    setState(() => _isUpdatingImage = true);

    try {
      await _user!.updatePhotoURL(null);
      await FirebaseAuth.instance.currentUser?.reload();

      _loadUser();

      _showSnackBar('Foto de perfil eliminada');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isUpdatingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    final newName = _displayNameCtrl.text.trim();
    if (_user == null || newName.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await _user!.updateDisplayName(newName);
      await FirebaseAuth.instance.currentUser?.reload();

      _loadUser();

      _showSnackBar('Perfil actualizado');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final hasPhoto = u?.photoURL != null && u!.photoURL!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: hasPhoto ? NetworkImage(u.photoURL!) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                    _userInitial(u),
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
                if (_isUpdatingImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUpdatingImage ? null : _showImageSourceDialog,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              u?.displayName ?? 'Usuario',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              u?.email ?? '',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _displayNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre visible',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar cambios'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _authController.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
