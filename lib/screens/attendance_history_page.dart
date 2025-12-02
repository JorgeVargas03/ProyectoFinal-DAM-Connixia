import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'event_detail_page.dart';

class AttendanceHistoryPage extends StatelessWidget {
  final String? userId; // Si es null, usa el usuario actual

  const AttendanceHistoryPage({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final targetUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;

    if (targetUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historial de Asistencia')),
        body: const Center(child: Text('No hay usuario autenticado')),
      );
    }

    final isMe = FirebaseAuth.instance.currentUser?.uid == targetUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMe ? 'Mi Historial de Asistencia' : 'Historial de Asistencia',
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Buscar todos los eventos donde el usuario es participante
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('participants', arrayContains: targetUserId)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, eventsSnapshot) {
          if (eventsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!eventsSnapshot.hasData || eventsSnapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay eventos registrados',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final events = eventsSnapshot.data!.docs;

          return FutureBuilder<Map<String, DocumentSnapshot>>(
            // Obtener información de asistencia para cada evento
            future: _getAttendanceForEvents(events, targetUserId),
            builder: (context, attendanceSnapshot) {
              if (attendanceSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final attendanceMap = attendanceSnapshot.data ?? {};

              // Filtrar eventos con asistencia confirmada
              final confirmedEvents = events.where((eventDoc) {
                final attendance = attendanceMap[eventDoc.id];
                return attendance != null &&
                    attendance.exists &&
                    attendance.data() != null &&
                    (attendance.data() as Map<String, dynamic>)['status'] ==
                        'confirmed';
              }).toList();

              if (confirmedEvents.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isMe
                              ? 'Aún no has confirmado llegada\na ningún evento'
                              : 'Este usuario no ha confirmado\nllegada a ningún evento',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Confirma tu llegada sacudiendo el teléfono\nen la ubicación del evento',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: confirmedEvents.length,
                itemBuilder: (context, index) {
                  final eventDoc = confirmedEvents[index];
                  final event = eventDoc.data() as Map<String, dynamic>;
                  final eventId = eventDoc.id;
                  final attendance = attendanceMap[eventId];
                  final attendanceData =
                      attendance?.data() as Map<String, dynamic>?;

                  final title = event['title'] ?? 'Evento';
                  final date = (event['date'] as Timestamp?)?.toDate();
                  final address =
                      event['location']?['address'] ?? 'Ubicación desconocida';
                  final confirmedAt =
                      (attendanceData?['confirmedAt'] as Timestamp?)?.toDate();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventDetailPage(eventId: eventId),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- TÍTULO Y BADGE ---
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'ASISTIDO',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // --- FECHA DEL EVENTO ---
                            if (date != null)
                              _buildInfoRow(
                                icon: Icons.event,
                                text: DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                  'es',
                                ).format(date),
                                color: Colors.blue,
                              ),

                            const SizedBox(height: 8),

                            // --- UBICACIÓN ---
                            _buildInfoRow(
                              icon: Icons.location_on,
                              text: address,
                              color: Colors.red,
                            ),

                            const SizedBox(height: 8),

                            // --- HORA DE CONFIRMACIÓN ---
                            if (confirmedAt != null)
                              _buildInfoRow(
                                icon: Icons.check_circle_outline,
                                text:
                                    'Confirmado ${_formatTimeAgo(confirmedAt)}',
                                color: Colors.green,
                              ),

                            const SizedBox(height: 12),

                            // --- BOTÓN VER DETALLES ---
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EventDetailPage(eventId: eventId),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                label: const Text('Ver detalles'),
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
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'hace ${difference.inDays} día${difference.inDays > 1 ? "s" : ""}';
    } else if (difference.inHours > 0) {
      return 'hace ${difference.inHours} hora${difference.inHours > 1 ? "s" : ""}';
    } else if (difference.inMinutes > 0) {
      return 'hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? "s" : ""}';
    } else {
      return 'justo ahora';
    }
  }

  Future<Map<String, DocumentSnapshot>> _getAttendanceForEvents(
    List<QueryDocumentSnapshot> events,
    String userId,
  ) async {
    final Map<String, DocumentSnapshot> attendanceMap = {};

    for (var eventDoc in events) {
      try {
        final attendanceDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventDoc.id)
            .collection('attendance')
            .doc(userId)
            .get();

        attendanceMap[eventDoc.id] = attendanceDoc;
      } catch (e) {
        // Si hay error, simplemente no se incluye en el mapa
        continue;
      }
    }

    return attendanceMap;
  }
}
