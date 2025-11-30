import 'package:flutter/material.dart';
import '../controllers/contact_controller.dart';
import 'user_profile_page.dart';
import 'dart:async';

class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final ContactController _contactController = ContactController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _myCurrentContacts = [];

  // Para rastrear visualmente las solicitudes enviadas en esta sesión
  final Set<String> _sentRequests = {};

  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadMyContacts();
  }

  void _loadMyContacts() {
    // Escuchamos los contactos para saber si ya son amigos
    _contactController.getUserContactsStream().listen((contacts) {
      if (mounted) {
        setState(() {
          _myCurrentContacts = contacts;
        });
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    final results = await _contactController.searchUsersByName(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Usamos el color primario en la AppBar si tu tema no lo hace por defecto
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Buscar personas...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          return _buildUserResultTile(user);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.person_search, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Busca amigos por su nombre',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildUserResultTile(Map<String, dynamic> user) {
    final uid = user['uid'];
    final name = user['displayName'] ?? 'Usuario';
    final photoURL = user['photoURL'] ?? '';
    final email = user['email'] ?? '';

    // 1. Verificar si ya es amigo
    final isAlreadyFriend = _myCurrentContacts.any((c) => c['uid'] == uid);

    // 2. Verificar si acabamos de enviar solicitud
    final isRequestSent = _sentRequests.contains(uid);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        // Al tocar la tarjeta (no el botón), vamos al perfil
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => UserProfilePage(
                    targetUserId: uid,
                    userName: name
                )
            ),
          );
        },
        leading: CircleAvatar(
          backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
          child: photoURL.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U') : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(email),

        // --- AQUÍ ESTÁ LA LÓGICA DEL BOTÓN ---
        trailing: isAlreadyFriend
            ? const Chip(
          label: Text('Amigos'),
          visualDensity: VisualDensity.compact,
          backgroundColor: Colors.green,
          labelStyle: TextStyle(color: Colors.white, fontSize: 12),
        )
            : isRequestSent
            ? const Chip(
          label: Text('Enviado'),
          visualDensity: VisualDensity.compact,
          backgroundColor: Colors.grey,
          labelStyle: TextStyle(color: Colors.white, fontSize: 12),
        )
            : ElevatedButton( // BOTÓN DE AGREGAR
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor, // Color Primario
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () async {
            // 1. Feedback inmediato visual
            setState(() {
              _sentRequests.add(uid);
            });

            // 2. Llamada a la base de datos
            try {
              await _contactController.sendFriendRequest(uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Solicitud enviada a $name')),
                );
              }
            } catch (e) {
              // Si falla, revertimos el estado visual
              if (mounted) {
                setState(() {
                  _sentRequests.remove(uid);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error al enviar solicitud')),
                );
              }
            }
          },
          child: const Text('Agregar'),
        ),
      ),
    );
  }
}