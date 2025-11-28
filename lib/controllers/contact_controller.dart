import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // --- 1. AGREGAR CONTACTO AL ARRAY ---
  Future<String?> addContact(String targetUid) async {
    if (currentUid == null) return 'Error de sesión';

    final userRef = _firestore.collection('users').doc(currentUid);

    try {
      // Usamos una transacción para asegurarnos de no sobrescribir datos si dos personas agregan a la vez
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) return 'Usuario no encontrado';

        // Obtenemos la lista actual o una vacía si es null
        List<dynamic> currentContacts = snapshot.data()?['contacts'] ?? [];

        // Verificar si ya existe
        bool exists = currentContacts.any((c) => c['uid'] == targetUid);
        if (exists) {
          return 'Este usuario ya está en tus contactos.';
        }

        // Crear el nuevo objeto de contacto
        final newContact = {
          'uid': targetUid,
          'isFavorite': false, // Por defecto no es favorito
          'addedAt': DateTime.now().toIso8601String(), // Usamos String para evitar problemas en arrays
        };

        // Agregar al array local y actualizar en Firestore
        currentContacts.add(newContact);
        transaction.update(userRef, {'contacts': currentContacts});

        return null; // Éxito
      });
    } catch (e) {
      print(e);
      return 'Error al agregar contacto';
    }
  }

  // --- 2. ALTERNAR FAVORITO (TOGGLE) ---
  // Aquí está el truco: Bajamos la lista, buscamos el índice, cambiamos y subimos.
  Future<void> toggleFavorite(String targetUid) async {
    if (currentUid == null) return;
    final userRef = _firestore.collection('users').doc(currentUid);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return;

        List<dynamic> contacts = List.from(snapshot.data()?['contacts'] ?? []);

        // Buscamos el índice del contacto
        int index = contacts.indexWhere((c) => c['uid'] == targetUid);

        if (index != -1) {
          // Modificamos el estado de isFavorite
          bool currentStatus = contacts[index]['isFavorite'] ?? false;
          contacts[index]['isFavorite'] = !currentStatus;

          // Actualizamos la base de datos con la lista modificada
          transaction.update(userRef, {'contacts': contacts});
        }
      });
    } catch (e) {
      print('Error al cambiar favorito: $e');
    }
  }

  // --- 3. OBTENER CONTACTOS PARA LA UI ---
  // Como es un array dentro del documento del usuario, escuchamos el documento del usuario.
  Stream<List<Map<String, dynamic>>> getUserContactsStream() {
    if (currentUid == null) return const Stream.empty();

    return _firestore.collection('users').doc(currentUid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null || !data.containsKey('contacts')) {
        return [];
      }
      // Convertimos el array dinámico a una lista de Mapas
      return List<Map<String, dynamic>>.from(data['contacts']);
    });
  }

  // --- 4. BUSCAR USUARIOS POR NOMBRE ---
  Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
    if (query.isEmpty) return [];

    try {
      // Truco de Firestore para buscar "empieza con..."
      // Ejemplo: Busca 'A' -> Trae 'Ana', 'Alberto', etc.
      final snapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10) // Limitamos a 10 para no gastar lecturas a lo loco
          .get();

      // Filtramos para no mostrar al propio usuario logueado
      final List<Map<String, dynamic>> users = [];
      for (var doc in snapshot.docs) {
        if (doc.id != currentUid) {
          users.add(doc.data());
        }
      }
      return users;
    } catch (e) {
      print('Error buscando usuarios: $e');
      return [];
    }
  }

  // Método auxiliar para saber si un UID ya está en mi lista local
  bool isContact(String targetUid, List<Map<String, dynamic>> myContacts) {
    return myContacts.any((c) => c['uid'] == targetUid);
  }

}