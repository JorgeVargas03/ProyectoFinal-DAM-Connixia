import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shake/shake.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/notification_controller.dart';

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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myPos = await _location.getCurrentPosition();
    if (mounted) setState(() {});

    _shake = ShakeDetector.autoStart(
      onPhoneShake: (_) {
        _onArrivedShake();
      },
    );

    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) _notifications.showLocal(n.title ?? 'Notificación', n.body ?? '');
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
      await _notifications.showLocal('Llegada confirmada', 'Se notificó tu arribo al evento.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos cercanos'),
        actions: [IconButton(onPressed: _auth.signOut, icon: const Icon(Icons.logout))],
      ),
      body: _myPos == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        initialCameraPosition: CameraPosition(target: _myPos!, zoom: 15),
        onMapCreated: (c) => _mapCtrl = c,
        markers: {Marker(markerId: const MarkerId('yo'), position: _myPos!)},
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () {},
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Crear evento'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'arrive',
            onPressed: () => _onArrivedShake(),
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirmar llegada'),
          ),
        ],
      ),
    );
  }
}
