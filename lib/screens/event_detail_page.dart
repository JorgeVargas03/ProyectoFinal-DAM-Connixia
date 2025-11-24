import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../controllers/event_controller.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _eventCtrl = EventController();
  final _currentUser = FirebaseAuth.instance.currentUser;

  // Formateador de fecha
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Fecha por definir';
    return DateFormat('EEEE d, MMMM yyyy - HH:mm', 'es').format(timestamp.toDate());
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
                    // PASAMOS LA FECHA ACTUAL (date) AL DIÁLOGO
                    onPressed: () => _showEditDialog(context, title, description, creatorId, date),
                  ),

                // Botón compartir (Visual)
                IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECCIÓN 1: EL MAPA (PLACEHOLDER) ---
                  _buildMapPlaceholder(),

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
                          Text(description, style: TextStyle(color: Colors.grey[800])),
                          const Divider(height: 40),
                        ],

                        // --- SECCIÓN 5: PARTICIPANTES (Resumen) ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Asistentes (${participants.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (isCreator)
                              const Chip(
                                label: Text('Eres admin'),
                                backgroundColor: Colors.green,
                                labelStyle: TextStyle(color: Colors.white),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Organizado por: $creatorName'),

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
                              : OutlinedButton.icon(
                            onPressed: () => _confirmLeave(context),
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('Salir del evento'),
                            style: OutlinedButton.styleFrom(
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

  // --- WIDGET DEL MAPA (HUECO) ---
  Widget _buildMapPlaceholder() {
    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.grey[200],
      child: Stack(
        children: [
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('Mapa interactivo'),
                Text('(Próximamente)', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'openMaps',
              onPressed: () {},
              child: const Icon(Icons.directions),
            ),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA: EDITAR EVENTO (CON FECHA) ---
  void _showEditDialog(BuildContext context, String currentTitle, String currentDesc, String creatorId, Timestamp? existingTimestamp) {
    final titleCtrl = TextEditingController(text: currentTitle);
    final descCtrl = TextEditingController(text: currentDesc);

    // Convertimos el timestamp existente a DateTime para manipularlo
    DateTime selectedDate = existingTimestamp != null
        ? existingTimestamp.toDate()
        : DateTime.now();

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
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                              'Advertencia: La fecha está en el pasado',
                              style: TextStyle(color: Colors.orange[800], fontSize: 12)
                          ),
                        )
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

                      Navigator.pop(ctx); // Cerrar diálogo

                      final error = await _eventCtrl.updateEvent(
                          widget.eventId,
                          creatorId,
                          {
                            'title': newTitle,
                            'description': newDesc,
                            'date': Timestamp.fromDate(selectedDate), // Guardamos la nueva fecha
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
}