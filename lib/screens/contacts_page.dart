import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/contact_controller.dart';
import 'search_users_page.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactController _contactController = ContactController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Contactos'),
        elevation: 0,
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
                  Icon(Icons.groups_outlined, size: 80, color: Colors.grey[400]),
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

    // Buscamos la info "viva" del usuario (foto nueva, nombre nuevo)
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(); // Cargando silencioso

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox(); // Usuario borrado

        final name = userData['displayName'] ?? 'Usuario';
        final photoURL = userData['photoURL'] ?? '';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: GestureDetector(
              onTap: () {
                // Aquí podrías abrir el perfil del amigo en el futuro
              },
              child: CircleAvatar(
                radius: 25,
                backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                child: photoURL.isEmpty
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(userData['email'] ?? ''),
            trailing: IconButton(
              icon: Icon(
                isFav ? Icons.star : Icons.star_border,
                color: isFav ? Colors.amber[700] : Colors.grey,
                size: 30,
              ),
              onPressed: () => controller.toggleFavorite(uid),
            ),
          ),
        );
      },
    );
  }
}