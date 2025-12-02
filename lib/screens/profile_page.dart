import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../controllers/auth_controller.dart';
import '../admin/controllers/admin_controller.dart';
import '../services/image_upload_service.dart';
import '../providers/theme_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'attendance_history_page.dart';
import '../admin/screens/admin_gate_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final _authController = AuthController();
  final _adminController = AdminController();
  final _displayNameCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  static const int _maxFileSizeBytes = 10 * 1024 * 1024;

  User? _user;
  bool _isUpdatingImage = false;
  bool _isSaving = false;
  bool _isChangingPassword = false;
  bool _isAdmin = false;

  late TabController _tabController;
  bool _isModalOpen = false;

  // Lista de colores disponibles
  final List<Color> _availableColors = [
    const Color(0xFF5C6BC0), // Indigo Suave
    const Color(0xFF42A5F5), // Azul Calmado
    const Color(0xFF26C6DA), // Turquesa
    const Color(0xFF26A69A), // Verde Cerceta
    const Color(0xFF66BB6A), // Verde Hoja
    const Color(0xFFC0CA33), // Lima Oscura
    const Color(0xFFFFCA28), // Ámbar Miel
    const Color(0xFFFFA726), // Naranja Atardecer
    const Color(0xFFEF5350), // Rojo Coral
    const Color(0xFFEC407A), // Rosa Pastel
    const Color(0xFFAB47BC), // Lavanda
    const Color(0xFF7E57C2), // Morado Profundo
    const Color(0xFF8D6E63), // Marrón Tierra
    const Color(0xFF78909C), // Gris Azulado
    const Color(0xFF546E7A), // Gris Pizarra
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _checkAdminStatus();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _loadUser() {
    setState(() {
      _user = FirebaseAuth.instance.currentUser;
      _displayNameCtrl.text = _user?.displayName ?? '';
    });
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _adminController.isAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
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

  String _getAuthProvider() {
    if (_user?.providerData.isEmpty ?? true) return 'Desconocido';
    final provider = _user!.providerData.first.providerId;
    if (provider == 'password') return 'Correo';
    if (provider == 'google.com') return 'Google';
    return provider;
  }

  IconData _getAuthProviderIcon() {
    if (_user?.providerData.isEmpty ?? true) return Icons.help_outline;
    final provider = _user!.providerData.first.providerId;
    if (provider == 'password') return Icons.email;
    if (provider == 'google.com') return Icons.g_mobiledata;
    return Icons.account_circle;
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

  Future<void> _changePassword() async {
    if (!_hasPasswordProvider()) return;

    final current = _currentPassCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();

    if (current.isEmpty || newPass.isEmpty) {
      _showSnackBar('Completa ambos campos', isError: true);
      return;
    }

    if (newPass.length < 6) {
      _showSnackBar(
        'Nueva contraseña debe tener mínimo 6 caracteres',
        isError: true,
      );
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
      _showSnackBar('Contraseña actualizada correctamente');
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
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
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar imagen',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Recortar imagen', aspectRatioLockEnabled: true),
        ],
      );
      return croppedFile != null ? File(croppedFile.path) : null;
    } catch (e) {
      _showSnackBar('Error al recortar: $e', isError: true);
      return null;
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);

      // 1. Recortar
      final croppedImage = await _cropImage(imageFile);
      if (croppedImage == null) return;

      // 2. Comprimir SOLO si excede 10 MB
      final finalImage = await _compressIfNeeded(croppedImage);

      // 3. Mostrar preview
      final confirmed = await _showPreviewDialog(finalImage);
      if (!confirmed) return;

      setState(() => _isUpdatingImage = true);

      final filename = 'profile_${_user!.uid}';
      final result = await ImageUploadService.uploadProfileImage(
        finalImage,
        filename,
      );

      if (result['success']) {
        await _user!.updatePhotoURL(result['profileImageUrl']);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .update({'photoURL': result['profileImageUrl']});

        await FirebaseAuth.instance.currentUser?.reload();
        _loadUser();
        _showSnackBar('Foto actualizada correctamente');
      } else {
        _showSnackBar(result['message'] ?? 'Error desconocido', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isUpdatingImage = false);
    }
  }

  /// Comprime la imagen SOLO si excede el límite de Cloudinary
  Future<File> _compressIfNeeded(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      final fileSizeMB = fileSize / (1024 * 1024);

      debugPrint('Tamaño original: ${fileSizeMB.toStringAsFixed(2)} MB');

      // Si el archivo es menor a 10 MB, retornarlo sin comprimir
      if (fileSize <= _maxFileSizeBytes) {
        debugPrint('[OK] Imagen dentro del límite, no se comprime');
        return imageFile;
      }

      debugPrint('[WARN] Imagen excede 10 MB, comprimiendo...');

      // Comprimir la imagen
      final filePath = imageFile.absolute.path;
      final lastIndex = filePath.lastIndexOf('.');
      final outPath = '${filePath.substring(0, lastIndex)}_compressed.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        outPath,
        quality: 75, // Calidad balanceada
        minWidth: 1200, // Suficiente para fotos de perfil
        minHeight: 1200,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        debugPrint('[ERROR] Error al comprimir, usando imagen original');
        return imageFile;
      }

      final compressedSize = await result.length();
      final compressedSizeMB = compressedSize / (1024 * 1024);
      debugPrint('[OK] Comprimida: ${compressedSizeMB.toStringAsFixed(2)} MB');

      // Si después de comprimir sigue siendo muy grande, comprimir más agresivamente
      if (compressedSize > _maxFileSizeBytes) {
        debugPrint('[WARN] Aún es grande, comprimiendo más...');
        return await _compressAggressively(File(result.path));
      }

      return File(result.path);
    } catch (e) {
      debugPrint('[ERROR] Error en compresión: $e');
      return imageFile; // Retornar original si hay error
    }
  }

  /// Compresión más agresiva para archivos muy grandes
  Future<File> _compressAggressively(File imageFile) async {
    try {
      final filePath = imageFile.absolute.path;
      final lastIndex = filePath.lastIndexOf('.');
      final outPath = '${filePath.substring(0, lastIndex)}_ultra.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        outPath,
        quality: 60, // Calidad más baja
        minWidth: 800, // Dimensiones más pequeñas
        minHeight: 800,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final finalSize = await result.length();
        debugPrint(
          '[OK] Compresión agresiva: ${(finalSize / (1024 * 1024)).toStringAsFixed(2)} MB',
        );
        return File(result.path);
      }

      return imageFile;
    } catch (e) {
      debugPrint('[ERROR] Error en compresión agresiva: $e');
      return imageFile;
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
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  void _showImageSourceDialog() {
    setState(() => _isModalOpen = true);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isDismissible: true,
      enableDrag: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_user?.photoURL != null && _user!.photoURL!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Ver foto actual'),
                onTap: () {
                  Navigator.pop(context);
                  _showFullImage();
                },
              ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
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
            if (_user?.photoURL != null && _user!.photoURL!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Eliminar foto',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await _confirmDeleteDialog();
                  if (confirmed) await _removeProfileImage();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isModalOpen = false);
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _showFullImage() {
    if (_user?.photoURL == null || _user!.photoURL!.isEmpty) return;

    setState(() => _isModalOpen = true);

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    _user!.photoURL!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.error, color: Colors.white, size: 64),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isModalOpen = false);
        FocusScope.of(context).unfocus();
      }
    });
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
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
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
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .update({'photoURL': null});
        await FirebaseAuth.instance.currentUser?.reload();
        _loadUser();
        _showSnackBar('Foto eliminada');
      } else {
        _showSnackBar(result['message'] ?? 'Error desconocido', isError: true);
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .update({'displayName': newName});
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
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    //Color para TabBar segun el modo
    final activeColor = isDark
        ? Color.lerp(primaryColor, Colors.white, 0.4)!
        : Color.lerp(primaryColor, Colors.black, 0.2)!;

    return GestureDetector(
      onTap: () {
        //Solo ocultar el teclado si NO hay un modal abierto
        if (!_isModalOpen) {
          FocusScope.of(context).unfocus();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi cuenta'),
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: activeColor,
            indicatorColor: activeColor,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            tabs: const [
              Tab(icon: Icon(Icons.person), text: 'Perfil'),
              Tab(icon: Icon(Icons.lock), text: 'Seguridad'),
              Tab(icon: Icon(Icons.palette), text: 'Apariencia'),
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
          _buildInfoCard(theme),
          const SizedBox(height: 24),
          if (_isAdmin) ...[
            _buildAdminAccessButton(),
            const SizedBox(height: 16),
          ],
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
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer,
              Theme.of(context).brightness == Brightness.dark
                  ? theme.colorScheme.surface
                  : Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: theme.colorScheme.surface,
                    backgroundImage: hasPhoto
                        ? NetworkImage(_user!.photoURL!)
                        : null,
                    child: !hasPhoto
                        ? Text(
                            _userInitial(),
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                ),
                if (_isUpdatingImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primary,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: _showImageSourceDialog,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _user?.displayName ?? 'Sin nombre',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _user?.email ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getAuthProviderIcon(),
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Cuenta de ${_getAuthProvider()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  Icons.calendar_today,
                  'Miembro desde',
                  _formatDate(_user?.metadata.creationTime),
                  theme,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // --- BOTÓN HISTORIAL DE ASISTENCIA ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AttendanceHistoryPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Ver historial de asistencia'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ],
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
              Row(
                children: [
                  Icon(Icons.person, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Información personal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              IgnorePointer(
                ignoring: _isModalOpen,
                child: TextFormField(
                  controller: _displayNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre visible',
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa un nombre'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Guardar cambios'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lock_reset,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cambiar contraseña',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _currentPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña actual',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isChangingPassword ? null : _changePassword,
                        icon: _isChangingPassword
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Actualizar contraseña'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            color: theme.colorScheme.errorContainer,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        'Zona de peligro',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Esta acción es permanente y no se puede deshacer.',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer.withOpacity(
                        0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _confirmDeleteAccount,
                      icon: Icon(
                        Icons.delete_forever,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(
                        'Eliminar cuenta',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await _authController.deleteAccount();
              if (result == null) {
                _showSnackBar('Cuenta eliminada');
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
          builder: (context, themeProvider, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Personalización',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- MODO OSCURO ---
                SwitchListTile(
                  title: const Text('Modo oscuro'),
                  subtitle: const Text('Activa el tema oscuro en toda la app'),
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    themeProvider.setTheme(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                  secondary: Icon(
                    themeProvider.themeMode == ThemeMode.dark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: theme.colorScheme.primary,
                  ),
                ),

                const Divider(height: 32),

                // --- SELECTOR DE COLOR (Botón que abre diálogo) ---
                Text(
                  'Color de énfasis',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: themeProvider.seedColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  title: const Text('Cambiar color del tema'),
                  subtitle: const Text('Toca para elegir de la paleta'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showColorPickerDialog(context, themeProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DIÁLOGO PARA SELECCIONAR COLOR ---
  void _showColorPickerDialog(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    // Variable para guardar el color seleccionado TEMPORALMENTE dentro del diálogo
    Color tempSelectedColor = themeProvider.seedColor;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Elige un color'),
              content: SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _availableColors.length,
                  itemBuilder: (context, index) {
                    final color = _availableColors[index];
                    final isSelected = tempSelectedColor.value == color.value;

                    return GestureDetector(
                      onTap: () {
                        setStateDialog(() {
                          tempSelectedColor = color;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                  width: 3.0,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    themeProvider.setSeedColor(tempSelectedColor);
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.palette, color: Colors.white),
                              const SizedBox(width: 10),
                              const Text('Tema actualizado correctamente'),
                            ],
                          ),
                          backgroundColor:
                              tempSelectedColor, // Usamos el color elegido
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdminAccessButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AdminGatePage()));
        },
        icon: const Icon(Icons.admin_panel_settings),
        label: const Text('Panel de Administración'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
