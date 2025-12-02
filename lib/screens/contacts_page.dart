import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/contact_controller.dart';
import 'search_users_page.dart';
import 'user_profile_page.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactController _contactController = ContactController();
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Contactos'),
        elevation: 0,
        actions: [
          // BOTÓN DE SOLICITUDES CON INDICADOR ROJO
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_myUid)
                .collection('friend_requests')
                .snapshots(),
            builder: (context, snapshot) {
              final hasRequests =
                  snapshot.hasData && snapshot.data!.docs.isNotEmpty;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FriendRequestsPage(),
                        ),
                      );
                    },
                  ),
                  if (hasRequests)
                    Positioned(
                      right: 11,
                      top: 11,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchUsersPage()),
          );
        },
        icon: const Icon(Icons.person_search),
        label: const Text('Buscar amigos'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _contactController.getUserContactsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final contacts = snapshot.data ?? [];

          if (contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No tienes contactos aún.\n¡Usa el botón para buscar amigos!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // Ordenar: Favoritos primero
          contacts.sort((a, b) {
            bool favA = a['isFavorite'] ?? false;
            bool favB = b['isFavorite'] ?? false;
            if (favA && !favB) return -1;
            if (!favA && favB) return 1;
            return 0;
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              return _ContactTile(
                contactData: contacts[index],
                controller: _contactController,
              );
            },
          );
        },
      ),
    );
  }
}

// --- WIDGET PARA CADA AMIGO (REUTILIZADO Y MEJORADO) ---
class _ContactTile extends StatelessWidget {
  final Map<String, dynamic> contactData;
  final ContactController controller;

  const _ContactTile({required this.contactData, required this.controller});

  @override
  Widget build(BuildContext context) {
    final uid = contactData['uid'];
    final isFav = contactData['isFavorite'] ?? false;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox();

        final name = userData['displayName'] ?? 'Usuario';
        final photoURL = userData['photoURL'] ?? '';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // NAVEGACIÓN A PERFIL DE USUARIO
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      UserProfilePage(targetUserId: uid, userName: name),
                ),
              );
            },
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                radius: 25,
                backgroundImage: photoURL.isNotEmpty
                    ? NetworkImage(photoURL)
                    : null,
                child: photoURL.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(userData['email'] ?? ''),
              // Favorito + Menú de opciones
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? Colors.amber[700] : Colors.grey,
                    ),
                    onPressed: () => controller.toggleFavorite(uid),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDelete(context, uid, name);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Eliminar contacto',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar a $name?'),
        content: const Text('Se eliminará de tu lista de contactos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              // 1. Llamamos al controlador actualizado
              await controller.deleteContact(uid);

              // 2. Cerramos el diálogo (La lista de fondo se actualizará sola gracias al Stream)
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// --- PÁGINA DE SOLICITUDES DE AMISTAD ---
class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de Amistad')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .collection('friend_requests')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final reqs = snapshot.data!.docs;

          if (reqs.isEmpty) {
            return const Center(
              child: Text('No tienes solicitudes pendientes'),
            );
          }

          return ListView.builder(
            itemCount: reqs.length,
            itemBuilder: (context, index) {
              final data = reqs[index].data() as Map<String, dynamic>;
              final senderUid = data['fromUid'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(senderUid)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData)
                    return const ListTile(title: Text('Cargando...'));
                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: userData['photoURL'] != null
                          ? NetworkImage(userData['photoURL'])
                          : null,
                      child: userData['photoURL'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(userData['displayName'] ?? 'Usuario'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            // Rechazar
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(myUid)
                                .collection('friend_requests')
                                .doc(senderUid)
                                .delete();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            // Aceptar (Lógica de añadir a contactos mutuamente)
                            final batch = FirebaseFirestore.instance.batch();
                            final myRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(myUid)
                                .collection('contacts')
                                .doc(senderUid);
                            final theirRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(senderUid)
                                .collection('contacts')
                                .doc(myUid);
                            final reqRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(myUid)
                                .collection('friend_requests')
                                .doc(senderUid);

                            batch.set(myRef, {
                              'uid': senderUid,
                              'addedAt': FieldValue.serverTimestamp(),
                            });
                            batch.set(theirRef, {
                              'uid': myUid,
                              'addedAt': FieldValue.serverTimestamp(),
                            });
                            batch.delete(reqRef);

                            await batch.commit();
                            if (context.mounted)
                              Navigator.pop(
                                context,
                              ); // Opcional: Cerrar o quedar
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      // También puedes ir al perfil desde aquí
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfilePage(targetUserId: senderUid),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
