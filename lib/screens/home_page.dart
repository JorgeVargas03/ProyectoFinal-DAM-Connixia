// (Solo los imports necesarios)
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shake/shake.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/event_controller.dart';
import '../services/notification_service.dart';
import 'profile_page.dart';
import 'events_page.dart';
import 'explore_events_page.dart';
import 'event_detail_page.dart';
import 'notifications_page.dart';
import 'contacts_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = AuthController();
  final _location = LocationController();
  final _notifications = NotificationController();
  final _eventCtrl = EventController();
  final _notificationService = NotificationService();

  GoogleMapController? _mapCtrl;
  LatLng? _myPos;
  ShakeDetector? _shake;
  bool _postingArrival = false;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myPos = await _location.getCurrentPosition();
    if (mounted) setState(() {});
    _shake = ShakeDetector.autoStart(onPhoneShake: (_) => _onArrivedShake());
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        _notifications.showLocal(n.title ?? 'Notificación', n.body ?? '');
      }
    });
  }

  Future<void> _onArrivedShake() async {
    if (_postingArrival) return;
    _postingArrival = true;
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      const eventId = 'demo-event';
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('arrivals')
          .doc(uid)
          .set({
        'uid': uid,
        'at': FieldValue.serverTimestamp(),
        'lat': _myPos?.latitude,
        'lng': _myPos?.longitude,
      }, SetOptions(merge: true));
      await _notifications.showLocal(
        'Llegada confirmada',
        'Se notificó tu arribo al evento.',
      );
    } finally {
      _postingArrival = false;
    }
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _shake?.stopListening();
    super.dispose();
  }

  void _toggleMap() => setState(() => _showMap = !_showMap);

  void _openProfile() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tomamos los colores del tema
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: _buildDrawer(colorScheme), // Pasamos el esquema de color
      body: _showMap ? _buildMapView() : _buildDashboard(context),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'map',
            onPressed: _toggleMap,
            // Colores dinámicos
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            icon: Icon(_showMap ? Icons.dashboard : Icons.map),
            label: Text(_showMap ? 'Panel' : 'Mapa'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'arrive',
            onPressed: _onArrivedShake,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Llegué'),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer(ColorScheme colorScheme) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            StreamBuilder<User?>(
              stream: FirebaseAuth.instance.userChanges(),
              builder: (context, snapshot) {
                final u = snapshot.data ?? FirebaseAuth.instance.currentUser;
                final name = (u?.displayName ?? '').trim();
                final email = (u?.email ?? '').trim();
                final hasPhoto = u?.photoURL != null && u!.photoURL!.isNotEmpty;
                final initial = (name.isNotEmpty
                    ? name[0]
                    : (email.isNotEmpty ? email[0] : 'U'))
                    .toUpperCase();

                return UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary, // Color base original
                        Theme.of(context).brightness == Brightness.dark
                            ? Color.lerp(colorScheme.primary, Colors.black, 0.6)!
                            : Color.lerp(colorScheme.primary, Colors.white, 0.6)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  accountName: Text(
                    name.isNotEmpty ? name : 'Usuario',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  accountEmail: Text(email),
                  currentAccountPicture: InkWell(
                    onTap: _openProfile,
                    borderRadius: BorderRadius.circular(40),
                    child: CircleAvatar(
                      backgroundColor: colorScheme.surface,
                      backgroundImage:
                      hasPhoto ? NetworkImage(u.photoURL!) : null,
                      child: hasPhoto
                          ? null
                          : Text(
                        initial,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            ListTile(
              leading: Icon(Icons.home, color: colorScheme.primary),
              title: const Text('Inicio'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Mi perfil'),
              onTap: _openProfile,
            ),

            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Mis Contactos'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ContactsScreen()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Mis eventos'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EventsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.explore),
              title: const Text('Explorar eventos'),
              subtitle: const Text('Descubre eventos cerca de ti'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExploreEventsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notificaciones'),
              trailing: StreamBuilder<int>(
                stream: _notificationService.getUnreadCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: TextStyle(
                        color: colorScheme.onError,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Ayuda'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Contacta soporte@connixia.app')),
                );
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: colorScheme.error),
              title: Text('Cerrar sesión',
                  style: TextStyle(color: colorScheme.error)),
              onTap: _auth.signOut,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 140,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              'Bienvenido',
              style: TextStyle(
                // Texto: Blanco si es tema Claro, Negro si es tema Oscuro
                color: isDark ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold, // Opcional, mejora la legibilidad
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    isDark
                        ? Color.lerp(colorScheme.primary, Colors.black, 0.3)!
                        : Color.lerp(colorScheme.primary, Colors.white, 0.3)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          actions: [
            // Notificaciones con badge
            StreamBuilder<int>(
              stream: _notificationService.getUnreadCount(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsPage(),
                          ),
                        );
                      },
                      tooltip: 'Notificaciones',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: TextStyle(
                              color: colorScheme.onError,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              icon: Icon(_showMap ? Icons.dashboard : Icons.map),
              onPressed: _toggleMap,
              tooltip: _showMap ? 'Ver panel' : 'Ver mapa',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _auth.signOut,
              tooltip: 'Cerrar sesión',
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          _userInitial(),
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Aquí irá tu resumen.\n(Sección personalizable).',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Icon(Icons.explore, color: colorScheme.primary),
                  title: const Text('Explorar eventos'),
                  subtitle: const Text('Descubre eventos cerca de ti'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.primary),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExploreEventsPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline, color: colorScheme.primary),
                  title: const Text('Confirmar llegada'),
                  subtitle: const Text('También puedes agitar el teléfono'),
                  onTap: _onArrivedShake,
                  trailing: _postingArrival
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.navigate_next),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Icon(Icons.event, color: colorScheme.primary),
                  title: const Text('Eventos'),
                  subtitle: const Text('Administra tus puntos de encuentro'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.primary),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EventsPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Icon(Icons.notifications, color: colorScheme.primary),
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Centro próximamente'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationsPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 120),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    if (_myPos == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _eventCtrl.getAllPublicEvents(),
      builder: (context, snapshot) {
        Set<Marker> eventMarkers = {};
        if (snapshot.hasData) {
          eventMarkers = _buildEventMarkers(snapshot.data!.docs);
        }

        return GoogleMap(
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          initialCameraPosition: CameraPosition(target: _myPos!, zoom: 13),
          onMapCreated: (c) => _mapCtrl = c,
          markers: {
            Marker(
              markerId: const MarkerId('mi_ubicacion'),
              position: _myPos!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'Tu ubicación'),
            ),
            ...eventMarkers,
          },
          onTap: (position) {
          },
        );
      },
    );
  }

  Set<Marker> _buildEventMarkers(List<DocumentSnapshot> events) {
    final markers = <Marker>{};
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    for (var doc in events) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['location']?['lat'] as double?;
      final lng = data['location']?['lng'] as double?;
      final title = data['title'] ?? 'Evento';
      final creatorId = data['creatorId'];
      final participants = List.from(data['participants'] ?? []);

      if (lat != null && lng != null && _myPos != null) {
        final distance = _eventCtrl.calculateDistance(
          _myPos!.latitude,
          _myPos!.longitude,
          lat,
          lng,
        );

        if (distance <= 50) {
          final isMyEvent = creatorId == myUid;
          markers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                isMyEvent ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
              ),
              infoWindow: InfoWindow(
                title: title,
                snippet: '${participants.length} asistentes • ${distance.toStringAsFixed(1)} km',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventDetailPage(eventId: doc.id),
                  ),
                );
              },
            ),
          );
        }
      }
    }

    return markers;
  }

  String _userInitial() {
    final u = FirebaseAuth.instance.currentUser;
    final name = (u?.displayName ?? '').trim();
    final email = (u?.email ?? '').trim();
    final source = name.isNotEmpty ? name : (email.isNotEmpty ? email : 'U');
    return source.characters.first.toUpperCase();
  }
}