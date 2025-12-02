import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../admin/controllers/admin_controller.dart';
import '../../screens/event_detail_page.dart';

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  final AdminController _adminCtrl = AdminController();
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _filterStatus = 'all'; // all, active, cancelled, completed

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchEvents(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await _adminCtrl.searchEvents(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Eventos'),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por título...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _searchEvents('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _searchEvents,
                ),
                const SizedBox(height: 12),
                // Filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todos',
                        selected: _filterStatus == 'all',
                        onTap: () => setState(() => _filterStatus = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Activos',
                        selected: _filterStatus == 'active',
                        onTap: () => setState(() => _filterStatus = 'active'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Cancelados',
                        selected: _filterStatus == 'cancelled',
                        onTap: () =>
                            setState(() => _filterStatus = 'cancelled'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Completados',
                        selected: _filterStatus == 'completed',
                        onTap: () =>
                            setState(() => _filterStatus = 'completed'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Resultados
          Expanded(
            child: _searchResults.isNotEmpty
                ? _buildSearchResults()
                : _buildAllEvents(),
          ),
        ],
      ),
    );
  }

  // Mostrar resultados de búsqueda
  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final event = _searchResults[index];
        return _EventCard(
          event: event,
          adminCtrl: _adminCtrl,
          onUpdate: () => _searchEvents(_searchCtrl.text),
        );
      },
    );
  }

  // Mostrar todos los eventos con StreamBuilder
  Widget _buildAllEvents() {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminCtrl.getAllEvents(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var events = snapshot.data?.docs ?? [];

        // Aplicar filtro de estado
        if (_filterStatus != 'all') {
          events = events.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == _filterStatus;
          }).toList();
        }

        if (events.isEmpty) {
          return const Center(
            child: Text('No hay eventos que coincidan con el filtro'),
          );
        }

        return ListView.builder(
          itemCount: events.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final eventDoc = events[index];
            final event = {
              'id': eventDoc.id,
              ...eventDoc.data() as Map<String, dynamic>,
            };
            return _EventCard(
              event: event,
              adminCtrl: _adminCtrl,
              onUpdate: () {}, // No necesita actualizar en stream
            );
          },
        );
      },
    );
  }
}

// Widget de filtro chip
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }
}

// Widget de tarjeta de evento
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final AdminController adminCtrl;
  final VoidCallback onUpdate;

  const _EventCard({
    required this.event,
    required this.adminCtrl,
    required this.onUpdate,
  });

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'active':
        return 'ACTIVO';
      case 'cancelled':
        return 'CANCELADO';
      case 'completed':
        return 'COMPLETADO';
      default:
        return 'DESCONOCIDO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final eventId = event['id'] ?? '';
    final title = event['title'] ?? 'Sin título';
    final description = event['description'] ?? '';
    final status = event['status'];
    final privacy = event['privacy'] ?? 'public';
    final creatorId = event['creatorId'];
    final participants = event['participants'] as List? ?? [];
    final date = event['date'] as Timestamp?;
    final createdAt = event['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          privacy == 'private' ? Icons.lock : Icons.public,
          color: privacy == 'private' ? Colors.orange : Colors.blue,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusLabel(status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${participants.length} participantes',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(date.toDate()),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID: $eventId',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                if (creatorId != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(creatorId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final creator =
                            snapshot.data!.data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Creador: ${creator['displayName'] ?? 'Sin nombre'} (${creator['email']})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Creado: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate())}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Botón para ver detalles del evento
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EventDetailPage(eventId: eventId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('Ver Evento'),
                    ),

                    // Botón para eliminar evento
                    ElevatedButton.icon(
                      onPressed: () => _deleteEvent(context, eventId, title),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Eliminar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(
    BuildContext context,
    String eventId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Evento'),
        content: Text(
          '¿Estás seguro de que quieres eliminar el evento "$title"?\n\n'
          'Esta acción no se puede deshacer y eliminará:\n'
          '• El evento\n'
          '• Todos los mensajes\n'
          '• Registros de asistencia\n'
          '• Datos de participantes',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final error = await adminCtrl.deleteEvent(eventId);

      if (context.mounted) {
        Navigator.pop(context); // Cerrar indicador de carga

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Evento eliminado exitosamente'),
            backgroundColor: error == null ? Colors.green : Colors.red,
          ),
        );

        if (error == null) onUpdate();
      }
    }
  }
}
