import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:proyectofinal_connixia/screens/configuration_page.dart';
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
      if (n != null)
        _notifications.showLocal(n.title ?? 'Notificación', n.body ?? '');
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

  void _toggleMap() {
    setState(() => _showMap = !_showMap);
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
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: const Center(
                child: Text(
                  'Encuentra y crea eventos cerca de ti',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(_showMap ? Icons.map : Icons.map_outlined),
              onPressed: _toggleMap,
              tooltip: 'Ver mapa',
            ),
            IconButton(
              onPressed: _auth.signOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Tarjetas de acciones rápidas
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 3,
                      child: InkWell(
                        onTap: () {
                          // abrir pantalla de crear evento (placeholder)
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.add_location_alt, size: 36),
                              SizedBox(height: 8),
                              Text(
                                'Crear evento',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text('Propón un punto en el mapa y una hora'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.people, size: 36),
                            SizedBox(height: 8),
                            Text(
                              'Buscar gente',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Une con personas interesadas en planear salidas',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Próximos eventos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Lista demo de eventos
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Café en la plaza'),
                  subtitle: const Text('Hoy · 18:30'),
                  trailing: ElevatedButton(
                    onPressed: () => setState(() => _showMap = true),
                    child: const Text('Ver en mapa'),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.hiking),
                  title: const Text('Caminata por el parque'),
                  subtitle: const Text('Mañana · 09:00'),
                  trailing: ElevatedButton(
                    onPressed: () => setState(() => _showMap = true),
                    child: const Text('Ver en mapa'),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return _myPos == null
        ? const Center(child: CircularProgressIndicator())
        : GoogleMap(
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            initialCameraPosition: CameraPosition(target: _myPos!, zoom: 15),
            onMapCreated: (c) => _mapCtrl = c,
            markers: {
              Marker(markerId: const MarkerId('yo'), position: _myPos!),
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.userChanges(),
                builder: (context, snapshot) {
                  final u = snapshot.data ?? FirebaseAuth.instance.currentUser;
                  final name = (u?.displayName ?? '').trim();
                  final email = (u?.email ?? '').trim();
                  final initial =
                  (name.isNotEmpty ? name[0] : (email.isNotEmpty ? email[0] : 'U')).toUpperCase();

                  return UserAccountsDrawerHeader(
                    accountName: Text(name.isNotEmpty ? name : 'Usuario'),
                    accountEmail: Text(email),
                    currentAccountPicture: CircleAvatar(
                      child: Text(
                        initial,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Perfil'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Configuración'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConfigurationPage()),
                  );
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesión'),
                onTap: _auth.signOut,
              ),
            ],
          ),
        ),
      ),
      // FIX: acotar tamaño para evitar altura infinita
      body: SizedBox.expand(
        child: AnimatedCrossFade(
          firstChild: SizedBox.expand(child: _buildDashboard(context)),
          secondChild: SizedBox.expand(child: _buildMapView()),
          crossFadeState: _showMap ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 350),
          // Opcional: mantener tamaño durante transición
          layoutBuilder: (topChild, topKey, bottomChild, bottomKey) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(key: bottomKey, child: bottomChild),
                Positioned.fill(key: topKey, child: topChild),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () {
              // Abrir creación de evento (pendiente)
            },
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Crear evento'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'arrive',
            onPressed: _onArrivedShake,
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirmar llegada'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'toggleMap',
            onPressed: _toggleMap,
            child: Icon(_showMap ? Icons.home : Icons.map),
            tooltip: _showMap ? 'Volver al inicio' : 'Ver mapa',
          ),
        ],
      ),
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
