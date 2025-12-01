import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/event_controller.dart';
import 'location_picker_page.dart';
import '../widgets/invite_friends_dialog.dart';
import 'user_profile_page.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _eventCtrl = EventController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  GoogleMapController? _mapController;

  // Formateador de fecha
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Fecha por definir';
    return DateFormat('EEEE d, MMMM yyyy - HH:mm', 'es').format(timestamp.toDate());
  }

  String _formatTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return 'el ${DateFormat('dd/MM').format(date)}';
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Validaciones de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('Cargando...')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          // 2. Validación de existencia
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('El evento ya no existe o fue eliminado')),
            );
          }

          // 3. Extracción de datos
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = data['title'] ?? 'Sin título';
          final description = data['description'] ?? '';
          final date = data['date'] as Timestamp?;
          final creatorId = data['creatorId'];
          final creatorName = data['creatorName'] ?? 'Desconocido';
          final address = data['location']?['address'] ?? 'Ubicación pendiente';
          final participants = List.from(data['participants'] ?? []);
          
          // Extraer coordenadas del mapa
          final location = data['location'] as Map<String, dynamic>?;
          final lat = location?['lat'] as double?;
          final lng = location?['lng'] as double?;

          // Validar permisos
          final isCreator = _currentUser?.uid == creatorId;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Detalles'),
              actions: [
                // BOTÓN EDITAR (Solo visible para el creador)
                if (isCreator)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Editar información',
                    // PASAMOS LA FECHA ACTUAL Y UBICACIÓN AL DIÁLOGO
                    onPressed: () => _showEditDialog(context, title, description, creatorId, date, lat, lng, address),
                  ),

                // Botón compartir (Visual)
                IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECCIÓN 1: EL MAPA ---
                  _buildMapView(lat, lng, address),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SECCIÓN 2: ENCABEZADO ---
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month, color: Colors.indigo, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(date),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // --- SECCIÓN 3: UBICACIÓN TEXTUAL ---
                        const Text('Ubicación:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(address)),
                          ],
                        ),
                        const Divider(height: 40),

                        // --- SECCIÓN 4: DESCRIPCIÓN ---
                        if (description.isNotEmpty) ...[
                          const Text('Acerca del evento:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(description),
                          const Divider(height: 40),
                        ],

                        // --- SECCIÓN 5: PARTICIPANTES ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Asistentes (${participants.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),

                            if (isCreator)
                              IconButton.filledTonal(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => InviteFriendsDialog(
                                      eventId: widget.eventId,
                                      eventTitle: title,
                                      currentParticipants: participants,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.person_add),
                                tooltip: 'Invitar amigos',
                              )
                            else
                            // Si no eres creador, mostramos el chip de siempre
                              Chip(
                                label: const Text('Organizador'),
                                // ... tus estilos
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Lista de participantes con fotos
                        // Lista de participantes con fotos
                        // Lista de participantes con confirmación de llegada
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('events')
                              .doc(widget.eventId)
                              .collection('attendance')
                              .snapshots(),
                          builder: (context, attendanceSnapshot) {
                            // Mapa de userId -> datos de asistencia
                            final attendanceMap = <String, Map<String, dynamic>>{};

                            if (attendanceSnapshot.hasData) {
                              for (final doc in attendanceSnapshot.data!.docs) {
                                attendanceMap[doc.id] = doc.data() as Map<String, dynamic>;
                              }
                            }

                            return FutureBuilder<List<Map<String, dynamic>>>(
                              future: _eventCtrl.getParticipantsInfo(participants.cast<String>()),
                              builder: (context, participantsSnapshot) {
                                if (participantsSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final participantsInfo = participantsSnapshot.data ?? [];

                                if (participantsInfo.isEmpty) {
                                  return Text(
                                    'No se pudo cargar la información de los participantes',
                                    style: TextStyle(color: Colors.grey[600]),
                                  );
                                }

                                return Column(
                                  children: participantsInfo.map((participant) {
                                    final uid = participant['uid'];
                                    final isOrganizer = uid == creatorId;
                                    final displayName = participant['displayName'] ?? 'Usuario';
                                    final photoURL = participant['photoURL'];
                                    final initial = displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : 'U';

                                    // Datos de asistencia
                                    final attendance = attendanceMap[uid];
                                    final hasConfirmed = attendance?['status'] == 'confirmed';
                                    final confirmedAt = attendance?['confirmedAt'] as Timestamp?;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      elevation: 1,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => UserProfilePage(
                                                targetUserId: uid,
                                                userName: displayName,
                                              ),
                                            ),
                                          );
                                        },
                                        child: ListTile(
                                          leading: Stack(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                                backgroundImage: photoURL != null && photoURL.isNotEmpty
                                                    ? NetworkImage(photoURL)
                                                    : null,
                                                child: photoURL == null || photoURL.isEmpty
                                                    ? Text(
                                                  initial,
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                                    : null,
                                              ),
                                              // Badge de confirmación
                                              if (hasConfirmed)
                                                Positioned(
                                                  right: 0,
                                                  bottom: 0,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.white, width: 2),
                                                    ),
                                                    child: const Icon(
                                                      Icons.check,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          title: Text(displayName),
                                          subtitle: hasConfirmed && confirmedAt != null
                                              ? Text(
                                            'Llegó ${_formatTimeAgo(confirmedAt)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                              : null,
                                          trailing: isOrganizer
                                              ? Chip(
                                            label: const Text('Organizador'),
                                            backgroundColor: Colors.amber[100],
                                            labelStyle: const TextStyle(fontSize: 11),
                                          )
                                              : hasConfirmed
                                              ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
                                              : Icon(Icons.schedule, color: Colors.grey[400], size: 20),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            );
                          },
                        ),


                        const SizedBox(height: 40),

                        // --- SECCIÓN 6: BOTONES DE ACCIÓN ---
                        SizedBox(
                          width: double.infinity,
                          child: isCreator
                              ? ElevatedButton.icon(
                            onPressed: () => _confirmDelete(context, creatorId),
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Cancelar evento'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[50],
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.all(16),
                            ),
                          )
                              : participants.contains(_currentUser?.uid)
                              ? OutlinedButton.icon(
                            onPressed: () => _confirmLeave(context),
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('Salir del evento'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                            ),
                          )
                              : ElevatedButton.icon(
                            onPressed: () => _confirmJoin(context, widget.eventId),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Unirme al evento'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[50],
                              foregroundColor: Colors.green[700],
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET DEL MAPA REAL ---
  Widget _buildMapView(double? lat, double? lng, String address) {
    if (lat == null || lng == null) {
      return Container(
        height: 250,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('Sin ubicación definida'),
            ],
          ),
        ),
      );
    }

    final position = LatLng(lat, lng);

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: position,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: {
              Marker(
                markerId: const MarkerId('event_location'),
                position: position,
                infoWindow: InfoWindow(
                  title: 'Punto de encuentro',
                  snippet: address,
                ),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'openMaps',
              onPressed: () => _openInMaps(lat, lng),
              child: const Icon(Icons.directions),
              tooltip: 'Abrir en Google Maps',
            ),
          ),
        ],
      ),
    );
  }

  // Abrir en Google Maps
  Future<void> _openInMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps')),
        );
      }
    }
  }

  // --- LÓGICA: EDITAR EVENTO (CON FECHA Y UBICACIÓN) ---
  void _showEditDialog(
    BuildContext context, 
    String currentTitle, 
    String currentDesc, 
    String creatorId, 
    Timestamp? existingTimestamp,
    double? existingLat,
    double? existingLng,
    String existingAddress,
  ) {
    final titleCtrl = TextEditingController(text: currentTitle);
    final descCtrl = TextEditingController(text: currentDesc);

    // Convertimos el timestamp existente a DateTime para manipularlo
    DateTime selectedDate = existingTimestamp != null
        ? existingTimestamp.toDate()
        : DateTime.now();
    
    // Variables para la ubicación
    double? selectedLat = existingLat;
    double? selectedLng = existingLng;
    String selectedAddress = existingAddress;

    showDialog(
      context: context,
      builder: (ctx) {
        // StatefulBuilder permite actualizar la fecha visualmente dentro del diálogo
        return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Text('Editar Evento'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Título'),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Descripción'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      // --- SELECTOR DE FECHA Y HORA ---
                      InkWell(
                        onTap: () async {
                          // 1. Fecha
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)), // Permitir el día de hoy
                            lastDate: DateTime(2100),
                          );
                          if (date == null) return;

                          // 2. Hora
                          if (!context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );
                          if (time == null) return;

                          // 3. Actualizar estado del diálogo
                          setStateDialog(() {
                            selectedDate = DateTime(
                                date.year, date.month, date.day,
                                time.hour, time.minute
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, color: Colors.indigo),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Fecha y Hora:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm').format(selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(Icons.edit, size: 18, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      // Advertencia si la fecha es pasada
                      if (selectedDate.isBefore(DateTime.now()))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '⚠️ La fecha ya pasó',
                            style: TextStyle(color: Colors.orange[700], fontSize: 12),
                          ),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // --- SELECTOR DE UBICACIÓN ---
                      const Text('Ubicación:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final result = await Navigator.of(context).push<Map<String, dynamic>>(
                            MaterialPageRoute(builder: (_) => const LocationPickerPage()),
                          );
                          
                          if (result != null) {
                            setStateDialog(() {
                              selectedLat = result['lat'];
                              selectedLng = result['lng'];
                              selectedAddress = result['address'];
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: selectedLat != null 
                                  ? Theme.of(context).colorScheme.primary 
                                  : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedLat != null 
                                        ? 'Ubicación seleccionada' 
                                        : 'Seleccionar ubicación',
                                      style: TextStyle(
                                        fontWeight: selectedLat != null 
                                          ? FontWeight.bold 
                                          : FontWeight.normal,
                                      ),
                                    ),
                                    if (selectedLat != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedAddress,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final newTitle = titleCtrl.text.trim();
                      final newDesc = descCtrl.text.trim();

                      if (newTitle.isEmpty) return;

                      // VALIDACIÓN: No permitir guardar fechas pasadas
                      if (selectedDate.isBefore(DateTime.now())) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Debes elegir una fecha futura'),
                                backgroundColor: Colors.red
                            )
                        );
                        return;
                      }

                      // VALIDACIÓN: Ubicación requerida
                      if (selectedLat == null || selectedLng == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Debes seleccionar una ubicación')),
                        );
                        return;
                      }

                      Navigator.pop(ctx); // Cerrar diálogo

                      final error = await _eventCtrl.updateEvent(
                          widget.eventId,
                          creatorId,
                          {
                            'title': newTitle,
                            'description': newDesc,
                            'date': Timestamp.fromDate(selectedDate),
                            'location': {
                              'lat': selectedLat,
                              'lng': selectedLng,
                              'address': selectedAddress,
                            },
                          }
                      );

                      if (mounted) {
                        if (error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error), backgroundColor: Colors.red),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Evento actualizado')),
                          );
                        }
                      }
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  // --- LÓGICA: BORRAR EVENTO ---
  Future<void> _confirmDelete(BuildContext context, String creatorId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar evento?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _eventCtrl.deleteEvent(widget.eventId, creatorId);
      if (mounted) Navigator.pop(context);
    }
  }

  // --- LÓGICA: SALIR DEL EVENTO ---
  Future<void> _confirmLeave(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir del evento?'),
        content: const Text('Dejarás de ver este evento en tu lista.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
        ],
      ),
    );

    if (confirm == true) {
      await _eventCtrl.leaveEvent(widget.eventId);
      if (mounted) Navigator.pop(context);
    }
  }

  // --- LÓGICA: UNIRSE AL EVENTO ---
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

    if (confirm == true && mounted) {
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
}