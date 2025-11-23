import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../controllers/auth_controller.dart';
import '../services/image_upload_service.dart';
import '../providers/theme_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final _authController = AuthController();
  final _displayNameCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  User? _user;
  bool _isUpdatingImage = false;
  bool _isSaving = false;
  bool _isSendingVerification = false;
  bool _isChangingPassword = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _loadUser() {
    setState(() {
      _user = FirebaseAuth.instance.currentUser;
      _displayNameCtrl.text = _user?.displayName ?? '';
    });
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool _hasPasswordProvider() {
    return _user?.providerData.any((p) => p.providerId == 'password') ?? false;
  }

  String _userInitial() {
    final name = (_user?.displayName ?? '').trim();
    final email = (_user?.email ?? '').trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'U';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Desconocido';
    return DateFormat('dd MMM yyyy', 'es').format(date);
  }

  Future<void> _sendEmailVerification() async {
    if (_user == null || _user!.emailVerified) return;
    setState(() => _isSendingVerification = true);
    try {
      await _user!.sendEmailVerification();
      _showSnackBar('Correo de verificación enviado');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isSendingVerification = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_hasPasswordProvider()) return;

    final current = _currentPassCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();

    if (current.isEmpty || newPass.isEmpty) {
      _showSnackBar('Completa ambos campos', isError: true);
      return;
    }

    if (newPass.length < 6) {
      _showSnackBar('Nueva contraseña debe tener mínimo 6 caracteres', isError: true);
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: current,
      );
      await _user!.reauthenticateWithCredential(credential);
      await _user!.updatePassword(newPass);

      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _showSnackBar('Contraseña actualizada correctamente');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showSnackBar('Contraseña actual incorrecta', isError: true);
      } else {
        _showSnackBar('Error: ${e.message}', isError: true);
      }
    } finally {
      setState(() => _isChangingPassword = false);
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        compressQuality: 80,
        compressFormat: ImageCompressFormat.jpg,
        maxWidth: 1080,
        maxHeight: 1080,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar imagen',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Recortar imagen',
            aspectRatioLockEnabled: true,
          ),
        ],
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      );

      return croppedFile != null ? File(croppedFile.path) : null;
    } catch (e) {
      _showSnackBar('Error al recortar: $e', isError: true);
      return null;
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      File? croppedImage = await _cropImage(File(pickedFile.path));
      if (croppedImage == null) return;

      final confirmed = await _showPreviewDialog(croppedImage);
      if (!confirmed) return;

      setState(() => _isUpdatingImage = true);

      final filename = 'profile_${_user!.uid}';
      final result = await ImageUploadService.uploadProfileImage(croppedImage, filename);

      if (result['success']) {
        await _user!.updatePhotoURL(result['profileImageUrl']);
        await FirebaseAuth.instance.currentUser?.reload();
        _loadUser();
        _showSnackBar('Foto actualizada');
      } else {
        _showSnackBar(result['message'], isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isUpdatingImage = false);
    }
  }

  Future<bool> _showPreviewDialog(File imageFile) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(child: Image.file(imageFile, fit: BoxFit.contain)),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Confirmar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            if (_user?.photoURL != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar foto', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await _confirmDeleteDialog();
                  if (confirm) _removeProfileImage();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar foto'),
        content: const Text('¿Confirmas eliminar tu foto de perfil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _removeProfileImage() async {
    setState(() => _isUpdatingImage = true);
    try {
      final filename = 'profile_${_user!.uid}';
      final result = await ImageUploadService.deleteProfileImage(filename);
      if (result['success']) {
        await _user!.updatePhotoURL(null);
        await FirebaseAuth.instance.currentUser?.reload();
        _loadUser();
        _showSnackBar('Foto eliminada');
      } else {
        _showSnackBar(result['message'], isError: true);
      }
    } finally {
      setState(() => _isUpdatingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final newName = _displayNameCtrl.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _user!.updateDisplayName(newName);
      await FirebaseAuth.instance.currentUser?.reload();
      _loadUser();
      _showSnackBar('Perfil actualizado');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _user?.photoURL != null && _user!.photoURL!.isNotEmpty;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline), text: 'Perfil'),
            Tab(icon: Icon(Icons.lock_outline), text: 'Seguridad'),
            Tab(icon: Icon(Icons.palette_outlined), text: 'Apariencia'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(hasPhoto, theme),
          _buildSecurityTab(theme),
          _buildAppearanceTab(theme),
        ],
      ),
    );
  }

  Widget _buildProfileTab(bool hasPhoto, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileHeader(hasPhoto, theme),
          const SizedBox(height: 16),
          if (_user != null && !_user!.emailVerified) ...[
            _buildVerificationBanner(),
            const SizedBox(height: 16),
          ],
          _buildInfoCard(theme),
          const SizedBox(height: 16),
          _buildSignOutButton(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool hasPhoto, ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [theme.primaryColor.withOpacity(0.1), theme.primaryColor.withOpacity(0.05)],
          ),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: hasPhoto ? () {} : null,
                  child: Hero(
                    tag: 'profile_avatar',
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: theme.primaryColor.withOpacity(0.2),
                      backgroundImage: hasPhoto ? NetworkImage(_user!.photoURL!) : null,
                      child: _isUpdatingImage
                          ? const CircularProgressIndicator()
                          : (!hasPhoto ? Text(_userInitial(), style: const TextStyle(fontSize: 48)) : null),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      onPressed: _showImageSourceDialog,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _user?.displayName ?? 'Sin nombre',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(_user?.email ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _user?.providerData.map((p) {
                IconData icon = Icons.mail;
                String label = 'Email';
                if (p.providerId == 'google.com') {
                  icon = Icons.g_mobiledata;
                  label = 'Google';
                } else if (p.providerId == 'apple.com') {
                  icon = Icons.apple;
                  label = 'Apple';
                }
                return Chip(
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                );
              }).toList() ??
                  [],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBanner() {
    return Card(
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tu correo no está verificado',
                style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: _isSendingVerification ? null : _sendEmailVerification,
              child: _isSendingVerification
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verificar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Información personal', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre visible',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                  label: const Text('Guardar cambios'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_hasPasswordProvider()) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cambiar contraseña', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _currentPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        prefixIcon: const Icon(Icons.lock_open),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isChangingPassword ? null : _changePassword,
                        icon: _isChangingPassword ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                        label: const Text('Actualizar contraseña'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Iniciaste sesión con Google. No necesitas contraseña.')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            color: Colors.red[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Text('Zona de peligro', style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Una vez eliminada tu cuenta, no podrás recuperar tus datos.'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDeleteAccount(),
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text('Eliminar mi cuenta', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar cuenta'),
        content: const Text('Esta acción es permanente. ¿Confirmas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await _authController.deleteAccount();
              if (result == null) {
                _authController.signOut();
              } else {
                _showSnackBar(result, isError: true);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Modo oscuro'),
                subtitle: const Text('Activa el tema oscuro en toda la app'),
                value: themeProvider.themeMode == ThemeMode.dark,
                onChanged: (val) => themeProvider.setTheme(val ? ThemeMode.dark : ThemeMode.light),
                secondary: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _authController.signOut,
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
