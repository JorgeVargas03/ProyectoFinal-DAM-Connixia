import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String eventId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final DateTime createdAt;
  final bool notificationSent;

  Message({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    required this.createdAt,
    this.notificationSent = false,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Usuario',
      senderPhotoUrl: data['senderPhotoUrl'],
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationSent: data['notificationSent'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'notificationSent': notificationSent,
    };
  }
}
