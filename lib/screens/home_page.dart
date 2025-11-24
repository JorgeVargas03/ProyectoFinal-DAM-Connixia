import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shake/shake.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/notification_controller.dart';
import 'profile_page.dart';
import 'package:characters/characters.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = AuthController();
  final _location = LocationController();
  final _notifications = NotificationController();

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
    return Scaffold(
      drawer: _buildDrawer(),
      body: _showMap ? _buildMapView() : _buildDashboard(context),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'map',
            onPressed: _toggleMap,
            icon: Icon(_showMap ? Icons.dashboard : Icons.map),
            label: Text(_showMap ? 'Panel' : 'Mapa'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'arrive',
            onPressed: _onArrivedShake,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Llegué'),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer() {
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
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                      backgroundColor: Colors.white,
                      backgroundImage: hasPhoto ? NetworkImage(u!.photoURL!) : null,
                      child: hasPhoto
                          ? null
                          : Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Mi perfil'),
              onTap: _openProfile,
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Mis eventos'),
              subtitle: const Text('Próximamente'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Función en desarrollo')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notificaciones'),
              subtitle: const Text('Próximamente'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Función en desarrollo')),
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
                  const SnackBar(content: Text('Contacta soporte@connixia.app')),
                );
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
              onTap: _auth.signOut,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 140,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('Bienvenido'),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          actions: [
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
                        child: Text(
                          _userInitial(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
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
                  leading: const Icon(Icons.check_circle_outline),
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
                  leading: const Icon(Icons.event),
                  title: const Text('Eventos'),
                  subtitle: const Text('Módulo próximamente'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Eventos aún no disponibles')),
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
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Centro próximamente'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Centro de notificaciones en desarrollo')),
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
    return GoogleMap(
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      initialCameraPosition: CameraPosition(target: _myPos!, zoom: 15),
      onMapCreated: (c) => _mapCtrl = c,
      markers: {
        Marker(markerId: const MarkerId('yo'), position: _myPos!),
      },
    );
  }

  String _userInitial() {
    final u = FirebaseAuth.instance.currentUser;
    final name = (u?.displayName ?? '').trim();
    final email = (u?.email ?? '').trim();
    final source = name.isNotEmpty ? name : (email.isNotEmpty ? email : 'U');
    return source.characters.first.toUpperCase();
  }
}
