import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../admin/controllers/admin_controller.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final AdminController _adminCtrl = AdminController();
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await _adminCtrl.searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),

          // Resultados
          Expanded(
            child: _searchResults.isNotEmpty
                ? _buildSearchResults()
                : _buildAllUsers(),
          ),
        ],
      ),
    );
  }

  // Mostrar resultados de búsqueda
  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _UserCard(
          user: user,
          adminCtrl: _adminCtrl,
          onUpdate: () => _searchUsers(_searchCtrl.text),
        );
      },
    );
  }

  // Mostrar todos los usuarios con StreamBuilder
  Widget _buildAllUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminCtrl.getAllUsers(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return const Center(child: Text('No hay usuarios registrados'));
        }

        return ListView.builder(
          itemCount: users.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final user = {
              'uid': userDoc.id,
              ...userDoc.data() as Map<String, dynamic>,
            };
            return _UserCard(
              user: user,
              adminCtrl: _adminCtrl,
              onUpdate: () {}, // No necesita actualizar en stream
            );
          },
        );
      },
    );
  }
}

// Widget de tarjeta de usuario
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final AdminController adminCtrl;
  final VoidCallback onUpdate;

  const _UserCard({
    required this.user,
    required this.adminCtrl,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final uid = user['uid'] ?? '';
    final displayName = user['displayName'] ?? 'Sin nombre';
    final email = user['email'] ?? 'Sin email';
    final role = user['role'] ?? 'user';
    final suspended = user['suspended'] ?? false;
    final photoURL = user['photoURL'];
    final createdAt = user['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundImage: photoURL != null && photoURL.isNotEmpty
              ? NetworkImage(photoURL)
              : null,
          backgroundColor: colorScheme.primaryContainer,
          child: photoURL == null || photoURL.isEmpty
              ? Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (role == 'admin')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (suspended)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SUSPENDIDO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email),
            if (createdAt != null)
              Text(
                'Registrado: ${DateFormat('dd/MM/yyyy').format(createdAt.toDate())}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UID: $uid',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Botón para cambiar rol
                    if (role == 'user')
                      ElevatedButton.icon(
                        onPressed: () => _changeRole(context, uid, 'admin'),
                        icon: const Icon(Icons.admin_panel_settings, size: 16),
                        label: const Text('Hacer Admin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else if (role == 'admin')
                      ElevatedButton.icon(
                        onPressed: () => _changeRole(context, uid, 'user'),
                        icon: const Icon(Icons.person, size: 16),
                        label: const Text('Quitar Admin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),

                    // Botón para suspender/activar
                    ElevatedButton.icon(
                      onPressed: () =>
                          _toggleSuspension(context, uid, !suspended),
                      icon: Icon(
                        suspended ? Icons.check_circle : Icons.block,
                        size: 16,
                      ),
                      label: Text(suspended ? 'Activar' : 'Suspender'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: suspended
                            ? Colors.green
                            : Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),

                    // Botón para ver detalles
                    OutlinedButton.icon(
                      onPressed: () => _showUserDetails(context, uid),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Ver Detalles'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    String userId,
    String newRole,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cambio de rol'),
        content: Text(
          newRole == 'admin'
              ? '¿Estás seguro de que quieres hacer a este usuario administrador?'
              : '¿Estás seguro de que quieres quitar los permisos de administrador?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final error = await adminCtrl.changeUserRole(userId, newRole);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Rol cambiado exitosamente'),
            backgroundColor: error == null ? Colors.green : Colors.red,
          ),
        );
        if (error == null) onUpdate();
      }
    }
  }

  Future<void> _toggleSuspension(
    BuildContext context,
    String userId,
    bool suspend,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspend ? 'Suspender Usuario' : 'Activar Usuario'),
        content: Text(
          suspend
              ? '¿Estás seguro de que quieres suspender a este usuario?'
              : '¿Estás seguro de que quieres activar a este usuario?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: suspend ? Colors.red : Colors.green,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final error = await adminCtrl.suspendUser(userId, suspend);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error ?? (suspend ? 'Usuario suspendido' : 'Usuario activado'),
            ),
            backgroundColor: error == null ? Colors.green : Colors.red,
          ),
        );
        if (error == null) onUpdate();
      }
    }
  }

  Future<void> _showUserDetails(BuildContext context, String userId) async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>?>(
        future: adminCtrl.getUserDetails(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final details = snapshot.data;
          if (details == null) {
            return const AlertDialog(
              title: Text('Error'),
              content: Text('No se pudo cargar la información del usuario'),
            );
          }

          return AlertDialog(
            title: const Text('Detalles del Usuario'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DetailRow(
                    label: 'Eventos Creados',
                    value: details['eventsCreated']?.toString() ?? '0',
                  ),
                  _DetailRow(
                    label: 'Eventos Participados',
                    value: details['eventsParticipated']?.toString() ?? '0',
                  ),
                  _DetailRow(
                    label: 'Contactos',
                    value: (details['contacts']?.length ?? 0).toString(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
