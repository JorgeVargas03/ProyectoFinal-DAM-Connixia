import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class EventChatPage extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventChatPage({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<EventChatPage> createState() => _EventChatPageState();
}

class _EventChatPageState extends State<EventChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sendNotifications = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _chatService.markMessagesAsRead(widget.eventId, currentUser.uid);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    // Verificar si el chat está cerrado
    final isClosed = await _chatService.isChatClosed(widget.eventId);
    if (isClosed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El chat ha sido cerrado por el organizador'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final text = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isLoading = true);

    try {
      await _chatService.sendMessage(
        eventId: widget.eventId,
        text: text,
        sendNotifications: _sendNotifications,
      );

      // Scroll al final después de enviar
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar mensaje: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este mensaje?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _chatService.deleteMessage(
          eventId: widget.eventId,
          messageId: messageId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mensaje eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleChatStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final isClosed = await _chatService.isChatClosed(widget.eventId);

      if (isClosed) {
        // Reabrir chat
        await _chatService.reopenChat(widget.eventId, currentUser.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat reabierto'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      } else {
        // Intentar cerrar chat
        final canClose = await _chatService.canCloseChatByTime(widget.eventId);

        if (!canClose) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Debes esperar al menos 2 horas después del evento',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Confirmar cierre
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cerrar chat'),
            content: const Text(
              '¿Estás seguro de que quieres cerrar el chat? '
              'Los participantes no podrán enviar más mensajes.\n\n'
              'Podrás reabrirlo cuando quieras.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Cerrar chat'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _chatService.closeChat(widget.eventId, currentUser.uid);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chat cerrado'),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() {});
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Ayer ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE HH:mm', 'es').format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .snapshots(),
      builder: (context, eventSnapshot) {
        final eventData = eventSnapshot.data?.data() as Map<String, dynamic>?;
        final isCreator = eventData?['creatorId'] == currentUser?.uid;
        final isChatClosed = eventData?['chatClosed'] ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.eventTitle,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    const Text(
                      'Chat del evento',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    if (isChatClosed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'CERRADO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            actions: [
              // Botón cerrar/abrir chat (solo creador)
              if (isCreator)
                FutureBuilder<bool>(
                  future: _chatService.canCloseChatByTime(widget.eventId),
                  builder: (context, canCloseSnapshot) {
                    final canClose = canCloseSnapshot.data ?? false;

                    return IconButton(
                      icon: Icon(
                        isChatClosed ? Icons.lock_open : Icons.lock_outline,
                        color: isChatClosed ? Colors.orange : null,
                      ),
                      onPressed: (isChatClosed || canClose)
                          ? _toggleChatStatus
                          : null,
                      tooltip: isChatClosed
                          ? 'Reabrir chat'
                          : canClose
                          ? 'Cerrar chat'
                          : 'Podrás cerrar el chat 2h después del evento',
                    );
                  },
                ),
              // Toggle de notificaciones
              IconButton(
                icon: Icon(
                  _sendNotifications
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                ),
                onPressed: () {
                  setState(() {
                    _sendNotifications = !_sendNotifications;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _sendNotifications
                            ? 'Notificaciones activadas'
                            : 'Notificaciones desactivadas',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                tooltip: _sendNotifications
                    ? 'Desactivar notificaciones'
                    : 'Activar notificaciones',
              ),
            ],
          ),
          body: Column(
            children: [
              // Lista de mensajes
              Expanded(
                child: StreamBuilder<List<Message>>(
                  stream: _chatService.getEventMessages(widget.eventId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text('Error: ${snapshot.error}'),
                          ],
                        ),
                      );
                    }

                    final messages = snapshot.data ?? [];

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
                              'No hay mensajes aún',
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '¡Sé el primero en escribir!',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUser?.uid;
                        final showAvatar =
                            index == 0 ||
                            messages[index - 1].senderId != message.senderId;

                        return _buildMessageBubble(
                          message,
                          isMe,
                          showAvatar,
                          colorScheme,
                        );
                      },
                    );
                  },
                ),
              ),

              // Campo de entrada
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: isChatClosed
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'El chat ha sido cerrado por el organizador',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: 'Escribe un mensaje...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FloatingActionButton(
                              onPressed: _isLoading ? null : _sendMessage,
                              mini: true,
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(
    Message message,
    bool isMe,
    bool showAvatar,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundImage: message.senderPhotoUrl != null
                  ? NetworkImage(message.senderPhotoUrl!)
                  : null,
              child: message.senderPhotoUrl == null
                  ? Text(
                      message.senderName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 14),
                    )
                  : null,
            )
          else if (!isMe)
            const SizedBox(width: 32),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: isMe ? () => _deleteMessage(message.id) : null,
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? colorScheme.primary
                          : colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            color: isMe
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            color: isMe
                                ? colorScheme.onPrimary.withOpacity(0.7)
                                : colorScheme.onSurfaceVariant.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
