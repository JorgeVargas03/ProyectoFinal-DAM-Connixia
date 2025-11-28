import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class InviteFriendsDialog extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final List<dynamic> currentParticipants;

  const InviteFriendsDialog({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.currentParticipants,
  });

  @override
  State<InviteFriendsDialog> createState() => _InviteFriendsDialogState();
}

class _InviteFriendsDialogState extends State<InviteFriendsDialog> {
  final _notificationService = NotificationService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  // Para controlar visualmente a quiénes acabamos de invitar
  final Set<String> _justInvited = {};

  @override
  Widget build(BuildContext context) {
    final myUid = _currentUser?.uid;
    if (myUid == null) return const SizedBox();

    return AlertDialog(
      title: const Text('Invitar amigos'),
      content: SizedBox(
        width: double.maxFinite,
        // CORRECCIÓN 1: Escuchamos el DOCUMENTO del usuario, no una colección
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(myUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text('Error al cargar contactos.');
            }

            // CORRECCIÓN 2: Extraemos el array 'contacts' del mapa de datos
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final List<dynamic> contactsList = userData['contacts'] ?? [];

            if (contactsList.isEmpty) {
              return const Text(
                'No tienes contactos agregados aún.\nVe a "Mis Contactos" para buscar amigos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              );
            }

            // CORRECCIÓN 3: Iteramos sobre la lista del array
            return ListView.builder(
              shrinkWrap: true,
              itemCount: contactsList.length,
              itemBuilder: (context, index) {
                // Cada elemento del array es un mapa: {uid: '...', isFavorite: ...}
                final contactMap = contactsList[index] as Map<String, dynamic>;
                final friendUid = contactMap['uid'];

                // Filtro 1: Ya está en el evento?
                if (widget.currentParticipants.contains(friendUid)) {
                  return const SizedBox.shrink();
                }

                // Recuperamos nombre/foto real del usuario usando su UID
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(friendUid).get(),
                  builder: (context, userSnap) {
                    // Mientras carga la info del amigo
                    if (!userSnap.hasData) return const SizedBox();

                    // Si el amigo borró su cuenta
                    if (!userSnap.data!.exists) return const SizedBox();

                    final user = userSnap.data!.data() as Map<String, dynamic>;
                    final name = user['displayName'] ?? 'Usuario';
                    final photoURL = user['photoURL'];

                    final isInvited = _justInvited.contains(friendUid);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: photoURL != null && photoURL.isNotEmpty
                            ? NetworkImage(photoURL)
                            : null,
                        child: (photoURL == null || photoURL.isEmpty)
                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                            : null,
                      ),
                      title: Text(name),
                      trailing: isInvited
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await _inviteUser(friendUid, name);
                        },
                        child: const Text('Invitar'),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        )
      ],
    );
  }

  Future<void> _inviteUser(String friendUid, String friendName) async {
    setState(() => _justInvited.add(friendUid));

    await _notificationService.sendInvitation(
      eventId: widget.eventId,
      eventTitle: widget.eventTitle,
      targetUserId: friendUid,
      senderName: _currentUser?.displayName ?? 'Un amigo',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitación enviada a $friendName')),
      );
    }
  }
}