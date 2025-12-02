import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../controllers/notification_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/event_controller.dart';

class SelectEventForAttendanceDialog extends StatelessWidget {
  const SelectEventForAttendanceDialog({super.key});

  /// Filtra eventos donde el usuario NO ha confirmado llegada
  Future<List<Map<String, dynamic>>> _filterEventsWithoutAttendance(
    List<QueryDocumentSnapshot> events,
    String userId,
  ) async {
    final List<Map<String, dynamic>> filteredEvents = [];

    for (final event in events) {
      final eventId = event.id;
      final eventData = event.data() as Map<String, dynamic>;

      // Verificar si ya existe un registro de asistencia confirmada
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('attendance')
          .doc(userId)
          .get();

      final hasConfirmed =
          attendanceDoc.exists &&
          attendanceDoc.data()?['status'] == 'confirmed';

      // Solo agregar eventos donde NO se ha confirmado llegada
      if (!hasConfirmed) {
        filteredEvents.add({
          'id': eventId,
          'title': eventData['title'] ?? 'Sin título',
          'date': (eventData['date'] as Timestamp?)?.toDate(),
          'address': eventData['location']?['address'] ?? 'Sin ubicación',
        });
      }
    }

    return filteredEvents;
  }

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
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
              )
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
              return Center(child: Text('Error: ${snapshot.hasError}'));
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

            // 4. Lista de eventos (filtrando los que ya tienen asistencia confirmada)
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _filterEventsWithoutAttendance(events, currentUserId),
              builder: (context, filteredSnapshot) {
                if (filteredSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (filteredSnapshot.hasError) {
                  return Center(
                    child: Text('Error: ${filteredSnapshot.error}'),
                  );
                }

                final filteredEvents = filteredSnapshot.data ?? [];

                if (filteredEvents.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 64,
                            color: Colors.green,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Ya confirmaste llegada a todos tus eventos de hoy',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final eventInfo = filteredEvents[index];
                    final eventId = eventInfo['id'];
                    final title = eventInfo['title'];
                    final date = eventInfo['date'];
                    final address = eventInfo['address'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.event,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (date != null)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('HH:mm').format(date),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey,
                                ),
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
                        onTap: () => _confirmAttendance(
                          context,
                          eventId,
                          title,
                          currentUserId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: false).pop(),
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
    // 1. Obtener ubicación actual del usuario
    final locationCtrl = LocationController();
    final currentLocation = await locationCtrl.getCurrentPosition();

    if (currentLocation == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener tu ubicación. Activa el GPS.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Obtener ubicación del evento
    final eventDoc = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .get();

    if (!eventDoc.exists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El evento no existe'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final eventData = eventDoc.data()!;
    final eventLat = eventData['location']?['lat'] as double?;
    final eventLng = eventData['location']?['lng'] as double?;

    if (eventLat == null || eventLng == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El evento no tiene ubicación definida'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Calcular distancia
    final eventCtrl = EventController();
    final distanceInKm = eventCtrl.calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      eventLat,
      eventLng,
    );

    // 4. Validar que esté cerca (máximo 200 metros = 0.2 km)
    const maxDistanceKm = 0.2;
    if (distanceInKm > maxDistanceKm) {
      final distanceInMeters = (distanceInKm * 1000).round();
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Advertencia: Demasiado lejos'),
          content: Text(
            'Estás a ${distanceInMeters}m del lugar del evento.\n\n'
            'Debes estar en el lugar (máximo 200m de distancia) para confirmar tu llegada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // 5. Confirmar acción
    final distanceInMeters = (distanceInKm * 1000).round();
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar llegada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Confirmas que llegaste a "$eventTitle"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estás a ${distanceInMeters}m del lugar',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
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

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final userName = userDoc.data()?['displayName'] ?? 'Un usuario';

      //4. Notificación al ORGANIZADOR
      if (creatorId != null && creatorId != userId) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'attendance_confirmed',
          'eventId': eventId,
          'eventTitle': eventTitle,
          'recipientId': creatorId,
          'senderId': userId,
          'message': '$userName ha confirmado su llegada a "$eventTitle"',
          'userId': userId,
          'senderName': userName,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      //5. Cerrar diálogo y mostrar confirmación visual
      if (context.mounted) {
        Navigator.of(context).pop();
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
