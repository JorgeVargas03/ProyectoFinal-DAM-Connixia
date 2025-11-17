// file: 'lib/screens/profile_page.dart'
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:characters/characters.dart';
import '../controllers/auth_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authController = AuthController();
  final _displayNameCtrl = TextEditingController();
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _displayNameCtrl.text = _user?.displayName ?? '';
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

  Future<void> _saveProfile() async {
    final newName = _displayNameCtrl.text.trim();
    if (_user == null || newName.isEmpty) return;

    await _user!.updateDisplayName(newName);
    await FirebaseAuth.instance.currentUser?.reload();

    setState(() {
      _user = FirebaseAuth.instance.currentUser; // refresca el estado local
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 44,
              child: Text(
                _userInitial(u),
                style: const TextStyle(fontSize: 32),
              ),
            ),
            const SizedBox(height: 12),
            Text(u?.email ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: _displayNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre visible',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _authController.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
