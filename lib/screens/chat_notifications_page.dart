import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'event_chat_page.dart';

class ChatNotificationsPage extends StatefulWidget {
  const ChatNotificationsPage({super.key});

  @override
  State<ChatNotificationsPage> createState() => _ChatNotificationsPageState();
}

class _ChatNotificationsPageState extends State<ChatNotificationsPage> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> _markAllAsRead() async {
    if (_currentUser == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final notifications = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: _currentUser!.uid)
        .where('read', isEqualTo: false)
        .where('type', isEqualTo: 'event_message')
        .get();
    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  void _handleMessageTap(Map<String, dynamic> data, String notificationId) {
    _markAsRead(notificationId);

    final eventId = data['eventId'];
    final eventTitle = data['eventTitle'] ?? 'Evento';

    if (eventId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              EventChatPage(eventId: eventId, eventTitle: eventTitle),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mensajes')),
        body: const Center(child: Text('Debes iniciar sesión')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes de Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'Marcar todos como leídos',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: _currentUser!.uid)
            .where('type', isEqualTo: 'event_message')
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final messages = snapshot.data?.docs ?? [];

          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes mensajes',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final data = message.data() as Map<String, dynamic>;
              final isRead = data['read'] ?? false;
              final senderName = data['senderName'] ?? 'Usuario';
              final messageText = data['messageText'] ?? '';
              final eventTitle = data['eventTitle'] ?? 'Evento';
              final timestamp = data['createdAt'] as Timestamp?;

              return Container(
                decoration: BoxDecoration(
                  color: isRead
                      ? colorScheme.surface
                      : colorScheme.primaryContainer.withOpacity(0.15),
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: InkWell(
                  onTap: () => _handleMessageTap(data, message.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar del chat
                        Stack(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary.withOpacity(0.7),
                                    colorScheme.tertiary.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  eventTitle.isNotEmpty
                                      ? eventTitle[0].toUpperCase()
                                      : 'E',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (!isRead)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Contenido del mensaje
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      eventTitle,
                                      style: TextStyle(
                                        fontWeight: isRead
                                            ? FontWeight.w500
                                            : FontWeight.bold,
                                        fontSize: 16,
                                        color: colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTime(timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isRead
                                          ? colorScheme.onSurfaceVariant
                                                .withOpacity(0.6)
                                          : colorScheme.primary,
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: RichText(
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.w500,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '$senderName: ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                          TextSpan(text: messageText),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
