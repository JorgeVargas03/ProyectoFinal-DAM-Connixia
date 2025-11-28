import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  /// Crear notificación cuando alguien se une a un evento
  Future<void> notifyEventJoin({
    required String eventId,
    required String eventTitle,
    required String creatorId,
    required String joinerName,
  }) async {
    try {
      await _db.collection('notifications').add({
        'type': 'event_join',
        'eventId': eventId,
        'eventTitle': eventTitle,
        'recipientId': creatorId, // Quien recibe la notificación
        'senderId': currentUid, // Quien se unió
        'senderName': joinerName,
        'message': '$joinerName se unió a tu evento "$eventTitle"',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Notificación enviada al creador del evento');
    } catch (e) {
      debugPrint('Error enviando notificación: $e');
    }
  }

  /// Obtener notificaciones del usuario actual
  Stream<QuerySnapshot> getMyNotifications() {
    if (currentUid == null) return const Stream.empty();
    
    return _db
        .collection('notifications')
        .where('recipientId', isEqualTo: currentUid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      debugPrint('Error marcando notificación como leída: $e');
    }
  }

  /// Marcar todas las notificaciones como leídas
  Future<void> markAllAsRead() async {
    if (currentUid == null) return;
    
    try {
      final batch = _db.batch();
      final snapshot = await _db
          .collection('notifications')
          .where('recipientId', isEqualTo: currentUid)
          .where('read', isEqualTo: false)
          .get();
      
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error marcando todas como leídas: $e');
    }
  }

  /// Contar notificaciones no leídas
  Stream<int> getUnreadCount() {
    if (currentUid == null) return Stream.value(0);
    
    return _db
        .collection('notifications')
        .where('recipientId', isEqualTo: currentUid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Eliminar notificación
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error eliminando notificación: $e');
    }
  }

  /// Eliminar todas las notificaciones leídas
  Future<void> clearReadNotifications() async {
    if (currentUid == null) return;
    
    try {
      final batch = _db.batch();
      final snapshot = await _db
          .collection('notifications')
          .where('recipientId', isEqualTo: currentUid)
          .where('read', isEqualTo: true)
          .get();
      
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error limpiando notificaciones: $e');
    }
  }

  // ... (dentro de class NotificationService)

  // 1. ENVIAR INVITACIÓN (Lo usa el organizador)
  Future<void> sendInvitation({
    required String eventId,
    required String eventTitle,
    required String targetUserId, // El ID de tu amigo
    required String senderName,   // Tu nombre
  }) async {
    try {
      await _db.collection('notifications').add({
        'type': 'event_invite', // <--- TIPO CLAVE
        'eventId': eventId,
        'eventTitle': eventTitle,
        'recipientId': targetUserId,
        'senderId': currentUid,
        'senderName': senderName,
        'message': '$senderName te invitó al evento "$eventTitle"',
        'read': false,
        'status': 'pending', // pending, accepted, rejected
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error enviando invitación: $e');
    }
  }

  // 2. RESPONDER INVITACIÓN (Lo usa el amigo al dar click)
  Future<void> respondToInvitation(String notificationId, String eventId, bool accepted) async {
    if (currentUid == null) return;

    try {
      final batch = _db.batch();

      // A) Actualizar la notificación para que no se pueda volver a clicar
      final notifRef = _db.collection('notifications').doc(notificationId);
      batch.update(notifRef, {
        'status': accepted ? 'accepted' : 'rejected',
        'read': true, // Se marca como leída automáticamente
      });

      // B) Si aceptó, lo agregamos al evento
      if (accepted) {
        final eventRef = _db.collection('events').doc(eventId);
        batch.update(eventRef, {
          'participants': FieldValue.arrayUnion([currentUid])
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error respondiendo invitación: $e');
      throw e; // Relanzamos para mostrar snackbar en la UI
    }
  }

}
