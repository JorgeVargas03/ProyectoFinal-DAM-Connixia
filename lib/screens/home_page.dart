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
import '../widgets/select_event_for_attendance_dialog.dart';

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
    setState(() => _postingArrival = true);
    await showDialog(
      context: context,
      barrierDismissible: false,  // Evita cerrar tocando fuera
      builder: (_) => const SelectEventForAttendanceDialog(),
    );
    if (mounted) {
      setState(() => _postingArrival = false);
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
                  child: StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.userChanges(),
                    builder: (context, authSnapshot) {
                      final u = authSnapshot.data;
                      if (u == null) {
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Cargando perfil...',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('events')
                            .where('participants', arrayContains: u.uid)
                            .snapshots(),
                        builder: (context, eventSnapshot) {
                          final myEvents = eventSnapshot.data?.docs ?? [];
                          final createdEvents = myEvents.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['creatorId'] == u.uid;
                          }).length;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(u.uid)
                                .get(),
                            builder: (context, firestoreSnapshot) {
                              String? photoUrl;
                              if (firestoreSnapshot.hasData && firestoreSnapshot.data!.exists) {
                                final data = firestoreSnapshot.data!.data() as Map<String, dynamic>;
                                photoUrl = data['photoURL'];
                              }

                              final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
                              final userName = u.displayName ?? 'Usuario';
                              final userEmail = u.email ?? '';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header con Avatar y Nombre (Sin tap general)
                                  Row(
                                    children: [
                                      // Avatar con tap solo para editar foto
                                      InkWell(
                                        onTap: _openProfile,
                                        borderRadius: BorderRadius.circular(35),
                                        child: Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 35,
                                              backgroundColor: colorScheme.primaryContainer,
                                              backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                                              child: hasPhoto
                                                  ? null
                                                  : Text(
                                                _userInitial(),
                                                style: TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: colorScheme.surface,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.edit,
                                                  size: 14,
                                                  color: colorScheme.onPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              userName,
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            if (userEmail.isNotEmpty)
                                              Text(
                                                userEmail,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  // Estadísticas con Tap Individual
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        // Tap en "Participando" → Ver eventos donde participo
                                        InkWell(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => const EventsPage(),
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: _buildStat(
                                            context,
                                            Icons.event,
                                            '${myEvents.length}',
                                            'Participando',
                                            colorScheme.primary,
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 50,
                                          color: colorScheme.outlineVariant,
                                        ),
                                        // Tap en "Creados" → Ver solo eventos creados por mí
                                        InkWell(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => const EventsPage(),
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: _buildStat(
                                            context,
                                            Icons.create,
                                            '$createdEvents',
                                            'Creados',
                                            colorScheme.tertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Acciones Rápidas (Botones)
                                  const SizedBox(height: 16),

// ⏰ Próximo Evento con Countdown
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('events')
                                        .where('participants', arrayContains: u.uid)
                                        .where('date', isGreaterThan: Timestamp.now())
                                        .orderBy('date')
                                        .limit(1)
                                        .snapshots(),
                                    builder: (context, nextSnapshot) {
                                      if (!nextSnapshot.hasData || nextSnapshot.data!.docs.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      final nextEvent = nextSnapshot.data!.docs.first;
                                      final data = nextEvent.data() as Map<String, dynamic>;
                                      final title = data['title'] ?? 'Evento';
                                      final eventDate = (data['date'] as Timestamp).toDate();
                                      final now = DateTime.now();
                                      final difference = eventDate.difference(now);

                                      String timeLeft;
                                      Color countdownColor;
                                      if (difference.inDays > 0) {
                                        timeLeft = '${difference.inDays}d';
                                        countdownColor = colorScheme.primary;
                                      } else if (difference.inHours > 0) {
                                        timeLeft = '${difference.inHours}h';
                                        countdownColor = Colors.orange;
                                      } else if (difference.inMinutes > 0) {
                                        timeLeft = '${difference.inMinutes}m';
                                        countdownColor = colorScheme.error;
                                      } else {
                                        timeLeft = '¡Ahora!';
                                        countdownColor = colorScheme.error;
                                      }

                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              colorScheme.primaryContainer,
                                              colorScheme.secondaryContainer,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: colorScheme.primary.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => EventDetailPage(eventId: nextEvent.id),
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).brightness == Brightness.light
                                                      ? Colors.white.withOpacity(0.2)
                                                      : colorScheme.primary.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  Icons.alarm,
                                                  color: Theme.of(context).brightness == Brightness.light
                                                      ? Colors.white
                                                      : colorScheme.primary,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Próximo evento',
                                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                        color: Theme.of(context).brightness == Brightness.light
                                                            ? colorScheme.secondary.withOpacity(0.7)
                                                            : colorScheme.primary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      title,
                                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        color: Theme.of(context).brightness == Brightness.light
                                                            ? Colors.white
                                                            : Colors.white.withOpacity(0.8),
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${eventDate.day}/${eventDate.month}/${eventDate.year} a las ${eventDate.hour.toString().padLeft(2, '0')}:${eventDate.minute.toString().padLeft(2, '0')}',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: countdownColor,
                                                  borderRadius: BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: countdownColor.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  timeLeft,
                                                  style: TextStyle(
                                                    color: colorScheme.onPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 12),

// 📩 Invitaciones a Eventos Pendientes
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('events')
                                        .where('invited', arrayContains: u.uid)
                                        .snapshots(),
                                    builder: (context, inviteSnapshot) {
                                      if (!inviteSnapshot.hasData) return const SizedBox.shrink();

                                      final allInvites = inviteSnapshot.data!.docs;
                                      final pendingInvites = allInvites.where((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final participants = List.from(data['participants'] ?? []);
                                        return !participants.contains(u.uid);
                                      }).toList();

                                      if (pendingInvites.isEmpty) return const SizedBox.shrink();

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.tertiaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: colorScheme.tertiary,
                                            width: 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor: Colors.transparent,
                                              builder: (_) => _buildPendingInvitesSheet(pendingInvites),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.tertiary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.mail,
                                                  color: colorScheme.onTertiary,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Invitaciones a eventos',
                                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                        color: colorScheme.tertiary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Tienes ${pendingInvites.length} ${pendingInvites.length == 1 ? 'invitación pendiente' : 'invitaciones pendientes'}',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: colorScheme.onTertiaryContainer,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: colorScheme.tertiary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 12),

// 👥 Invitaciones de Contactos Pendientes
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('contactRequests')
                                        .where('receiverId', isEqualTo: u.uid)
                                        .where('status', isEqualTo: 'pending')
                                        .snapshots(),
                                    builder: (context, contactSnapshot) {
                                      if (!contactSnapshot.hasData) return const SizedBox.shrink();

                                      final pendingRequests = contactSnapshot.data!.docs;

                                      if (pendingRequests.isEmpty) return const SizedBox.shrink();

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: colorScheme.secondary,
                                            width: 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor: Colors.transparent,
                                              builder: (_) => _buildPendingContactsSheet(pendingRequests),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.secondary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.person_add,
                                                  color: colorScheme.onSecondary,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Solicitudes de contacto',
                                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                        color: colorScheme.secondary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Tienes ${pendingRequests.length} ${pendingRequests.length == 1 ? 'solicitud pendiente' : 'solicitudes pendientes'}',
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: colorScheme.onSecondaryContainer,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: colorScheme.secondary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                ],
                              );
                            },
                          );
                        },
                      );
                    },
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

    final twelveHoursAgo = DateTime.now().subtract(const Duration(hours: 12));

    for (var doc in events) {
      final data = doc.data() as Map<String, dynamic>;

      final Timestamp? eventTimestamp = data['date'];

      if (eventTimestamp != null) {
        final eventDate = eventTimestamp.toDate();

        if (eventDate.isBefore(twelveHoursAgo)) {
          continue;
        }
      }

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

// Modal para invitaciones de eventos
  Widget _buildPendingInvitesSheet(List<DocumentSnapshot> invites) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Invitaciones a Eventos',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...invites.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Evento';
            final date = (data['date'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.event, color: colorScheme.primary),
                title: Text(title),
                subtitle: date != null
                    ? Text('${date.day}/${date.month}/${date.year}')
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check, color: colorScheme.primary),
                      onPressed: () async {
                        await _acceptEventInvite(doc.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.error),
                      onPressed: () async {
                        await _rejectEventInvite(doc.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailPage(eventId: doc.id),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
//_openProfile
// Modal para solicitudes de contacto
  Widget _buildPendingContactsSheet(List<DocumentSnapshot> requests) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Solicitudes de Contacto',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...requests.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final senderId = data['senderId'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const ListTile(title: Text('Cargando...'));
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                final name = userData?['displayName'] ?? 'Usuario';
                final email = userData?['email'] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text(email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: colorScheme.primary),
                          onPressed: () async {
                            await _acceptContactRequest(doc.id, senderId);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: colorScheme.error),
                          onPressed: () async {
                            await _rejectContactRequest(doc.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ],
      ),
    );
  }

// Aceptar invitación a evento
  Future<void> _acceptEventInvite(String eventId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayUnion([uid]),
      'invited': FieldValue.arrayRemove([uid]),
    });
  }

// Rechazar invitación a evento
  Future<void> _rejectEventInvite(String eventId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('events').doc(eventId).update({
      'invited': FieldValue.arrayRemove([uid]),
    });
  }

// Aceptar solicitud de contacto
  Future<void> _acceptContactRequest(String requestId, String senderId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // Agregar a contactos mutuos
      transaction.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'contacts': FieldValue.arrayUnion([senderId])},
      );
      transaction.update(
        FirebaseFirestore.instance.collection('users').doc(senderId),
        {'contacts': FieldValue.arrayUnion([uid])},
      );

      // Actualizar estado de solicitud
      transaction.update(
        FirebaseFirestore.instance.collection('contactRequests').doc(requestId),
        {'status': 'accepted'},
      );
    });
  }

// Rechazar solicitud de contacto
  Future<void> _rejectContactRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('contactRequests').doc(requestId).update({
      'status': 'rejected',
    });
  }


  Widget _buildStat(BuildContext context, IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

}