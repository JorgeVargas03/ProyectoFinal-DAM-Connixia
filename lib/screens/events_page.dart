import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../controllers/event_controller.dart';
import 'event_detail_page.dart';
import 'location_picker_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EventsPage extends StatefulWidget {
  final bool filterCreatedOnly;

  final LatLng? initialLocation;

  const EventsPage({
    super.key,
    this.filterCreatedOnly = false,
    this.initialLocation,
  });

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _eventCtrl = EventController();

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCreateEventDialog(preselectedLocation: widget.initialLocation);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCreateEventDialog(preselectedLocation: widget.initialLocation);
      });
    }
  }

  // Estado para el filtro de tiempo: 'all', 'upcoming', 'past'
  String _timeFilter = 'all';

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '--';
    return DateFormat('dd MMM HH:mm', 'es').format(timestamp.toDate());
  }

  // --- NUEVO HELPER para obtener icono de privacidad ---
  Icon _getPrivacyIcon(String? privacy, {double size = 16}) {
    switch (privacy) {
      case 'public':
        return Icon(Icons.public, color: Colors.green, size: size);
      case 'semi-private':
        return Icon(Icons.people, color: Colors.orange, size: size);
      case 'private':
        return Icon(Icons.lock, color: Colors.red, size: size);
      default:
        return Icon(Icons.public, color: Colors.grey, size: size);
    }
  }

  // --- NUEVO HELPER para obtener texto de privacidad ---
  String _getPrivacyText(String? privacy) {
    switch (privacy) {
      case 'public':
        return 'Público';
      case 'semi-private':
        return 'Semiprivado';
      case 'private':
        return 'Privado';
      default:
        return 'No definido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.filterCreatedOnly ? 'Eventos Creados' : 'Mis Eventos',
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- BARRA DE FILTROS DE TIEMPO ---
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('Todos', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Próximos', 'upcoming'),
                const SizedBox(width: 8),
                _buildFilterChip('Pasados', 'past'),
              ],
            ),
          ),

          // --- LISTA DE EVENTOS ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _eventCtrl.getMyEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var docs = snapshot.data?.docs ?? [];
                final now = DateTime.now();

                // 1. FILTRO: Creados vs Todos (Lógica anterior)
                if (widget.filterCreatedOnly && myUid != null) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['creatorId'] == myUid;
                  }).toList();
                }

                // 2. FILTRO: Tiempo (Próximos vs Pasados)
                if (_timeFilter != 'all') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final date = (data['date'] as Timestamp?)?.toDate();
                    if (date == null) return false;

                    if (_timeFilter == 'upcoming') {
                      return date.isAfter(now);
                    } else {
                      // 'past'
                      return date.isBefore(now);
                    }
                  }).toList();
                }

                // 3. ORDENAMIENTO (Mejora de UX)
                docs.sort((a, b) {
                  final dateA =
                      (a.data() as Map<String, dynamic>)['date'] as Timestamp?;
                  final dateB =
                      (b.data() as Map<String, dynamic>)['date'] as Timestamp?;

                  if (dateA == null || dateB == null) return 0;

                  // Si son pasados, queremos ver el más reciente primero (Descendente)
                  // Si son próximos o todos, queremos ver el más cercano primero (Ascendente)
                  if (_timeFilter == 'past') {
                    return dateB.compareTo(dateA);
                  } else {
                    return dateA.compareTo(dateB);
                  }
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getEmptyMessage(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final eventId = doc.id;

                    final title = data['title'] ?? 'Sin título';
                    final creatorId = data['creatorId'] ?? '';
                    final creatorName = data['creatorName'] ?? 'Alguien';
                    final date = data['date'] as Timestamp?;
                    final address =
                        data['location']?['address'] ?? 'Ubicación desconocida';

                    final isCreator = (myUid == creatorId);
                    final isPast = date?.toDate().isBefore(now) ?? false;

                    return Opacity(
                      // Efecto visual: si ya pasó, se ve un poco más transparente
                      opacity: isPast ? 0.7 : 1.0,
                      child: Card(
                        elevation: isPast ? 1 : 3, // Menos sombra si ya pasó
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: isPast
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey.withOpacity(0.1)
                                  : Colors.grey[300])
                            : null,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isPast
                                  ? Colors.grey.withOpacity(0.1)
                                  : colorScheme.primaryContainer.withOpacity(
                                      0.3,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isPast ? Icons.history : Icons.location_on,
                              color: isPast
                                  ? Colors.grey[600]
                                  : colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: isPast
                                  ? TextDecoration.lineThrough
                                  : null, // Tachado opcional si ya pasó
                              color: isPast ? Colors.grey[700] : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(date),
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isCreator
                                    ? 'Organizado por ti'
                                    : 'Organiza: $creatorName',
                                style: TextStyle(
                                  color: isCreator
                                      ? Colors.green
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          trailing: isCreator
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Eliminar evento',
                                  onPressed: () =>
                                      _confirmDelete(eventId, creatorId),
                                )
                              : isPast
                              ? null // Si ya pasó, no mostramos nada (quita la opción de salir)
                              : IconButton(
                                  icon: const Icon(
                                    Icons.exit_to_app,
                                    color: Colors.orange,
                                  ),
                                  tooltip: 'Salir del evento',
                                  onPressed: () => _confirmLeave(eventId),
                                ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EventDetailPage(eventId: eventId),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEventDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Evento'),
      ),
    );
  }

  // --- WIDGET PARA LOS CHIPS DE FILTRO ---
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _timeFilter == value;
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() => _timeFilter = value);
        }
      },
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }

  // Mensaje dinámico cuando está vacío
  String _getEmptyMessage() {
    if (_timeFilter == 'upcoming') return 'No tienes eventos próximos';
    if (_timeFilter == 'past') return 'No tienes eventos pasados';
    return 'No tienes eventos activos';
  }

  Future<void> _confirmDelete(String eventId, String creatorId) async {
    // ... sin cambios ...
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar evento?'),
        content: const Text(
          'El evento se borrará para todos los participantes. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final error = await _eventCtrl.deleteEvent(eventId, creatorId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error ?? 'Evento eliminado')));
      }
    }
  }

  Future<void> _confirmLeave(String eventId) async {
    // ... sin cambios ...
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir del evento?'),
        content: const Text(
          'Ya no verás este evento en tu lista ni compartirás ubicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final error = await _eventCtrl.leaveEvent(eventId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error ?? 'Saliste del evento')));
      }
    }
  }

  void _showCreateEventDialog({LatLng? preselectedLocation}) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 2));

    double? selectedLat = preselectedLocation?.latitude;
    double? selectedLng = preselectedLocation?.longitude;
    String selectedAddress = preselectedLocation != null
        ? 'Ubicación seleccionada en el mapa'
        : 'Sin ubicación';

    String selectedPrivacy = 'public';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nuevo Punto de Encuentro'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ej. Cena de graduación',
                        prefixIcon: Icon(Icons.title),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // --- SELECTOR DE PRIVACIDAD ---
                    const Text(
                      'Visibilidad',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedPrivacy,
                      decoration: InputDecoration(
                        prefixIcon: _getPrivacyIcon(selectedPrivacy, size: 20),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'public',
                          child: Text('Público'),
                        ),
                        DropdownMenuItem(
                          value: 'semi-private',
                          child: Text('Semiprivado (Contactos)'),
                        ),
                        DropdownMenuItem(
                          value: 'private',
                          child: Text('Privado (por invitación)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() {
                            selectedPrivacy = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // --- SELECTOR DE FECHA ---
                    const Text(
                      '¿Cuándo?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (date == null) return;

                        if (!context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (time == null) return;

                        final newDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                        setStateDialog(() => selectedDate = newDateTime);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.indigo,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat(
                                'dd/MM/yyyy HH:mm',
                                'es',
                              ).format(selectedDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Mensaje de error si la fecha es pasada (validación visual)
                    if (selectedDate.isBefore(DateTime.now()))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '¡Cuidado! La fecha ya pasó.',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // --- SELECTOR DE UBICACIÓN ---
                    const Text(
                      '¿Dónde?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final result = await Navigator.of(context)
                            .push<Map<String, dynamic>>(
                              MaterialPageRoute(
                                builder: (_) => const LocationPickerPage(),
                              ),
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
                    final title = titleCtrl.text.trim();

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('El título no puede estar vacío'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (selectedDate.isBefore(DateTime.now())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'La fecha del evento debe ser en el futuro',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (selectedLat == null || selectedLng == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Debes seleccionar una ubicación para el evento',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);

                    final error = await _eventCtrl.createEvent(
                      title: title, // Usamos la variable ya trimeada
                      description: descCtrl.text.trim(),
                      date: selectedDate,
                      lat: selectedLat!,
                      lng: selectedLng!,
                      address: selectedAddress,
                      privacy: selectedPrivacy,
                    );

                    if (mounted && error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
