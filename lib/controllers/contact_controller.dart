import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // OBTENER CONTACTOS
  Stream<List<Map<String, dynamic>>> getUserContactsStream() {
    if (currentUid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('contacts')
        .snapshots() // <--- Esto hace la magia del auto-refresh
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            // Aseguramos que el UID venga en el mapa, si no está, usamos el ID del documento
            data['uid'] = data['uid'] ?? doc.id;
            return data;
          }).toList();
        });
  }

  // ELIMINAR CONTACTO
  Future<void> deleteContact(String targetUid) async {
    if (currentUid == null) return;

    try {
      // Borrar de MI lista
      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('contacts')
          .doc(targetUid)
          .delete();

      // Borrarme de SU lista para que sea recíproco
      await _firestore
          .collection('users')
          .doc(targetUid)
          .collection('contacts')
          .doc(currentUid)
          .delete();
    } catch (e) {
      print('Error al eliminar contacto: $e');
    }
  }

  // ALTERNAR FAVORITO (TOGGLE)
  Future<void> toggleFavorite(String targetUid) async {
    if (currentUid == null) return;

    final contactRef = _firestore
        .collection('users')
        .doc(currentUid)
        .collection('contacts')
        .doc(targetUid);

    try {
      final doc = await contactRef.get();
      if (doc.exists) {
        bool currentStatus = doc.data()?['isFavorite'] ?? false;
        await contactRef.update({'isFavorite': !currentStatus});
      }
    } catch (e) {
      print('Error al cambiar favorito: $e');
    }
  }

  // BUSCAR USUARIOS POR NOMBRE
  Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
    if (query.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      final List<Map<String, dynamic>> users = [];
      for (var doc in snapshot.docs) {
        if (doc.id != currentUid) {
          // Inyectamos el ID por si acaso
          var userData = doc.data();
          userData['uid'] = doc.id;
          users.add(userData);
        }
      }
      return users;
    } catch (e) {
      print('Error buscando usuarios: $e');
      return [];
    }
  }

  // VERIFICAR SI ES CONTACTO
  Future<bool> isFriend(String targetUid) async {
    if (currentUid == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(currentUid)
        .collection('contacts')
        .doc(targetUid)
        .get();

    return doc.exists;
  }

  // --- ENVIAR SOLICITUD DE AMISTAD ---
  Future<void> sendFriendRequest(String targetUid) async {
    if (currentUid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(targetUid)
          .collection('friend_requests')
          .doc(currentUid)
          .set({
            'fromUid': currentUid,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
    } catch (e) {
      print('Error enviando solicitud: $e');
      throw e; // Relanzamos para manejarlo en la UI si queremos
    }
  }
}
