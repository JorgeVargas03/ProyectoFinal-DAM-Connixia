// (Solo los imports necesarios)
import 'dart:async';
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
import 'event_chats_list_page.dart';
import 'contacts_page.dart' as contacts;
import '../widgets/select_event_for_attendance_dialog.dart';
import 'attendance_history_page.dart';

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
  Set<Polyline> _polylines = {};
  Timer? _routeUpdateTimer;
  String? _currentOnTheWayEventId;

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
    // Verificar si hay eventos marcados como "en camino" y activar tracking
    _checkAndStartRouteTracking();
  }

  Future<void> _onArrivedShake() async {
    if (_postingArrival) return;
    setState(() => _postingArrival = true);
    await showDialog(
      context: context,
      barrierDismissible: false, // Evita cerrar tocando fuera
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
    _routeUpdateTimer?.cancel();
    super.dispose();
  }

  void _toggleMap() => setState(() => _showMap = !_showMap);

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
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
                final initial =
                    (name.isNotEmpty
                            ? name[0]
                            : (email.isNotEmpty ? email[0] : 'U'))
                        .toUpperCase();

                return UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary, // Color base original
                        Theme.of(context).brightness == Brightness.dark
                            ? Color.lerp(
                                colorScheme.primary,
                                Colors.black,
                                0.6,
                              )!
                            : Color.lerp(
                                colorScheme.primary,
                                Colors.white,
                                0.6,
                              )!,
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
                      backgroundImage: hasPhoto
                          ? NetworkImage(u.photoURL!)
                          : null,
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
                  MaterialPageRoute(builder: (_) => contacts.ContactsScreen()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Mis eventos'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const EventsPage()));
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                    content: Text('Contacta soporte@connixia.app'),
                  ),
                );
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: colorScheme.error),
              title: Text(
                'Cerrar sesión',
                style: TextStyle(color: colorScheme.error),
              ),
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
            background: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        isDark
                            ? Color.lerp(
                                colorScheme.primary,
                                Colors.black,
                                0.3,
                              )!
                            : Color.lerp(
                                colorScheme.primary,
                                Colors.white,
                                0.3,
                              )!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Text(
                    'Bienvenido',
                    style: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Notificaciones generales
            _buildAppBarNotificationButton(
              colorScheme: colorScheme,
              icon: Icons.notifications,
              tooltip: 'Notificaciones',
              notificationTypes: [
                'event_invitation',
                'attendance_confirmed',
                'event_update',
              ],
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
            ),
            // Mensajes de chats
            _buildAppBarNotificationButton(
              colorScheme: colorScheme,
              icon: Icons.chat_bubble_outline,
              tooltip: 'Mensajes',
              notificationTypes: ['event_message'],
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventChatsListPage()),
                );
              },
            ),
            // Solicitudes de amistad
            _buildAppBarFriendRequestButton(
              colorScheme: colorScheme,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const contacts.FriendRequestsPage(),
                  ),
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
                              child: Icon(
                                Icons.person,
                                color: colorScheme.onPrimaryContainer,
                              ),
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
                              if (firestoreSnapshot.hasData &&
                                  firestoreSnapshot.data!.exists) {
                                final data =
                                    firestoreSnapshot.data!.data()
                                        as Map<String, dynamic>;
                                photoUrl = data['photoURL'];
                              }

                              final hasPhoto =
                                  photoUrl != null && photoUrl.isNotEmpty;
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
                                              backgroundColor:
                                                  colorScheme.primaryContainer,
                                              backgroundImage: hasPhoto
                                                  ? NetworkImage(photoUrl)
                                                  : null,
                                              child: hasPhoto
                                                  ? null
                                                  : Text(
                                                      _userInitial(),
                                                      style: TextStyle(
                                                        fontSize: 28,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: colorScheme
                                                            .onPrimaryContainer,
                                                      ),
                                                    ),
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              userName,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            if (userEmail.isNotEmpty)
                                              Text(
                                                userEmail,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // Estadísticas con Tap Individual
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest
                                          .withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: FutureBuilder<int>(
                                      future: _getAttendedEventsCount(u.uid),
                                      builder: (context, attendedSnapshot) {
                                        final attendedCount =
                                            attendedSnapshot.data ?? 0;

                                        return Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const EventsPage(),
                                                    ),
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: _buildStat(
                                                  context,
                                                  Icons.event,
                                                  '${myEvents.length}',
                                                  'Participando',
                                                  colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 50,
                                              color: colorScheme.outlineVariant,
                                            ),
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const EventsPage(
                                                            filterCreatedOnly:
                                                                true,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: _buildStat(
                                                  context,
                                                  Icons.create,
                                                  '$createdEvents',
                                                  'Creados',
                                                  colorScheme.secondary
                                                      .withOpacity(0.6),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 50,
                                              color: colorScheme.outlineVariant,
                                            ),
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const AttendanceHistoryPage(),
                                                    ),
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: _buildStat(
                                                  context,
                                                  Icons.check_circle,
                                                  '$attendedCount',
                                                  'Asistidos',
                                                  Colors.green,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // 📅 Eventos de Hoy
                                  _buildTodayEvents(u.uid, colorScheme),

                                  const SizedBox(height: 12),

                                  // 📩 Invitaciones a Eventos Pendientes
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('events')
                                        .where('invited', arrayContains: u.uid)
                                        .snapshots(),
                                    builder: (context, inviteSnapshot) {
                                      if (!inviteSnapshot.hasData)
                                        return const SizedBox.shrink();

                                      final allInvites =
                                          inviteSnapshot.data!.docs;
                                      final pendingInvites = allInvites.where((
                                        doc,
                                      ) {
                                        final data =
                                            doc.data() as Map<String, dynamic>;
                                        final participants = List.from(
                                          data['participants'] ?? [],
                                        );
                                        return !participants.contains(u.uid);
                                      }).toList();

                                      if (pendingInvites.isEmpty)
                                        return const SizedBox.shrink();

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.tertiaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (_) =>
                                                  _buildPendingInvitesSheet(
                                                    pendingInvites,
                                                  ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
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
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Invitaciones a eventos',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .tertiary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Tienes ${pendingInvites.length} ${pendingInvites.length == 1 ? 'invitación pendiente' : 'invitaciones pendientes'}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .onTertiaryContainer,
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
                                      if (!contactSnapshot.hasData)
                                        return const SizedBox.shrink();

                                      final pendingRequests =
                                          contactSnapshot.data!.docs;

                                      if (pendingRequests.isEmpty)
                                        return const SizedBox.shrink();

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (_) =>
                                                  _buildPendingContactsSheet(
                                                    pendingRequests,
                                                  ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.secondary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.person_add,
                                                  color:
                                                      colorScheme.onSecondary,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Solicitudes de contacto',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .secondary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Tienes ${pendingRequests.length} ${pendingRequests.length == 1 ? 'solicitud pendiente' : 'solicitudes pendientes'}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .onSecondaryContainer,
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

                                  const SizedBox(height: 12),

                                  // ✅ Últimos Eventos Asistidos
                                  _buildRecentAttendedEvents(
                                    u.uid,
                                    colorScheme,
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
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ExploreEventsPage(),
                      ),
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
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: colorScheme.primary,
                  ),
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
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: colorScheme.primary,
                  ),
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
                  leading: Icon(
                    Icons.notifications,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Notificaciones'),
                  subtitle: const Text(
                    'Mantente informado de las últimas noticias',
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsPage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 140),
            ]),
          ),
        ),
      ],
    );
  }

  // Reemplaza tu método _buildMapView() actual por este:
  Widget _buildMapView() {
    if (_myPos == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- CAMBIO CLAVE: Usamos getNearbyEvents para una consulta más eficiente ---
    return StreamBuilder<QuerySnapshot>(
      stream: _eventCtrl.getNearbyEvents(
        userLat: _myPos!.latitude,
        userLng: _myPos!.longitude,
        radiusInKm: 50, // Radio de búsqueda de 50 km
      ),
      builder: (context, snapshot) {
        Set<Marker> eventMarkers = {};
        if (snapshot.hasData) {
          // Ahora _buildEventMarkers recibe los eventos ya pre-filtrados
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
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: const InfoWindow(title: 'Tu ubicación'),
            ),
            ...eventMarkers,
          },
          polylines: _polylines,
          onTap: (position) {},
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
                snippet:
                    '${participants.length} asistentes • ${distance.toStringAsFixed(1)} km',
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

  // --- MÉTODOS PARA TRACKING DE RUTA "EN CAMINO" ---

  // Verificar si hay eventos marcados como "en camino" al iniciar
  Future<void> _checkAndStartRouteTracking() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Buscar eventos donde el usuario está marcado como "en camino"
    final eventsSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    for (var eventDoc in eventsSnapshot.docs) {
      final onTheWayDoc = await eventDoc.reference
          .collection('onTheWay')
          .doc(currentUser.uid)
          .get();

      if (onTheWayDoc.exists && onTheWayDoc.data()?['isActive'] == true) {
        // Encontramos un evento marcado como "en camino"
        final eventData = eventDoc.data();
        final lat = eventData['location']?['lat'] as double?;
        final lng = eventData['location']?['lng'] as double?;

        if (lat != null && lng != null) {
          _currentOnTheWayEventId = eventDoc.id;
          await _updateRoutePolyline(lat, lng);

          // Iniciar actualización periódica cada 10 segundos
          _routeUpdateTimer = Timer.periodic(
            const Duration(seconds: 10),
            (_) => _updateRoutePolyline(lat, lng),
          );
          break; // Solo un evento a la vez
        }
      }
    }
  }

  // Actualizar la línea de ruta en el mapa
  Future<void> _updateRoutePolyline(double eventLat, double eventLng) async {
    try {
      final currentLocation = await _location.getCurrentPosition();

      if (currentLocation == null) return;

      // Crear una línea entre la ubicación actual y el evento
      final polyline = Polyline(
        polylineId: const PolylineId('route_to_event'),
        points: [currentLocation, LatLng(eventLat, eventLng)],
        color: Colors.blue,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      );

      if (mounted) {
        setState(() {
          _polylines = {polyline};
        });
      }
    } catch (e) {
      debugPrint('Error actualizando ruta: $e');
    }
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...requests.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final senderId = data['senderId'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(senderId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const ListTile(title: Text('Cargando...'));
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
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
        {
          'contacts': FieldValue.arrayUnion([senderId]),
        },
      );
      transaction.update(
        FirebaseFirestore.instance.collection('users').doc(senderId),
        {
          'contacts': FieldValue.arrayUnion([uid]),
        },
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
    await FirebaseFirestore.instance
        .collection('contactRequests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  Widget _buildStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
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

  // Obtener conteo de eventos asistidos
  Future<int> _getAttendedEventsCount(String userId) async {
    try {
      final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('participants', arrayContains: userId)
          .get();

      int count = 0;
      for (var eventDoc in eventsQuery.docs) {
        final attendanceDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventDoc.id)
            .collection('attendance')
            .doc(userId)
            .get();

        if (attendanceDoc.exists &&
            attendanceDoc.data()?['status'] == 'confirmed') {
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  // Widget de eventos de hoy
  Widget _buildTodayEvents(String userId, ColorScheme colorScheme) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('participants', arrayContains: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('date', isLessThan: Timestamp.fromDate(todayEnd))
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final events = snapshot.data!.docs;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer,
                colorScheme.secondaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.today,
                        color: colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Eventos de Hoy',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                          Text(
                            '${events.length} ${events.length == 1 ? 'evento' : 'eventos'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: events.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final event = events[index];
                  final data = event.data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Sin título';
                  final eventDate = (data['date'] as Timestamp).toDate();
                  final address =
                      data['location']?['address'] ?? 'Sin ubicación';

                  final difference = eventDate.difference(now);

                  // Verificar estado de confirmación
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('events')
                        .doc(event.id)
                        .collection('attendance')
                        .doc(userId)
                        .get(),
                    builder: (context, attendanceSnapshot) {
                      final hasConfirmed =
                          attendanceSnapshot.hasData &&
                          attendanceSnapshot.data!.exists &&
                          (attendanceSnapshot.data!.data()
                                  as Map<String, dynamic>?)?['status'] ==
                              'confirmed';

                      // Determinar estado y tiempo restante
                      String timeLeft;
                      Color countdownColor;
                      IconData statusIcon;
                      bool showConfirmedBadge = false;
                      String? badgeText;

                      if (hasConfirmed) {
                        if (difference.inMinutes < 0) {
                          // Evento confirmado y finalizado
                          timeLeft = 'Completado';
                          countdownColor = Colors.green;
                          statusIcon = Icons.check_circle;
                          showConfirmedBadge =
                              false; // No mostrar badge adicional
                        } else if (difference.inHours > 0) {
                          timeLeft = '${difference.inHours}h';
                          countdownColor = Colors.blue;
                          statusIcon = Icons.check_circle;
                          showConfirmedBadge = true;
                          badgeText = '✓ Confirmado';
                        } else {
                          timeLeft = '${difference.inMinutes}m';
                          countdownColor = Colors.blue;
                          statusIcon = Icons.check_circle;
                          showConfirmedBadge = true;
                          badgeText = '✓ Confirmado';
                        }
                      } else if (difference.inMinutes < 0) {
                        timeLeft = 'Pasado';
                        countdownColor = Colors.grey;
                        statusIcon = Icons.history;
                      } else if (difference.inDays > 0) {
                        timeLeft = '${difference.inDays}d';
                        countdownColor = colorScheme.primary;
                        statusIcon = Icons.alarm;
                      } else if (difference.inHours > 0) {
                        timeLeft = '${difference.inHours}h';
                        countdownColor = Colors.orange;
                        statusIcon = Icons.alarm;
                      } else if (difference.inMinutes > 0) {
                        timeLeft = '${difference.inMinutes}m';
                        countdownColor = colorScheme.error;
                        statusIcon = Icons.notifications_active;
                      } else {
                        timeLeft = '¡Ahora!';
                        countdownColor = colorScheme.error;
                        statusIcon = Icons.notifications_active;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              showConfirmedBadge
                                  ? Colors.blue.shade50
                                  : colorScheme.primaryContainer.withOpacity(
                                      0.3,
                                    ),
                              showConfirmedBadge
                                  ? Colors.blue.shade100
                                  : colorScheme.secondaryContainer.withOpacity(
                                      0.3,
                                    ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: showConfirmedBadge
                                ? Colors.blue.withOpacity(0.5)
                                : colorScheme.primary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EventDetailPage(eventId: event.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Icono del evento
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.white.withOpacity(0.8)
                                        : colorScheme.surface.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: countdownColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    statusIcon,
                                    color: countdownColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Información del evento
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (showConfirmedBadge &&
                                          badgeText != null)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            badgeText!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.light
                                                  ? colorScheme.onSurface
                                                  : Colors.white,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Tiempo restante con degradado
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: timeLeft == 'Completado'
                                        ? 12
                                        : 16,
                                    vertical: timeLeft == 'Completado' ? 8 : 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        countdownColor,
                                        countdownColor.withOpacity(0.7),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: countdownColor.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (timeLeft == 'Completado')
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      Text(
                                        timeLeft == 'Completado'
                                            ? '✓'
                                            : timeLeft,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: timeLeft == 'Completado'
                                              ? 14
                                              : 18,
                                        ),
                                      ),
                                    ],
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
            ],
          ),
        );
      },
    );
  }

  // Widget de últimos eventos asistidos
  Widget _buildRecentAttendedEvents(String userId, ColorScheme colorScheme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getRecentAttendedEvents(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final recentEvents = snapshot.data!;

        return Container(
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Eventos Asistidos',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                          ),
                          Text(
                            'Últimos eventos confirmados',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.green.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...recentEvents.map((eventData) {
                final title = eventData['title'] as String;
                final date = eventData['date'] as DateTime;
                final eventId = eventData['eventId'] as String;

                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.event_available,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailPage(eventId: eventId),
                      ),
                    );
                  },
                );
              }).toList(),
              const Divider(height: 1),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AttendanceHistoryPage(),
                    ),
                  );
                },
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ver historial completo',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Obtener últimos 3 eventos asistidos
  Future<List<Map<String, dynamic>>> _getRecentAttendedEvents(
    String userId,
  ) async {
    try {
      final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('participants', arrayContains: userId)
          .get();

      List<Map<String, dynamic>> attendedEvents = [];

      for (var eventDoc in eventsQuery.docs) {
        final attendanceDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventDoc.id)
            .collection('attendance')
            .doc(userId)
            .get();

        if (attendanceDoc.exists &&
            attendanceDoc.data()?['status'] == 'confirmed') {
          final eventData = eventDoc.data();
          final confirmedAt =
              (attendanceDoc.data()?['confirmedAt'] as Timestamp?)?.toDate();

          attendedEvents.add({
            'eventId': eventDoc.id,
            'title': eventData['title'] ?? 'Evento',
            'date': (eventData['date'] as Timestamp).toDate(),
            'confirmedAt': confirmedAt ?? DateTime.now(),
          });
        }
      }

      // Ordenar por fecha de confirmación (más reciente primero)
      attendedEvents.sort(
        (a, b) => (b['confirmedAt'] as DateTime).compareTo(
          a['confirmedAt'] as DateTime,
        ),
      );

      // Retornar solo los últimos 3
      return attendedEvents.take(3).toList();
    } catch (e) {
      return [];
    }
  }

  // Encontrar el próximo evento a mostrar según la lógica híbrida
  Future<DocumentSnapshot?> _findNextDisplayableEvent(
    List<QueryDocumentSnapshot> events,
    String userId,
  ) async {
    final now = DateTime.now();

    for (var eventDoc in events) {
      final eventData = eventDoc.data() as Map<String, dynamic>;
      final eventDate = (eventData['date'] as Timestamp).toDate();
      final difference = eventDate.difference(now);

      // Verificar si hay confirmación
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventDoc.id)
          .collection('attendance')
          .doc(userId)
          .get();

      final hasConfirmed =
          attendanceDoc.exists &&
          attendanceDoc.data()?['status'] == 'confirmed';

      // Lógica híbrida:
      // - Si es futuro: siempre mostrar
      // - Si pasó y está confirmado: mostrar hasta 3h después
      // - Si pasó y NO está confirmado: mostrar hasta 1h después

      if (difference.inMinutes > 0) {
        // Evento futuro - siempre mostrar
        return eventDoc;
      } else if (hasConfirmed && difference.inHours > -3) {
        // Evento confirmado en las últimas 3 horas
        return eventDoc;
      } else if (!hasConfirmed && difference.inHours > -1) {
        // Evento no confirmado en la última hora
        return eventDoc;
      }
      // Si no cumple las condiciones, continuar con el siguiente
    }

    // No hay eventos que cumplan los criterios
    return null;
  }

  // Widget para botón de notificación en AppBar
  Widget _buildAppBarNotificationButton({
    required ColorScheme colorScheme,
    required IconData icon,
    required String tooltip,
    required List<String> notificationTypes,
    required VoidCallback onPressed,
  }) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: tooltip,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('type', whereIn: notificationTypes)
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unreadCount > 0
                    ? colorScheme.errorContainer.withOpacity(0.2)
                    : Colors.transparent,
              ),
              child: IconButton(
                icon: Icon(icon),
                onPressed: onPressed,
                tooltip: tooltip,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
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
    );
  } // Widget para botón de solicitudes de amistad en AppBar

  Widget _buildAppBarFriendRequestButton({
    required ColorScheme colorScheme,
    required VoidCallback onPressed,
  }) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return IconButton(
        icon: const Icon(Icons.person_add_outlined),
        onPressed: onPressed,
        tooltip: 'Solicitudes',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friend_requests')
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unreadCount > 0
                    ? colorScheme.primaryContainer.withOpacity(0.3)
                    : Colors.transparent,
              ),
              child: IconButton(
                icon: const Icon(Icons.person_add_outlined),
                onPressed: onPressed,
                tooltip: 'Solicitudes',
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
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
    );
  } // Widget para los botones de notificaciones centralizados

  Widget _buildNotificationButtons(String userId, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _buildNotificationButton(
              userId: userId,
              icon: Icons.notifications,
              label: 'General',
              notificationType: [
                'event_invitation',
                'attendance_confirmed',
                'event_update',
              ],
              color: colorScheme.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildNotificationButton(
              userId: userId,
              icon: Icons.chat_bubble,
              label: 'Mensajes',
              notificationType: ['event_message'],
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EventChatsListPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFriendRequestButton(
              userId: userId,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const contacts.FriendRequestsPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget individual para cada botón de notificación
  Widget _buildNotificationButton({
    required String userId,
    required IconData icon,
    required String label,
    required List<String> notificationType,
    required Color color,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('type', whereIn: notificationType)
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
        }

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Icon(icon, color: color, size: 28),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget especial para botón de solicitudes de amistad (usa contactRequests)
  Widget _buildFriendRequestButton({
    required String userId,
    required Color color,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('contactRequests')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
        }

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Icon(Icons.person_add, color: color, size: 28),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Solicitudes',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
