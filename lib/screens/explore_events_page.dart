import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../controllers/event_controller.dart';
import '../controllers/location_controller.dart';
import 'event_detail_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ExploreEventsPage extends StatefulWidget {
  const ExploreEventsPage({super.key});

  @override
  State<ExploreEventsPage> createState() => _ExploreEventsPageState();
}

class _ExploreEventsPageState extends State<ExploreEventsPage> {
  final _eventCtrl = EventController();
  final _locationCtrl = LocationController();
  LatLng? _myPosition;
  bool _loadingLocation = true;
  double? _maxDistance; // null = sin límite

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    _myPosition = await _locationCtrl.getCurrentPosition();
    setState(() => _loadingLocation = false);
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '--';
    return DateFormat('dd MMM HH:mm', 'es').format(timestamp.toDate());
  }

  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar Eventos'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _maxDistance == null ? Icons.filter_list_off : Icons.filter_list,
            ),
            onPressed: _showFilterDialog,
            tooltip: 'Filtrar por distancia',
          ),
        ],
      ),
      body: _loadingLocation
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: _eventCtrl.getAllVisibleEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.explore_off, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay eventos disponibles',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '¡Sé el primero en crear uno!',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // Filtrar y ordenar por distancia
                final now = DateTime.now();
                final eventsWithDistance = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lat = data['location']?['lat'] as double?;
                  final lng = data['location']?['lng'] as double?;
                  final date = data['date'] as Timestamp?;

                  double? distance;
                  if (_myPosition != null && lat != null && lng != null) {
                    distance = _eventCtrl.calculateDistance(
                      _myPosition!.latitude,
                      _myPosition!.longitude,
                      lat,
                      lng,
                    );
                  }

                  return {
                    'doc': doc,
                    'data': data,
                    'distance': distance,
                    'date': date,
                  };
                }).where((item) {
                  // Filtro 1: Excluir eventos pasados
                  final date = item['date'] as Timestamp?;
                  if (date != null && date.toDate().isBefore(now)) {
                    return false;
                  }

                  // Filtro 2: Aplicar filtro de distancia si está activo
                  if (_maxDistance != null) {
                    final distance = item['distance'] as double?;
                    if (distance == null || distance > _maxDistance!) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                // Ordenar por distancia (más cerca primero)
                eventsWithDistance.sort((a, b) {
                  final distA = a['distance'] as double?;
                  final distB = b['distance'] as double?;
                  if (distA == null) return 1;
                  if (distB == null) return -1;
                  return distA.compareTo(distB);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: eventsWithDistance.length,
                  itemBuilder: (context, index) {
                    final item = eventsWithDistance[index];
                    final doc = item['doc'] as DocumentSnapshot;
                    final data = item['data'] as Map<String, dynamic>;
                    final distance = item['distance'] as double?;
                    final eventId = doc.id;

                    final title = data['title'] ?? 'Sin título';
                    final creatorId = data['creatorId'] ?? '';
                    final creatorName = data['creatorName'] ?? 'Alguien';
                    final date = data['date'] as Timestamp?;
                    final address = data['location']?['address'] ?? 'Ubicación desconocida';
                    final participants = List.from(data['participants'] ?? []);

                    final isMyEvent = (myUid == creatorId);
                    final isAlreadyJoined = participants.contains(myUid);
                    final isTooFar = distance != null && distance > 100; // Más de 100km

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EventDetailPage(eventId: eventId),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Encabezado
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  if (isMyEvent)
                                    Chip(
                                      label: const Text('Tu evento'),
                                      backgroundColor: Colors.blue[100],
                                      labelStyle: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Fecha y hora
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDate(date),
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Distancia
                              if (distance != null)
                                Row(
                                  children: [
                                    Icon(Icons.navigation, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatDistance(distance),
                                      style: TextStyle(
                                        color: isTooFar ? Colors.orange : Colors.grey[700],
                                        fontWeight: isTooFar ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    if (isTooFar) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '(Muy lejos)',
                                        style: TextStyle(color: Colors.orange[700], fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              const SizedBox(height: 6),

                              // Ubicación
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      address,
                                      style: TextStyle(color: Colors.grey[700]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Organizador y participantes
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Por: $creatorName',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${participants.length}',
                                        style: TextStyle(color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Botón de acción
                              SizedBox(
                                width: double.infinity,
                                child: _buildActionButton(
                                  context,
                                  eventId,
                                  isMyEvent,
                                  isAlreadyJoined,
                                  isTooFar,
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

  Widget _buildActionButton(
    BuildContext context,
    String eventId,
    bool isMyEvent,
    bool isAlreadyJoined,
    bool isTooFar,
  ) {
    if (isMyEvent) {
      return OutlinedButton.icon(
        onPressed: null, // Deshabilitado
        icon: const Icon(Icons.check_circle),
        label: const Text('Tu evento'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey,
        ),
      );
    }

    if (isAlreadyJoined) {
      return ElevatedButton.icon(
        onPressed: null, // Deshabilitado
        icon: const Icon(Icons.check),
        label: const Text('Ya estás unido'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[100],
          foregroundColor: Colors.green[800],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: isTooFar
          ? () => _showTooFarDialog(context)
          : () => _confirmJoin(context, eventId),
      icon: Icon(isTooFar ? Icons.warning_amber : Icons.add),
      label: Text(isTooFar ? 'Muy lejos' : 'Unirme al evento'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isTooFar ? Colors.orange[100] : null,
        foregroundColor: isTooFar ? Colors.orange[800] : null,
      ),
    );
  }

  void _showTooFarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Evento lejano'),
        content: const Text(
          'Este evento está a más de 100 km de distancia. '
          '¿Seguro que deseas unirte?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Continuar con el join
            },
            child: const Text('Sí, unirme'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmJoin(BuildContext context, String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unirse al evento'),
        content: const Text(
          '¿Deseas unirte a este evento? '
          'El organizador recibirá una notificación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unirme'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final error = await _eventCtrl.joinEvent(eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? '¡Te uniste al evento!'),
            backgroundColor: error == null ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        double? tempMaxDistance = _maxDistance;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filtrar por distancia'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Todos los eventos'),
                    leading: Radio<double?>(
                      value: null,
                      groupValue: tempMaxDistance,
                      onChanged: (value) {
                        setDialogState(() => tempMaxDistance = value);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Hasta 10 km'),
                    leading: Radio<double?>(
                      value: 10,
                      groupValue: tempMaxDistance,
                      onChanged: (value) {
                        setDialogState(() => tempMaxDistance = value);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Hasta 25 km'),
                    leading: Radio<double?>(
                      value: 25,
                      groupValue: tempMaxDistance,
                      onChanged: (value) {
                        setDialogState(() => tempMaxDistance = value);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Hasta 50 km'),
                    leading: Radio<double?>(
                      value: 50,
                      groupValue: tempMaxDistance,
                      onChanged: (value) {
                        setDialogState(() => tempMaxDistance = value);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Hasta 100 km'),
                    leading: Radio<double?>(
                      value: 100,
                      groupValue: tempMaxDistance,
                      onChanged: (value) {
                        setDialogState(() => tempMaxDistance = value);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _maxDistance = tempMaxDistance);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tempMaxDistance == null
                              ? 'Mostrando todos los eventos'
                              : 'Mostrando eventos hasta ${tempMaxDistance}km',
                        ),
                      ),
                    );
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
