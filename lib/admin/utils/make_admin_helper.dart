// Script auxiliar para configurar el primer administrador
// INSTRUCCIONES:
// 1. Copia este código en cualquier parte de tu app (por ejemplo, en un botón temporal)
// 2. Ejecuta la función makeCurrentUserAdmin() cuando estés logueado con el usuario que quieres hacer admin
// 3. Verifica en Firebase Console que el campo 'role' se haya actualizado
// 4. ELIMINA este código después de configurar tu primer admin

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> makeCurrentUserAdmin() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print('[ERROR] No hay usuario autenticado');
    return;
  }

  try {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'role': 'admin',
    });

    print('[OK] Usuario convertido en administrador exitosamente');
    print('   Email: ${user.email}');
    print('   UID: ${user.uid}');
    print('   Reinicia la app para ver el botón de administración');
  } catch (e) {
    print('[ERROR] Error al actualizar el rol: $e');
  }
}

// OPCIÓN 2: Si el usuario no tiene el campo 'role', usa esto en su lugar:
Future<void> addAdminRoleToCurrentUser() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print('[ERROR] No hay usuario autenticado');
    return;
  }

  try {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'role': 'admin',
    }, SetOptions(merge: true));

    print('[OK] Rol de administrador agregado exitosamente');
    print('   Email: ${user.email}');
    print('   UID: ${user.uid}');
    print('   Reinicia la app para ver el botón de administración');
  } catch (e) {
    print('[ERROR] Error al agregar el rol: $e');
  }
}

// OPCIÓN 3: Función para verificar el rol actual
Future<void> checkCurrentUserRole() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print('[ERROR] No hay usuario autenticado');
    return;
  }

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      print('[WARN] El documento de usuario no existe en Firestore');
      return;
    }

    final data = doc.data();
    final role = data?['role'] ?? 'no definido';

    print('Información del usuario actual:');
    print('   Email: ${user.email}');
    print('   UID: ${user.uid}');
    print('   Rol actual: $role');

    if (role == 'admin') {
      print('   [OK] Este usuario ES administrador');
    } else {
      print('   Este usuario NO es administrador');
    }
  } catch (e) {
    print('[ERROR] Error al verificar el rol: $e');
  }
}

// EJEMPLO DE USO:
// En tu código, puedes agregar un botón temporal así:
/*
FloatingActionButton(
  onPressed: () async {
    await makeCurrentUserAdmin();
    // O usa: await checkCurrentUserRole();
  },
  child: const Icon(Icons.admin_panel_settings),
)
*/
