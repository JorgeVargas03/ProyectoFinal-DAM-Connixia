import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' show cos, pi, sin, atan2, sqrt;
import '../services/notification_service.dart';

class EventController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

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

  // --- LEER (READ): Obtener TODOS los eventos públicos activos ---
  Stream<QuerySnapshot> getAllPublicEvents() {
    return _db
        .collection('events')
        .where('status', isEqualTo: 'active')
        .orderBy('date', descending: false)
        .snapshots();
  }

  // --- LEER (READ): Obtener eventos públicos cercanos (filtro por coordenadas aproximadas) ---
  Stream<QuerySnapshot> getNearbyEvents({
    required double userLat,
    required double userLng,
    double radiusInKm = 50, // Radio de búsqueda por defecto 50km
  }) {
    // Aproximación simple: filtrar por rango de coordenadas
    // Para mayor precisión, usar GeoFlutterFire o similar
    final latDelta = radiusInKm / 111.0; // 1 grado lat ≈ 111 km
    final lngDelta = radiusInKm / (111.0 * cos(userLat * pi / 180));

    return _db
        .collection('events')
        .where('status', isEqualTo: 'active')
        .where('location.lat', isGreaterThan: userLat - latDelta)
        .where('location.lat', isLessThan: userLat + latDelta)
        .orderBy('location.lat')
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

  // --- UNIRSE (JOIN): Para unirse a eventos de otros usuarios ---
  Future<String?> joinEvent(String eventId) async {
    if (currentUid == null) return 'Error de sesión';
    
    try {
      final eventDoc = await _db.collection('events').doc(eventId).get();
      
      if (!eventDoc.exists) return 'El evento no existe';
      
      final data = eventDoc.data() as Map<String, dynamic>;
      final creatorId = data['creatorId'];
      final participants = List.from(data['participants'] ?? []);
      
      // Validar que no sea el creador
      if (currentUid == creatorId) {
        return 'No puedes unirte a tu propio evento';
      }
      
      // Validar que no esté ya unido
      if (participants.contains(currentUid)) {
        return 'Ya estás participando en este evento';
      }
      
      // Unirse al evento
      await _db.collection('events').doc(eventId).update({
        'participants': FieldValue.arrayUnion([currentUid])
      });
      
      // Enviar notificación al creador
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
      return 'Error al unirse';
    }
  }

  // --- CALCULAR DISTANCIA entre dos puntos (Haversine formula) ---
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371; // Radio de la Tierra en km
    
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c; // Distancia en kilómetros
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  // --- OBTENER INFORMACIÓN DE PARTICIPANTES ---
  Future<List<Map<String, dynamic>>> getParticipantsInfo(List<String> participantIds) async {
    if (participantIds.isEmpty) return [];
    
    try {
      final users = <Map<String, dynamic>>[];
      
      // Firestore limita 'in' queries a 10 elementos, así que procesamos en lotes
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
}