import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // VERIFICAR SI EL USUARIO ACTUAL ES ADMIN
  Future<bool> isAdmin() async {
    if (currentUid == null) return false;

    try {
      final userDoc = await _db.collection('users').doc(currentUid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data();
      return userData?['role'] == 'admin';
    } catch (e) {
      debugPrint('Error verificando rol de admin: $e');
      return false;
    }
  }

  // OBTENER ESTADÍSTICAS GENERALES
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      // Contar usuarios totales
      final usersSnapshot = await _db.collection('users').count().get();
      final totalUsers = usersSnapshot.count;

      // Contar eventos activos
      final activeEventsSnapshot = await _db
          .collection('events')
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      final activeEvents = activeEventsSnapshot.count;

      // Contar todos los eventos
      final allEventsSnapshot = await _db.collection('events').count().get();
      final totalEvents = allEventsSnapshot.count;

      // Contar notificaciones totales
      final notificationsSnapshot = await _db
          .collection('notifications')
          .count()
          .get();
      final totalNotifications = notificationsSnapshot.count;

      return {
        'totalUsers': totalUsers,
        'activeEvents': activeEvents,
        'totalEvents': totalEvents,
        'totalNotifications': totalNotifications,
      };
    } catch (e) {
      debugPrint('Error obteniendo estadísticas: $e');
      return {
        'totalUsers': 0,
        'activeEvents': 0,
        'totalEvents': 0,
        'totalNotifications': 0,
      };
    }
  }

  // OBTENER TODOS LOS USUARIOS (CON PAGINACIÓN)
  Stream<QuerySnapshot> getAllUsers({int limit = 50}) {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  // OBTENER TODOS LOS EVENTOS (CON PAGINACIÓN)
  Stream<QuerySnapshot> getAllEvents({int limit = 50}) {
    return _db
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  // CAMBIAR ROL DE USUARIO (ADMIN/USER)
  Future<String?> changeUserRole(String userId, String newRole) async {
    if (!await isAdmin()) {
      return 'No tienes permisos de administrador';
    }

    if (userId == currentUid) {
      return 'No puedes cambiar tu propio rol';
    }

    if (newRole != 'admin' && newRole != 'user') {
      return 'Rol inválido. Debe ser "admin" o "user"';
    }

    try {
      await _db.collection('users').doc(userId).update({
        'role': newRole,
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      });
      return null; // Éxito
    } catch (e) {
      debugPrint('Error cambiando rol de usuario: $e');
      return 'Error al cambiar el rol: $e';
    }
  }

  // ELIMINAR EVENTO (SOLO ADMIN)
  Future<String?> deleteEvent(String eventId) async {
    if (!await isAdmin()) {
      return 'No tienes permisos de administrador';
    }

    try {
      final batch = _db.batch();

      // Eliminar el evento principal
      batch.delete(_db.collection('events').doc(eventId));

      // Eliminar subcolecciones (attendance, messages, onTheWay)
      final attendanceDocs = await _db
          .collection('events')
          .doc(eventId)
          .collection('attendance')
          .get();
      for (var doc in attendanceDocs.docs) {
        batch.delete(doc.reference);
      }

      final messagesDocs = await _db
          .collection('events')
          .doc(eventId)
          .collection('messages')
          .get();
      for (var doc in messagesDocs.docs) {
        batch.delete(doc.reference);
      }

      final onTheWayDocs = await _db
          .collection('events')
          .doc(eventId)
          .collection('onTheWay')
          .get();
      for (var doc in onTheWayDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return null; // Éxito
    } catch (e) {
      debugPrint('Error eliminando evento: $e');
      return 'Error al eliminar el evento: $e';
    }
  }

  // SUSPENDER USUARIO (MARCAR COMO INACTIVO)
  Future<String?> suspendUser(String userId, bool suspend) async {
    if (!await isAdmin()) {
      return 'No tienes permisos de administrador';
    }

    if (userId == currentUid) {
      return 'No puedes suspenderte a ti mismo';
    }

    try {
      await _db.collection('users').doc(userId).update({
        'suspended': suspend,
        'suspendedAt': suspend ? FieldValue.serverTimestamp() : null,
      });
      return null; // Éxito
    } catch (e) {
      debugPrint('Error suspendiendo usuario: $e');
      return 'Error al suspender usuario: $e';
    }
  }

  // OBTENER DETALLES DE USUARIO
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;

      // Contar eventos creados por el usuario
      final eventsCreated = await _db
          .collection('events')
          .where('creatorId', isEqualTo: userId)
          .count()
          .get();

      // Contar eventos a los que asistió
      final eventsParticipated = await _db
          .collection('events')
          .where('participants', arrayContains: userId)
          .count()
          .get();

      // Contar contactos desde la subcolección (fuente de verdad)
      final contactsSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .count()
          .get();
      final contactsCount = contactsSnapshot.count ?? 0;

      return {
        ...userData,
        'eventsCreated': eventsCreated.count,
        'eventsParticipated': eventsParticipated.count,
        'contactsCount': contactsCount,
      };
    } catch (e) {
      debugPrint('Error obteniendo detalles de usuario: $e');
      return null;
    }
  }

  // BUSCAR USUARIOS POR EMAIL O NOMBRE
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final queryLower = query.toLowerCase();

      // Buscar por email
      final emailResults = await _db
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: queryLower)
          .where('email', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(10)
          .get();

      // Buscar por nombre
      final nameResults = await _db
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      // Combinar resultados eliminando duplicados
      final Map<String, Map<String, dynamic>> resultsMap = {};

      for (var doc in emailResults.docs) {
        resultsMap[doc.id] = {'uid': doc.id, ...doc.data()};
      }

      for (var doc in nameResults.docs) {
        resultsMap[doc.id] = {'uid': doc.id, ...doc.data()};
      }

      return resultsMap.values.toList();
    } catch (e) {
      debugPrint('Error buscando usuarios: $e');
      return [];
    }
  }

  // BUSCAR EVENTOS POR TÍTULO
  Future<List<Map<String, dynamic>>> searchEvents(String query) async {
    if (query.isEmpty) return [];

    try {
      final results = await _db
          .collection('events')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      return results.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      debugPrint('Error buscando eventos: $e');
      return [];
    }
  }
}
