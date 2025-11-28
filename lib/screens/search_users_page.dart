import 'package:flutter/material.dart';
import '../controllers/contact_controller.dart';
import 'dart:async'; // Para el debouncer

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
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Cargamos mis contactos actuales para saber a quién ya tengo agregado
    _loadMyContacts();
  }

  void _loadMyContacts() {
    final stream = _contactController.getUserContactsStream();
    stream.listen((contacts) {
      if (mounted) {
        setState(() {
          _myCurrentContacts = contacts;
        });
      }
    });
  }

  // Evita hacer búsquedas por cada letra que escribes, espera 500ms
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
        title: TextField(
          controller: _searchCtrl,
          autofocus: true, // Teclado aparece automático
          style: const TextStyle(color: Colors.white),
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

    // Verificamos si ya es mi amigo
    final isAlreadyFriend = _contactController.isContact(uid, _myCurrentContacts);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
          child: photoURL.isEmpty ? Text(name[0].toUpperCase()) : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(email),
        trailing: isAlreadyFriend
            ? const Chip(
          label: Text('Agregado'),
          backgroundColor: Colors.green,
          labelStyle: TextStyle(color: Colors.white),
        )
            : ElevatedButton.icon(
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Agregar'),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () async {
            await _contactController.addContact(uid);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Agregaste a $name')),
            );
            // Recargamos búsqueda para actualizar el botón a "Agregado"
            _performSearch(_searchCtrl.text);
          },
        ),
      ),
    );
  }
}