import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
  String _friendStatus = 'none'; // 'none', 'pending_sent', 'pending_received', 'friends'

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
        .collection('users').doc(me).collection('contacts').doc(target).get();

    if (friendDoc.exists) {
      setState(() => _friendStatus = 'friends');
      return;
    }

    // 2. Checar si envié solicitud
    final sentDoc = await FirebaseFirestore.instance
        .collection('users').doc(target).collection('friend_requests').doc(me).get();

    if (sentDoc.exists) {
      setState(() => _friendStatus = 'pending_sent');
      return;
    }

    // 3. Checar si recibí solicitud
    final receivedDoc = await FirebaseFirestore.instance
        .collection('users').doc(me).collection('friend_requests').doc(target).get();

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
            .collection('users').doc(target).collection('friend_requests').doc(me);

        // Guardamos info básica para no tener que consultar de nuevo al mostrar la lista
        batch.set(reqRef, {
          'fromUid': me,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending'
        });

        await batch.commit();
        setState(() => _friendStatus = 'pending_sent');

      } else if (_friendStatus == 'pending_sent') {
        // CANCELAR SOLICITUD
        await FirebaseFirestore.instance
            .collection('users').doc(target).collection('friend_requests').doc(me).delete();
        setState(() => _friendStatus = 'none');

      } else if (_friendStatus == 'friends') {
        // ELIMINAR AMIGO (De ambas partes)
        final myContactRef = FirebaseFirestore.instance.collection('users').doc(me).collection('contacts').doc(target);
        final theirContactRef = FirebaseFirestore.instance.collection('users').doc(target).collection('contacts').doc(me);

        batch.delete(myContactRef);
        batch.delete(theirContactRef);
        await batch.commit();
        setState(() => _friendStatus = 'none');

      } else if (_friendStatus == 'pending_received') {
        // ACEPTAR SOLICITUD (Agregar en ambas colecciones)
        final myContactRef = FirebaseFirestore.instance.collection('users').doc(me).collection('contacts').doc(target);
        final theirContactRef = FirebaseFirestore.instance.collection('users').doc(target).collection('contacts').doc(me);
        final reqRef = FirebaseFirestore.instance.collection('users').doc(me).collection('friend_requests').doc(target);

        batch.set(myContactRef, {'uid': target, 'addedAt': FieldValue.serverTimestamp()});
        batch.set(theirContactRef, {'uid': me, 'addedAt': FieldValue.serverTimestamp()});
        batch.delete(reqRef); // Borrar la solicitud

        await batch.commit();
        setState(() => _friendStatus = 'friends');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si soy yo mismo, no mostrar botones de agregar
    final isMe = _currentUser?.uid == widget.targetUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de Usuario')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- CARD 1: DATOS DEL USUARIO ---
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final name = data?['displayName'] ?? widget.userName ?? 'Usuario';
                final photo = data?['photoURL'];
                final email = data?['email'] ?? '';

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: photo != null ? NetworkImage(photo) : null,
                          child: photo == null ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 30)) : null,
                        ),
                        const SizedBox(height: 16),
                        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(email, style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 20),

                        if (!isMe)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _handleFriendAction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getButtonColor(),
                                foregroundColor: Colors.white,
                              ),
                              icon: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(_getButtonIcon()),
                              label: Text(_getButtonText()),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // --- CARD 2: EVENTOS ASISTIDOS ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Eventos Recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),

            FutureBuilder<QuerySnapshot>(
              // Busca eventos donde el array 'participants' contenga el ID del usuario
              future: FirebaseFirestore.instance
                  .collection('events')
                  .where('participants', arrayContains: widget.targetUserId)
                  .limit(5)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final events = snapshot.data?.docs ?? [];

                if (events.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Este usuario no ha asistido a eventos públicos recientemente.'),
                    ),
                  );
                }

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final event = events[index].data() as Map<String, dynamic>;
                      final date = (event['date'] as Timestamp?)?.toDate();

                      return ListTile(
                        leading: const Icon(Icons.event_available, color: Colors.indigo),
                        title: Text(event['title'] ?? 'Evento'),
                        subtitle: date != null
                            ? Text(DateFormat('dd/MM/yyyy').format(date))
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helpers visuales para el botón
  Color _getButtonColor() {
    switch (_friendStatus) {
      case 'friends': return Colors.red;
      case 'pending_sent': return Colors.grey;
      case 'pending_received': return Colors.green;
      default: return Colors.blue;
    }
  }

  String _getButtonText() {
    switch (_friendStatus) {
      case 'friends': return 'Eliminar contacto';
      case 'pending_sent': return 'Cancelar solicitud';
      case 'pending_received': return 'Aceptar solicitud';
      default: return 'Agregar contacto';
    }
  }

  IconData _getButtonIcon() {
    switch (_friendStatus) {
      case 'friends': return Icons.person_remove;
      case 'pending_sent': return Icons.close;
      case 'pending_received': return Icons.check;
      default: return Icons.person_add;
    }
  }
}