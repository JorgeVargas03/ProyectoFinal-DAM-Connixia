// dart
import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import 'home_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authCtrl = AuthController();
  bool _loading = false;

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onRegister() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pass != confirm) {
      _showMessage('Las contraseñas no coinciden.');
      return;
    }

    setState(() => _loading = true);
    final err = await _authCtrl.registerWithEmail(email: email, password: pass);
    setState(() => _loading = false);

    if (err == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      _showMessage(err);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Correo')),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
            TextField(controller: _confirmCtrl, decoration: const InputDecoration(labelText: 'Confirmar contraseña'), obscureText: true),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _onRegister,
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Registrarme'),
            ),
          ],
        ),
      ),
    );
  }
}
