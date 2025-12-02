import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' show cos, pi, sin, atan2, sqrt;
import '../services/notification_service.dart';

class EventController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // FUNCIÓN DE MANTENIMIENTO
  Future<String> updateOldEventsToPublic() async {
    try {
      final snapshot = await _db
          .collection('events')
          .where('privacy', isEqualTo: null)
          .get();

      if (snapshot.docs.isEmpty) {
        return "¡Genial! No hay eventos antiguos que necesiten ser actualizados.";
      }

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'privacy': 'public'});
      }
      await batch.commit();
      return "Éxito: Se han actualizado ${snapshot.docs.length} eventos antiguos a 'público'.";
    } catch (e) {
      debugPrint("Error actualizando eventos antiguos: $e");
      return "Ocurrió un error durante la actualización: $e";
    }
  }

  String? get currentUid => _auth.currentUser?.uid;

  // OBTENER IDS DE CONTACTOS
  // Lee los contactos desde el array 'contacts' en el documento del usuario.
  Future<List<String>> _getContactIds() async {
    if (currentUid == null) return [];
    try {
      final userDoc = await _db.collection('users').doc(currentUid).get();
      if (!userDoc.exists) return [];
      // Lee el array 'contacts', si no existe, devuelve una lista vacía.
      final contacts = List<String>.from(userDoc.data()?['contacts'] ?? []);
      return contacts;
    } catch (e) {
      debugPrint("Error obteniendo contactos: $e");
      return [];
    }
  }

  // LEER EVENTOS DONDE PARTICIPO
  Stream<QuerySnapshot> getMyEvents() {
    if (currentUid == null) return const Stream.empty();
    return _db
        .collection('events')
        .where('participants', arrayContains: currentUid)
        .orderBy('date', descending: false)
        .snapshots();
  }

  // LEER TODOS LOS EVENTOS VISIBLES
  // Aplica el filtrado de semiprivados y privados en el cliente.
  // Públicos: todos lo ven
  // Semiprivados: solo contactos del creador
  // Privados: solo el creador (no se muestran aquí para otros usuarios)
  Stream<QuerySnapshot> getAllVisibleEvents() {
    if (currentUid == null) return const Stream.empty();
    final controller = StreamController<QuerySnapshot>();

    // Escuchamos el stream original de Firestore (todos los eventos activos)
    _db
        .collection('events')
        .where('status', isEqualTo: 'active')
        .orderBy('date', descending: false)
        .snapshots()
        .listen(
          (snapshot) async {
            final myContacts = await _getContactIds();
            final filteredDocs = _filterVisibleEvents(
              snapshot.docs,
              myContacts,
            );

            // Creamos un nuevo QuerySnapshot "falso" con los documentos filtrados
            final newSnapshot = _createFakeQuerySnapshot(
              filteredDocs,
              snapshot.metadata,
            );
            controller.add(newSnapshot);
          },
          onError: (error) {
            controller.addError(error);
          },
        );

    return controller.stream;
  }

  // LEER EVENTOS VISIBLES CERCANOS
  // Aplica el filtrado de semiprivados y privados en el cliente.
  Stream<QuerySnapshot> getNearbyEvents({
    required double userLat,
    required double userLng,
    double radiusInKm = 50,
  }) {
    if (currentUid == null) return const Stream.empty();
    final controller = StreamController<QuerySnapshot>();

    final latDelta = radiusInKm / 111.0;
    final lngDelta = radiusInKm / (111.0 * cos(userLat * pi / 180));

    // Escuchamos el stream original de Firestore (todos los eventos activos en el área)
    _db
        .collection('events')
        .where('status', isEqualTo: 'active')
        .where('location.lat', isGreaterThan: userLat - latDelta)
        .where('location.lat', isLessThan: userLat + latDelta)
        .orderBy('location.lat')
        .orderBy('date', descending: false)
        .snapshots()
        .listen(
          (snapshot) async {
            final myContacts = await _getContactIds();
            final filteredDocs = _filterVisibleEvents(
              snapshot.docs,
              myContacts,
            );

            // Creamos un nuevo QuerySnapshot "falso" con los documentos filtrados
            final newSnapshot = _createFakeQuerySnapshot(
              filteredDocs,
              snapshot.metadata,
            );
            controller.add(newSnapshot);
          },
          onError: (error) {
            controller.addError(error);
          },
        );

    return controller.stream;
  }

  // CREAR (CREATE)
  Future<String?> createEvent({
    required String title,
    required String description,
    required DateTime date,
    required double lat,
    required double lng,
    required String address,
    required String privacy,
    int? maxParticipants, // null = sin límite
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 'No estás autenticado';

    try {
      final eventData = {
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
        'creatorId': user.uid,
        'creatorName': user.displayName ?? 'Usuario',
        'location': {'lat': lat, 'lng': lng, 'address': address},
        'participants': [user.uid],
        'status': 'active',
        'privacy': privacy,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Solo agregar maxParticipants si tiene un valor
      if (maxParticipants != null) {
        eventData['maxParticipants'] = maxParticipants;
      }

      await _db.collection('events').add(eventData);
      return null;
    } catch (e) {
      debugPrint('Error creando evento: $e');
      return 'Error al crear el evento';
    }
  }

  // BORRAR (DELETE)
  Future<String?> deleteEvent(String eventId, String creatorId) async {
    if (currentUid != creatorId)
      return 'No tienes permiso para borrar este evento';
    try {
      await _db.collection('events').doc(eventId).delete();
      return null;
    } catch (e) {
      return 'Error al borrar evento';
    }
  }

  // EDITAR (UPDATE)
  Future<String?> updateEvent(
    String eventId,
    String creatorId,
    Map<String, dynamic> data,
  ) async {
    if (currentUid != creatorId)
      return 'No tienes permiso para editar este evento';
    try {
      await _db.collection('events').doc(eventId).update(data);
      return null;
    } catch (e) {
      return 'Error al actualizar evento';
    }
  }

  // SALIRSE (LEAVE)
  Future<String?> leaveEvent(String eventId) async {
    if (currentUid == null) return 'Error de sesión';
    try {
      await _db.collection('events').doc(eventId).update({
        'participants': FieldValue.arrayRemove([currentUid]),
      });
      return null;
    } catch (e) {
      return 'Error al salir del evento';
    }
  }

  // UNIRSE (JOIN)
  Future<String?> joinEvent(String eventId) async {
    if (currentUid == null) return 'Error de sesión';
    try {
      final eventDocRef = _db.collection('events').doc(eventId);
      final eventDoc = await eventDocRef.get();
      if (!eventDoc.exists) return 'El evento no existe';

      final data = eventDoc.data() as Map<String, dynamic>;
      final creatorId = data['creatorId'];
      final participants = List.from(data['participants'] ?? []);
      final invited = List.from(data['invited'] ?? []);
      final privacy = data['privacy'] ?? 'public';
      final maxParticipants = data['maxParticipants'] as int?;

      if (currentUid == creatorId) return 'No puedes unirte a tu propio evento';
      if (participants.contains(currentUid))
        return 'Ya estás participando en este evento';

      // Validar límite de participantes
      if (maxParticipants != null && participants.length >= maxParticipants) {
        return 'Este evento ha alcanzado su límite de $maxParticipants participantes';
      }

      // Verificar permisos según privacidad
      switch (privacy) {
        case 'public':
          // Público: cualquiera puede unirse
          break;

        case 'semi-private':
          // Semiprivado: solo contactos del creador
          final creatorDoc = await _db.collection('users').doc(creatorId).get();
          if (!creatorDoc.exists)
            return 'Error: No se pudo verificar la privacidad del evento.';
          final creatorContacts = List<String>.from(
            creatorDoc.data()?['contacts'] ?? [],
          );
          if (!creatorContacts.contains(currentUid)) {
            return 'Este evento es solo para contactos del organizador.';
          }
          break;

        case 'private':
          // Privado: solo con invitación
          if (!invited.contains(currentUid)) {
            return 'Este evento es privado. Necesitas una invitación para unirte.';
          }
          break;

        default:
          break;
      }

      // Agregar al evento
      await eventDocRef.update({
        'participants': FieldValue.arrayUnion([currentUid]),
        // Si fue invitado, lo removemos de la lista de invitados
        if (invited.contains(currentUid))
          'invited': FieldValue.arrayRemove([currentUid]),
      });

      // Notificar al creador
      final currentUser = _auth.currentUser;
      final joinerName = currentUser?.displayName ?? 'Un usuario';
      final eventTitle = data['title'] ?? 'un evento';
      await _notificationService.notifyEventJoin(
        eventId: eventId,
        eventTitle: eventTitle,
        creatorId: creatorId,
        joinerName: joinerName,
      );
      return null;
    } catch (e) {
      debugPrint('Error al unirse: $e');
      return 'Ocurrió un error al intentar unirse';
    }
  }

  // MÉTODOS DE AYUDA

  // Lógica de filtrado reutilizable
  // Públicos: todos lo ven
  // Semiprivados: solo contactos del creador (bidireccional)
  // Privados: solo el creador
  List<QueryDocumentSnapshot> _filterVisibleEvents(
    List<QueryDocumentSnapshot> docs,
    List<String> myContacts,
  ) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final privacy = data['privacy'] ?? 'public';
      final creatorId = data['creatorId'];

      // Público: todos lo ven
      if (privacy == 'public') return true;

      // Privado: solo el creador lo ve
      if (privacy == 'private') return creatorId == currentUid;

      // Semiprivado: el creador lo ve SIEMPRE, o lo ven sus contactos
      if (privacy == 'semi-private') {
        if (creatorId == currentUid) return true; // El creador siempre lo ve
        // Verificar si soy contacto del creador (bidireccional)
        return myContacts.contains(creatorId);
      }

      return false;
    }).toList();
  }

  // Utilidad para crear un QuerySnapshot "falso" y mantener compatibilidad
  QuerySnapshot _createFakeQuerySnapshot(
    List<QueryDocumentSnapshot> docs,
    SnapshotMetadata metadata,
  ) {
    return _FakeQuerySnapshot(docs, metadata);
  }

  // CÁLCULO DE DISTANCIA
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double d) => d * pi / 180;

  // OBTENER INFO DE PARTICIPANTES
  Future<List<Map<String, dynamic>>> getParticipantsInfo(
    List<String> participantIds,
  ) async {
    if (participantIds.isEmpty) return [];
    try {
      final users = <Map<String, dynamic>>[];
      for (var i = 0; i < participantIds.length; i += 10) {
        final batch = participantIds.skip(i).take(10).toList();
        final snapshot = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (var doc in snapshot.docs) {
          users.add({
            'uid': doc.id,
            'displayName': doc.data()['displayName'] ?? 'Usuario',
            'photoURL': doc.data()['photoURL'],
            'email': doc.data()['email'],
          });
        }
      }
      return users;
    } catch (e) {
      debugPrint('Error obteniendo participantes: $e');
      return [];
    }
  }

  // MARCAR COMO "EN CAMINO"
  Future<String?> setOnTheWay(String eventId, bool isOnTheWay) async {
    if (currentUid == null) return 'Error de sesión';
    try {
      await _db
          .collection('events')
          .doc(eventId)
          .collection('onTheWay')
          .doc(currentUid)
          .set({
            'userId': currentUid,
            'startedAt': FieldValue.serverTimestamp(),
            'isActive': isOnTheWay,
          });
      return null;
    } catch (e) {
      debugPrint('Error marcando en camino: $e');
      return 'Error al actualizar estado';
    }
  }

  // OBTENER USUARIOS "EN CAMINO"
  Stream<QuerySnapshot> getOnTheWayUsers(String eventId) {
    return _db
        .collection('events')
        .doc(eventId)
        .collection('onTheWay')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }
}

// Clase de ayuda para crear un QuerySnapshot falso
class _FakeQuerySnapshot implements QuerySnapshot {
  @override
  final List<QueryDocumentSnapshot> docs;

  @override
  final SnapshotMetadata metadata;

  @override
  List<DocumentChange> get docChanges => throw UnimplementedError();

  @override
  int get size => docs.length;

  _FakeQuerySnapshot(this.docs, this.metadata);
}
