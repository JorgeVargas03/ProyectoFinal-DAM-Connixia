import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class EventController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // --- LEER (READ): Obtener eventos donde participo ---
  Stream<QuerySnapshot> getMyEvents() {
    if (currentUid == null) return const Stream.empty();
    return _db
        .collection('events')
        .where('participants', arrayContains: currentUid)
        .orderBy('date', descending: false)
        .snapshots();
  }

  // --- CREAR (CREATE) ---
  Future<String?> createEvent({
    required String title,
    required String description,
    required DateTime date,
    required double lat,
    required double lng,
    required String address,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 'No estás autenticado';

    try {
      await _db.collection('events').add({
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
        'creatorId': user.uid, // <--- ESTO ES LA CLAVE DEL PERMISO
        'creatorName': user.displayName ?? 'Usuario',
        'location': {
          'lat': lat,
          'lng': lng,
          'address': address,
        },
        // El creador entra automáticamente como participante
        'participants': [user.uid],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('Error creando evento: $e');
      return 'Error al crear el evento';
    }
  }

  // --- BORRAR (DELETE): Solo si eres el creador ---
  Future<String?> deleteEvent(String eventId, String creatorId) async {
    if (currentUid != creatorId) {
      return 'No tienes permiso para borrar este evento';
    }

    try {
      await _db.collection('events').doc(eventId).delete();
      return null;
    } catch (e) {
      return 'Error al borrar evento';
    }
  }

  // --- EDITAR (UPDATE): Solo si eres el creador ---
  Future<String?> updateEvent(String eventId, String creatorId, Map<String, dynamic> data) async {
    if (currentUid != creatorId) {
      return 'No tienes permiso para editar este evento';
    }

    try {
      await _db.collection('events').doc(eventId).update(data);
      return null;
    } catch (e) {
      return 'Error al actualizar evento';
    }
  }

  // --- SALIRSE (LEAVE): Para invitados ---
  // Nota: Si el creador se sale, el evento podría quedar huérfano o podrías
  // decidir borrar el evento si el creador se va. Aquí solo lo sacamos de la lista.
  Future<String?> leaveEvent(String eventId) async {
    if (currentUid == null) return 'Error de sesión';

    try {
      await _db.collection('events').doc(eventId).update({
        'participants': FieldValue.arrayRemove([currentUid])
      });
      return null;
    } catch (e) {
      return 'Error al salir del evento';
    }
  }

  // --- UNIRSE (JOIN): Por si invitan mediante código o link en el futuro ---
  Future<String?> joinEvent(String eventId) async {
    if (currentUid == null) return 'Error de sesión';
    try {
      await _db.collection('events').doc(eventId).update({
        'participants': FieldValue.arrayUnion([currentUid])
      });
      return null;
    } catch (e) {
      return 'Error al unirse';
    }
  }
}