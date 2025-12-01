import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../controllers/notification_controller.dart';

class SelectEventForAttendanceDialog extends StatelessWidget {
  const SelectEventForAttendanceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return AlertDialog(
      title: const Text('¿A qué evento llegaste?'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .where('participants', arrayContains: currentUserId)
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
              .where('date', isLessThan: Timestamp.fromDate(todayEnd))
              .snapshots(),
          builder: (context, snapshot) {
            // 1. Cargando
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // 2. Error
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.hasError}'),
              );
            }

            // 3. Sin eventos
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No tienes eventos para hoy',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }

            final events = snapshot.data!.docs;

            // 4. Lista de eventos
            return ListView.builder(
              shrinkWrap: true,
              itemCount: events.length,
              itemBuilder: (context, index) {
                final eventData = events[index].data() as Map<String, dynamic>;
                final eventId = events[index].id;
                final title = eventData['title'] ?? 'Sin título';
                final date = (eventData['date'] as Timestamp?)?.toDate();
                final address = eventData['location']?['address'] ?? 'Sin ubicación';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.event,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (date != null)
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('HH:mm').format(date),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _confirmAttendance(context, eventId, title, currentUserId),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Future<void> _confirmAttendance(
      BuildContext context,
      String eventId,
      String eventTitle,
      String userId,
      ) async {
    // Confirmar acción
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar llegada'),
        content: Text('¿Confirmas que llegaste a "$eventTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      //1. Registrar asistencia
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('attendance')
          .doc(userId)
          .set({
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      //2. Notificación LOCAL al usuario (la que faltaba)
      final notificationController = NotificationController();
      await notificationController.showLocal(
        'Llegada confirmada',
        'Tu asistencia a "$eventTitle" ha sido registrada',
      );

      //3. Obtener info del evento para notificar al creador
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();

      final creatorId = eventDoc.data()?['creatorId'];

      //4. Notificación al ORGANIZADOR (ya existía)
      if (creatorId != null && creatorId != userId) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorId)
            .collection('notifications')
            .add({
          'type': 'attendance_confirmed',
          'eventId': eventId,
          'eventTitle': eventTitle,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      //5. Cerrar diálogo y mostrar confirmación visual
      if (context.mounted) {
        Navigator.pop(context); // Cerrar diálogo de selección
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Llegada confirmada a "$eventTitle"!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al confirmar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}
