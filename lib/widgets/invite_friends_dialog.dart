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
  final Set<String> _justInvited = {};

  @override
  Widget build(BuildContext context) {
    final myUid = _currentUser?.uid;
    if (myUid == null) return const SizedBox();

    return AlertDialog(
      title: const Text('Invitar amigos'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(myUid)
              .collection('contacts')
              .snapshots(),
          builder: (context, snapshot) {
            // 1. Estado de carga
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 2. Error
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            // 3. Sin contactos
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No tienes contactos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Agrega amigos desde la pantalla de contactos',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 4. Obtener IDs de contactos
            final contactIds = snapshot.data!.docs.map((doc) => doc.id).toList();

            // 5. Filtrar contactos que NO están en el evento
            final availableContactIds = contactIds
                .where((id) => !widget.currentParticipants.contains(id))
                .toList();

            // 6. Si todos los contactos ya están en el evento
            if (availableContactIds.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'Todos tus contactos ya están en el evento',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }

            // 7. Cargar información de los contactos disponibles
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadContactsInfo(availableContactIds),
              builder: (context, contactsSnapshot) {
                if (contactsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (contactsSnapshot.hasError) {
                  return Center(
                    child: Text('Error al cargar contactos: ${contactsSnapshot.error}'),
                  );
                }

                final contacts = contactsSnapshot.data ?? [];

                if (contacts.isEmpty) {
                  return const Center(
                    child: Text('No se pudieron cargar los contactos'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final userId = contact['id'] as String;
                    final userName = contact['name'] as String;
                    final userPhoto = contact['photoURL'] as String?;
                    final isInvited = _justInvited.contains(userId);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userPhoto != null && userPhoto.isNotEmpty
                            ? NetworkImage(userPhoto)
                            : null,
                        child: userPhoto == null || userPhoto.isEmpty
                            ? Text(userName[0].toUpperCase())
                            : null,
                      ),
                      title: Text(userName),
                      trailing: isInvited
                          ? const Icon(Icons.check, color: Colors.green)
                          : const Icon(Icons.person_add),
                      onTap: isInvited
                          ? null
                          : () => _inviteUser(userId, userName),
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
        ),
      ],
    );
  }

  // ✅ Método para cargar información de los contactos
  Future<List<Map<String, dynamic>>> _loadContactsInfo(List<String> contactIds) async {
    final contacts = <Map<String, dynamic>>[];

    for (final id in contactIds) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();

        if (userDoc.exists) {
          contacts.add({
            'id': id,
            'name': userDoc.data()?['displayName'] ?? 'Sin nombre',
            'photoURL': userDoc.data()?['photoURL'],
          });
        }
      } catch (e) {
        debugPrint('Error al cargar contacto $id: $e');
      }
    }

    return contacts;
  }

  Future<void> _inviteUser(String friendUid, String friendName) async {
    setState(() => _justInvited.add(friendUid));

    try {
      // Agregar usuario al evento
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({
        'participants': FieldValue.arrayUnion([friendUid]),
      });

      // Enviar notificación
      await _notificationService.sendEventInvitation(
        recipientId: friendUid,
        eventId: widget.eventId,
        eventTitle: widget.eventTitle,
        invitedBy: _currentUser!.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitación enviada a $friendName')),
        );
      }
    } catch (e) {
      setState(() => _justInvited.remove(friendUid));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al invitar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
