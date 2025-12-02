import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/fullscreen_image_viewer.dart';
import 'event_detail_page.dart';
import 'attendance_history_page.dart';

class UserProfilePage extends StatefulWidget {
  final String targetUserId;
  final String? userName; // Opcional, para mostrar mientras carga

  const UserProfilePage({super.key, required this.targetUserId, this.userName});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  // Estados de la relación
  bool _isLoading = false;
  String _friendStatus =
      'none'; // 'none', 'pending_sent', 'pending_received', 'friends'

  @override
  void initState() {
    super.initState();
    _checkFriendStatus();
  }

  // Verificar estado de amistad (Lógica simulada, debes adaptarla a tu Controller)
  Future<void> _checkFriendStatus() async {
    if (_currentUser == null) return;

    final me = _currentUser!.uid;
    final target = widget.targetUserId;

    // 1. Checar si ya son amigos
    final friendDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(me)
        .collection('contacts')
        .doc(target)
        .get();

    if (friendDoc.exists) {
      setState(() => _friendStatus = 'friends');
      return;
    }

    // 2. Checar si envié solicitud
    final sentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(target)
        .collection('friend_requests')
        .doc(me)
        .get();

    if (sentDoc.exists) {
      setState(() => _friendStatus = 'pending_sent');
      return;
    }

    // 3. Checar si recibí solicitud
    final receivedDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(me)
        .collection('friend_requests')
        .doc(target)
        .get();

    if (receivedDoc.exists) {
      setState(() => _friendStatus = 'pending_received');
      return;
    }

    setState(() => _friendStatus = 'none');
  }

  // Funciones de acción
  Future<void> _handleFriendAction() async {
    setState(() => _isLoading = true);
    final me = _currentUser!.uid;
    final target = widget.targetUserId;
    final batch = FirebaseFirestore.instance.batch();

    try {
      if (_friendStatus == 'none') {
        // ENVIAR SOLICITUD
        final reqRef = FirebaseFirestore.instance
            .collection('users')
            .doc(target)
            .collection('friend_requests')
            .doc(me);

        // Guardamos info básica para no tener que consultar de nuevo al mostrar la lista
        batch.set(reqRef, {
          'fromUid': me,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        await batch.commit();
        setState(() => _friendStatus = 'pending_sent');
      } else if (_friendStatus == 'pending_sent') {
        // CANCELAR SOLICITUD
        await FirebaseFirestore.instance
            .collection('users')
            .doc(target)
            .collection('friend_requests')
            .doc(me)
            .delete();
        setState(() => _friendStatus = 'none');
      } else if (_friendStatus == 'friends') {
        // ELIMINAR AMIGO (De ambas partes)
        final myContactRef = FirebaseFirestore.instance
            .collection('users')
            .doc(me)
            .collection('contacts')
            .doc(target);
        final theirContactRef = FirebaseFirestore.instance
            .collection('users')
            .doc(target)
            .collection('contacts')
            .doc(me);

        batch.delete(myContactRef);
        batch.delete(theirContactRef);
        await batch.commit();
        setState(() => _friendStatus = 'none');
      } else if (_friendStatus == 'pending_received') {
        // ACEPTAR SOLICITUD (Agregar en ambas colecciones)
        final myContactRef = FirebaseFirestore.instance
            .collection('users')
            .doc(me)
            .collection('contacts')
            .doc(target);
        final theirContactRef = FirebaseFirestore.instance
            .collection('users')
            .doc(target)
            .collection('contacts')
            .doc(me);
        final reqRef = FirebaseFirestore.instance
            .collection('users')
            .doc(me)
            .collection('friend_requests')
            .doc(target);

        batch.set(myContactRef, {
          'uid': target,
          'addedAt': FieldValue.serverTimestamp(),
        });
        batch.set(theirContactRef, {
          'uid': me,
          'addedAt': FieldValue.serverTimestamp(),
        });
        batch.delete(reqRef); // Borrar la solicitud

        await batch.commit();
        setState(() => _friendStatus = 'friends');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = _currentUser?.uid == widget.targetUserId;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.targetUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('Cargando...')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final name = data?['displayName'] ?? widget.userName ?? 'Usuario';
          final photo = data?['photoURL'];
          final email = data?['email'] ?? '';
          final createdAt = (data?['createdAt'] as Timestamp?)?.toDate();

          return CustomScrollView(
            slivers: [
              // --- APP BAR CON IMAGEN DE FONDO ---
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Theme.of(context).colorScheme.primaryContainer,
                              Theme.of(context).colorScheme.primary,
                            ],
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- CONTENIDO ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // --- FOTO DE PERFIL ---
                      GestureDetector(
                        onTap: photo != null && photo.isNotEmpty
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullscreenImageViewer(
                                      imageUrl: photo,
                                      heroTag:
                                          'user_profile_${widget.targetUserId}',
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Hero(
                          tag: 'user_profile_${widget.targetUserId}',
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            backgroundImage: photo != null && photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo == null || photo.isEmpty
                                ? Text(
                                    name[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 40,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // --- EMAIL ---
                      if (email.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 8),

                      // --- FECHA DE REGISTRO ---
                      if (createdAt != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Miembro desde ${_formatDate(createdAt)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 24),

                      // --- BOTÓN DE ACCIÓN (SI NO SOY YO) ---
                      if (!isMe)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleFriendAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getButtonColor(),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(_getButtonIcon()),
                            label: Text(
                              _getButtonText(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // --- ESTADÍSTICAS ---
                      _buildStatsSection(),

                      const SizedBox(height: 24),

                      // --- EVENTOS RECIENTES ---
                      _buildRecentEventsSection(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM yyyy', 'es').format(date);
  }

  // --- SECCIÓN DE ESTADÍSTICAS ---
  Widget _buildStatsSection() {
    return FutureBuilder<Map<String, int>>(
      future: _getStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'events': 0, 'attended': 0};

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.event,
                  label: 'Eventos',
                  value: stats['events']!,
                  color: Colors.blue,
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                _buildStatItem(
                  icon: Icons.check_circle,
                  label: 'Asistidos',
                  value: stats['attended']!,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return InkWell(
      onTap: label == 'Asistidos'
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AttendanceHistoryPage(userId: widget.targetUserId),
                ),
              );
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, int>> _getStats() async {
    try {
      final eventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('participants', arrayContains: widget.targetUserId)
          .get();

      int attendedCount = 0;

      for (var eventDoc in eventsQuery.docs) {
        final attendanceDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventDoc.id)
            .collection('attendance')
            .doc(widget.targetUserId)
            .get();

        if (attendanceDoc.exists &&
            attendanceDoc.data()?['status'] == 'confirmed') {
          attendedCount++;
        }
      }

      return {'events': eventsQuery.size, 'attended': attendedCount};
    } catch (e) {
      return {'events': 0, 'attended': 0};
    }
  }

  // --- SECCIÓN DE EVENTOS RECIENTES ---
  Widget _buildRecentEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Eventos Recientes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('events')
              .where('participants', arrayContains: widget.targetUserId)
              .orderBy('date', descending: true)
              .limit(10)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final events = snapshot.data?.docs ?? [];

            if (events.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No hay eventos recientes',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index].data() as Map<String, dynamic>;
                final eventId = events[index].id;
                final title = event['title'] ?? 'Evento';
                final date = (event['date'] as Timestamp?)?.toDate();
                final address =
                    event['location']?['address'] ?? 'Ubicación desconocida';
                final isPast = date != null && date.isBefore(DateTime.now());

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPast
                            ? Colors.grey.withOpacity(0.2)
                            : Theme.of(
                                context,
                              ).colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPast ? Icons.history : Icons.event,
                        color: isPast
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: isPast ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (date != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                  'es',
                                ).format(date),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailPage(eventId: eventId),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Helpers visuales para el botón
  Color _getButtonColor() {
    switch (_friendStatus) {
      case 'friends':
        return Colors.red;
      case 'pending_sent':
        return Colors.grey;
      case 'pending_received':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _getButtonText() {
    switch (_friendStatus) {
      case 'friends':
        return 'Eliminar contacto';
      case 'pending_sent':
        return 'Cancelar solicitud';
      case 'pending_received':
        return 'Aceptar solicitud';
      default:
        return 'Agregar contacto';
    }
  }

  IconData _getButtonIcon() {
    switch (_friendStatus) {
      case 'friends':
        return Icons.person_remove;
      case 'pending_sent':
        return Icons.close;
      case 'pending_received':
        return Icons.check;
      default:
        return Icons.person_add;
    }
  }
}
