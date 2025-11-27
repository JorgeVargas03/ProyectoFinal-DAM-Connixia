import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import 'event_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Marcar todas como leídas',
            onPressed: () async {
              await _notificationService.markAllAsRead();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Todas marcadas como leídas')),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clear') {
                await _notificationService.clearReadNotifications();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notificaciones leídas eliminadas')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Limpiar leídas'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService.getMyNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tienes notificaciones',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final notificationId = doc.id;
              
              final isRead = data['read'] ?? false;
              final message = data['message'] ?? 'Nueva notificación';
              final eventId = data['eventId'];
              final type = data['type'] ?? 'unknown';
              final timestamp = data['createdAt'] as Timestamp?;
              
              String timeAgo = 'Ahora';
              if (timestamp != null) {
                final diff = DateTime.now().difference(timestamp.toDate());
                if (diff.inDays > 0) {
                  timeAgo = 'hace ${diff.inDays}d';
                } else if (diff.inHours > 0) {
                  timeAgo = 'hace ${diff.inHours}h';
                } else if (diff.inMinutes > 0) {
                  timeAgo = 'hace ${diff.inMinutes}m';
                }
              }

              return Dismissible(
                key: Key(notificationId),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _notificationService.deleteNotification(notificationId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notificación eliminada')),
                  );
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey : Colors.blue,
                    child: Icon(
                      _getIconForType(type),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    message,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(timeAgo),
                  trailing: isRead 
                      ? null 
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () async {
                    // Marcar como leída
                    if (!isRead) {
                      await _notificationService.markAsRead(notificationId);
                    }
                    
                    // Navegar al evento si existe
                    if (eventId != null && mounted) {
                      final eventDoc = await FirebaseFirestore.instance
                          .collection('events')
                          .doc(eventId)
                          .get();
                      
                      if (eventDoc.exists && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetailPage(
                              eventId: eventId,
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'event_join':
        return Icons.person_add;
      case 'event_update':
        return Icons.event;
      case 'event_reminder':
        return Icons.alarm;
      default:
        return Icons.notifications;
    }
  }
}
