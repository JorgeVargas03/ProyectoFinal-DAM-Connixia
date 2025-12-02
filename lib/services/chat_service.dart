import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtener stream de mensajes de un evento
  Stream<List<Message>> getEventMessages(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .toList();
        });
  }

  /// Enviar un mensaje al chat del evento
  Future<void> sendMessage({
    required String eventId,
    required String text,
    bool sendNotifications = true,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || text.trim().isEmpty) return;

    try {
      // 1. Crear el mensaje
      final message = Message(
        id: '',
        eventId: eventId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'Usuario',
        senderPhotoUrl: currentUser.photoURL,
        text: text.trim(),
        createdAt: DateTime.now(),
        notificationSent: false,
      );

      // 2. Guardar en Firestore
      final docRef = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('messages')
          .add(message.toMap());

      // 3. Enviar notificaciones push si está habilitado
      if (sendNotifications) {
        await _sendMessageNotifications(
          eventId: eventId,
          messageId: docRef.id,
          senderName: message.senderName,
          text: text.trim(),
          senderId: currentUser.uid,
        );
      }
    } catch (e) {
      print('Error al enviar mensaje: $e');
      rethrow;
    }
  }

  /// Enviar notificaciones push a los participantes del evento
  Future<void> _sendMessageNotifications({
    required String eventId,
    required String messageId,
    required String senderName,
    required String text,
    required String senderId,
  }) async {
    try {
      // 1. Obtener información del evento
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return;

      final eventData = eventDoc.data()!;
      final eventTitle = eventData['title'] ?? 'Evento';
      final participants = List<String>.from(eventData['participants'] ?? []);

      // 2. Filtrar participantes (excluir al remitente)
      final recipients = participants.where((uid) => uid != senderId).toList();

      // 3. Crear notificaciones para cada participante
      final batch = _firestore.batch();
      for (final recipientId in recipients) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'type': 'event_message',
          'eventId': eventId,
          'eventTitle': eventTitle,
          'messageId': messageId,
          'recipientId': recipientId,
          'senderId': senderId,
          'senderName': senderName,
          'message': '$senderName: $text',
          'messageText': text,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // 4. Ejecutar batch
      await batch.commit();

      // 5. Marcar mensaje como notificado
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('messages')
          .doc(messageId)
          .update({'notificationSent': true});
    } catch (e) {
      print('Error al enviar notificaciones: $e');
    }
  }

  /// Eliminar un mensaje (solo el autor puede hacerlo)
  Future<void> deleteMessage({
    required String eventId,
    required String messageId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final messageDoc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return;

      final message = Message.fromFirestore(messageDoc);

      // Solo el autor puede eliminar
      if (message.senderId == currentUser.uid) {
        await _firestore
            .collection('events')
            .doc(eventId)
            .collection('messages')
            .doc(messageId)
            .delete();
      }
    } catch (e) {
      print('Error al eliminar mensaje: $e');
      rethrow;
    }
  }

  /// Contar mensajes no leídos (para badge)
  Future<int> getUnreadMessageCount(String eventId, String userId) async {
    try {
      // Obtener el último mensaje leído por el usuario
      final userEventDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('eventChats')
          .doc(eventId)
          .get();

      final lastRead = userEventDoc.exists
          ? (userEventDoc.data()?['lastReadAt'] as Timestamp?)?.toDate()
          : null;

      if (lastRead == null) {
        // Si nunca ha leído, contar todos los mensajes
        final messagesSnapshot = await _firestore
            .collection('events')
            .doc(eventId)
            .collection('messages')
            .get();
        return messagesSnapshot.docs.length;
      }

      // Contar mensajes después de la última lectura
      final unreadSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('messages')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastRead))
          .get();

      return unreadSnapshot.docs.length;
    } catch (e) {
      print('Error al contar mensajes no leídos: $e');
      return 0;
    }
  }

  /// Marcar mensajes como leídos
  Future<void> markMessagesAsRead(String eventId, String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('eventChats')
          .doc(eventId)
          .set({
            'lastReadAt': FieldValue.serverTimestamp(),
            'eventId': eventId,
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error al marcar mensajes como leídos: $e');
    }
  }

  /// Verificar si el creador puede cerrar el chat
  /// (debe haber pasado al menos X horas desde la fecha del evento)
  Future<bool> canCloseChatByTime(
    String eventId, {
    int hoursAfterEvent = 2,
  }) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return false;

      final eventData = eventDoc.data()!;
      final eventDate = (eventData['date'] as Timestamp?)?.toDate();

      if (eventDate == null) return false;

      final now = DateTime.now();
      final hoursSinceEvent = now.difference(eventDate).inHours;

      return hoursSinceEvent >= hoursAfterEvent;
    } catch (e) {
      print('Error al verificar tiempo para cerrar chat: $e');
      return false;
    }
  }

  /// Cerrar el chat del evento (solo creador)
  Future<bool> closeChat(String eventId, String userId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return false;

      final eventData = eventDoc.data()!;
      final creatorId = eventData['creatorId'];

      // Verificar que es el creador
      if (creatorId != userId) {
        throw Exception('Solo el creador puede cerrar el chat');
      }

      // Verificar que ha pasado el tiempo suficiente
      if (!await canCloseChatByTime(eventId)) {
        throw Exception('Aún no ha pasado suficiente tiempo desde el evento');
      }

      // Cerrar el chat
      await _firestore.collection('events').doc(eventId).update({
        'chatClosed': true,
        'chatClosedAt': FieldValue.serverTimestamp(),
        'chatClosedBy': userId,
      });

      return true;
    } catch (e) {
      print('Error al cerrar chat: $e');
      rethrow;
    }
  }

  /// Reabrir el chat del evento (solo creador)
  Future<bool> reopenChat(String eventId, String userId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return false;

      final eventData = eventDoc.data()!;
      final creatorId = eventData['creatorId'];

      // Verificar que es el creador
      if (creatorId != userId) {
        throw Exception('Solo el creador puede reabrir el chat');
      }

      // Reabrir el chat
      await _firestore.collection('events').doc(eventId).update({
        'chatClosed': false,
        'chatReopenedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error al reabrir chat: $e');
      rethrow;
    }
  }

  /// Verificar si el chat está cerrado
  Future<bool> isChatClosed(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return false;

      final eventData = eventDoc.data()!;
      return eventData['chatClosed'] ?? false;
    } catch (e) {
      print('Error al verificar si chat está cerrado: $e');
      return false;
    }
  }
}
