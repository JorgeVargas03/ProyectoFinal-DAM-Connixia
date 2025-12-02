import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'event_chat_page.dart';

/// Página tipo WhatsApp que muestra todos los chats de eventos
/// en los que participa el usuario
class EventChatsListPage extends StatelessWidget {
  const EventChatsListPage({super.key});

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(date);
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chats')),
        body: const Center(child: Text('Debes iniciar sesión')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chats de Eventos'), elevation: 0),
      body: StreamBuilder<QuerySnapshot>(
        // Obtener todos los eventos donde el usuario es participante
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('participants', arrayContains: currentUser.uid)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, eventsSnapshot) {
          if (eventsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (eventsSnapshot.hasError) {
            return Center(child: Text('Error: ${eventsSnapshot.error}'));
          }

          final events = eventsSnapshot.data?.docs ?? [];

          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 60,
                      color: colorScheme.primary.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No tienes chats',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Únete a eventos para chatear',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final eventDoc = events[index];
              final eventData = eventDoc.data() as Map<String, dynamic>;
              final eventId = eventDoc.id;
              final eventTitle = eventData['title'] ?? 'Sin título';
              final eventLocation = eventData['location'] ?? '';

              // Para cada evento, obtener el último mensaje
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .doc(eventId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, messagesSnapshot) {
                  String lastMessageText = 'No hay mensajes';
                  String lastMessageSender = '';
                  Timestamp? lastMessageTime;
                  int unreadCount = 0;

                  if (messagesSnapshot.hasData &&
                      messagesSnapshot.data!.docs.isNotEmpty) {
                    final lastMsg =
                        messagesSnapshot.data!.docs.first.data()
                            as Map<String, dynamic>;
                    lastMessageText = lastMsg['text'] ?? '';
                    lastMessageSender = lastMsg['senderName'] ?? 'Usuario';
                    lastMessageTime = lastMsg['timestamp'] as Timestamp?;
                  }

                  // Contar mensajes no leídos para este usuario en este evento
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('recipientId', isEqualTo: currentUser.uid)
                        .where('eventId', isEqualTo: eventId)
                        .where('type', isEqualTo: 'event_message')
                        .where('read', isEqualTo: false)
                        .snapshots(),
                    builder: (context, unreadSnapshot) {
                      unreadCount = unreadSnapshot.hasData
                          ? unreadSnapshot.data!.docs.length
                          : 0;

                      return Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          border: Border(
                            bottom: BorderSide(
                              color: colorScheme.outlineVariant.withOpacity(
                                0.3,
                              ),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventChatPage(
                                  eventId: eventId,
                                  eventTitle: eventTitle,
                                ),
                              ),
                            );
                            // No es necesario hacer nada aquí, el StreamBuilder se actualiza automáticamente
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Avatar del evento
                                Stack(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            colorScheme.primary.withOpacity(
                                              0.7,
                                            ),
                                            colorScheme.tertiary.withOpacity(
                                              0.7,
                                            ),
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
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: colorScheme.surface,
                                              width: 2,
                                            ),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : '$unreadCount',
                                            style: TextStyle(
                                              color: colorScheme.onPrimary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                // Información del chat
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              eventTitle,
                                              style: TextStyle(
                                                fontWeight: unreadCount > 0
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                fontSize: 16,
                                                color: colorScheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTime(lastMessageTime),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: unreadCount > 0
                                                  ? colorScheme.primary
                                                  : colorScheme.onSurfaceVariant
                                                        .withOpacity(0.6),
                                              fontWeight: unreadCount > 0
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
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
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                                ),
                                                children: [
                                                  if (lastMessageSender
                                                          .isNotEmpty &&
                                                      lastMessageText !=
                                                          'No hay mensajes')
                                                    TextSpan(
                                                      text:
                                                          '$lastMessageSender: ',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: colorScheme
                                                            .onSurface
                                                            .withOpacity(0.8),
                                                      ),
                                                    ),
                                                  TextSpan(
                                                    text: lastMessageText,
                                                  ),
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
              );
            },
          );
        },
      ),
    );
  }
}
