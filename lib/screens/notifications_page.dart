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
              final type = data['type'] ?? 'unknown';
              String message = data['message'] ?? 'Nueva notificación';

              if (type == 'attendance_confirmed') {
                final eventTitle = data['eventTitle'] ?? 'un evento';
                final userName = data['senderName'] ?? 'Un usuario';
                final confirmedAt = data['confirmedAt'] as Timestamp?;
                message = '$userName confirmó su llegada a "$eventTitle"';
              }
              final status = data['status'] ?? 'pending';
              final eventId = data['eventId'];

              // --- CORRECCIÓN 1: RECUPERAR EL TIEMPO (Esto faltaba) ---
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
              // ---------------------------------------------------------

              // LÓGICA ESPECIAL PARA INVITACIONES
              if (type == 'event_invite') {
                final isPending = status == 'pending';

                return Card(
                  color: isRead ? Colors.white : Colors.blue[50],
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Icon(Icons.mail, color: Colors.white),
                        ),
                        title: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(isPending ? '¿Deseas asistir?' : 'Invitación $status • $timeAgo'),
                      ),
                      if (isPending)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  _notificationService.respondToInvitation(notificationId, eventId, false);
                                },
                                child: const Text('Rechazar', style: TextStyle(color: Colors.grey)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  _notificationService.respondToInvitation(notificationId, eventId, true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('¡Te has unido al evento!')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                                child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }

              // LÓGICA PARA NOTIFICACIONES NORMALES
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
                  subtitle: Text(timeAgo), // Aquí se usa la variable que faltaba
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
                    if (!isRead) {
                      await _notificationService.markAsRead(notificationId);
                    }
                    // Navegar al evento si existe
                    if (eventId != null && mounted) {
                      // Verificar si el evento aún existe antes de navegar
                      final doc = await FirebaseFirestore.instance.collection('events').doc(eventId).get();
                      if (doc.exists && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetailPage(
                              eventId: eventId,
                            ),
                          ),
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El evento ya no existe')),
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

  // --- CORRECCIÓN 2: AGREGAR EL ICONO DE INVITACIÓN AL SWITCH ---
  IconData _getIconForType(String type) {
    switch (type) {
      case 'event_join':
        return Icons.person_add;
      case 'event_invite': // Nuevo caso
        return Icons.mail;
      case 'event_update':
        return Icons.event;
      case 'event_reminder':
        return Icons.alarm;
        case 'attendance_confirmed':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }
}