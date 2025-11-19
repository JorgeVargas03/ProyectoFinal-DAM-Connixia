import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proyectofinal_connixia/screens/sign_up_page.dart';
import '../controllers/auth_controller.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  bool _darkMode = false;
  final _authController = AuthController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apariencia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            SwitchListTile(
              title: Text('Modo oscuro'),
              value: _darkMode,
              onChanged: (v) {
                setState(() => _darkMode = v);
                // Aquí falta setState global o similar
                // para activar el modo oscuro en toda la app.
              },
            ),
            Divider(height: 32),
            Text(
              'Cuenta',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.lock_reset),
              title: Text('Cambiar contraseña'),
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && user.email != null) {
                  await _authController.sendPasswordReset(user.email!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Se envió un correo para restablecer contraseña.')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Eliminar cuenta', style: TextStyle(color: Colors.red)),
              onTap: () async {
                _confirmDeleteAccount(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar cuenta'),
        content: Text('¿Seguro que quieres eliminar tu cuenta? Esta acción es permanente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              final result = await _authController.deleteAccount();

              if (result == null) {
                if (mounted) {
                  Navigator.of(context).pop(); // Cierra la configuración
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignUpPage()),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(result)));
                }
              }
            },

            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
