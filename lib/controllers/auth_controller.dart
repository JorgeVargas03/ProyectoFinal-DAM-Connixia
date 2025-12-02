import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importante para la base de datos
import 'package:flutter/foundation.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- MÉTODO PRIVADO: CREAR DOCUMENTO DE USUARIO (SI NO EXISTE) ---
  // Este método actúa como un "seguro": verifica si el usuario tiene datos en la BD.
  // Si no tiene (porque es nuevo o es un usuario viejo), crea el documento inicial.
  Future<void> _createUserDocument(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userRef.get();

      if (!docSnapshot.exists) {
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'contacts': [], // Array vacío para agregar amigos después
          'fcmToken': '', // Listo para notificaciones
          'role': 'user', // Por defecto todos son usuarios normales
        });
      }
    } catch (e) {
      debugPrint('Error al crear/verificar perfil en Firestore: $e');
    }
  }

  // --- INICIAR SESIÓN CON EMAIL ---
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Autenticación pura de Firebase
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. VERIFICACIÓN DE REPARACIÓN:
      // Si el login es exitoso, llamamos a _createUserDocument.
      // Si el usuario ya tiene datos, no pasa nada.
      // Si el usuario era viejo y no tenía datos, se crean aquí.
      if (cred.user != null) {
        await _createUserDocument(cred.user!);
      }

      return null; // null significa éxito
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          return 'No existe una cuenta con ese correo.';
        case 'wrong-password':
          return 'Contraseña incorrecta.';
        case 'invalid-email':
          return 'Correo inválido.';
        case 'user-disabled':
          return 'Cuenta deshabilitada.';
        default:
          return e.message ?? 'Error de autenticación';
      }
    } catch (e) {
      debugPrint('Unknown sign-in error: $e');
      return 'Error inesperado al iniciar sesión.';
    }
  }

  // --- REGISTRO CON EMAIL ---
  Future<String?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final emailTrim = email.trim();
    final emailRegex = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
    if (emailTrim.isEmpty) return 'El correo es obligatorio.';
    if (!emailRegex.hasMatch(emailTrim)) return 'Formato de correo inválido.';
    if (password.isEmpty) return 'La contraseña es obligatoria.';
    if (password.length < 6)
      return 'La contraseña debe tener al menos 6 caracteres.';

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: emailTrim,
        password: password,
      );

      // Creamos el documento inmediatamente para el usuario nuevo
      if (cred.user != null) {
        await _createUserDocument(cred.user!);
      }

      await cred.user?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException (register): ${e.code} - ${e.message}');
      switch (e.code) {
        case 'email-already-in-use':
          return 'El correo ya está en uso.';
        case 'invalid-email':
          return 'Correo inválido.';
        case 'operation-not-allowed':
          return 'Método de registro no habilitado en Firebase.';
        case 'weak-password':
          return 'Contraseña débil.';
        default:
          return e.message ?? 'Error al registrar usuario.';
      }
    } catch (e) {
      debugPrint('Unknown register error: $e');
      return 'Error inesperado al registrar.';
    }
  }

  // --- INICIAR SESIÓN CON GOOGLE ---
  Future<String?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize(
        serverClientId:
            '736317810114-v6bmruruuluns7o1lmn76l3d3pva98i5.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();
      if (googleUser == null) {
        return 'Inicio de sesión cancelado';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        return 'Error: No se pudo obtener el ID Token de Google';
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      if (userCredential.user == null) {
        return 'Error: No se pudo completar el inicio de sesión';
      }

      // Aseguramos que el documento exista en Firestore
      await _createUserDocument(userCredential.user!);

      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuthException en Google Sign-In: ${e.code} - ${e.message}',
      );
      return e.message ?? 'Error de autenticación con Google';
    } catch (e, st) {
      debugPrint('Error inesperado en Google Sign-In: $e\n$st');
      return 'Error inesperado al iniciar sesión con Google.';
    }
  }

  // --- CERRAR SESIÓN ---
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error durante cierre de sesión: $e');
    }
  }

  // --- RECUPERAR CONTRASEÑA ---
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Error al enviar email de recuperación.';
    }
  }

  // --- ELIMINAR CUENTA ---
  Future<String?> deleteAccount() async {
    final user = _auth.currentUser;

    if (user == null) return 'No hay usuario autenticado.';

    try {
      // Opcional: Descomenta esto si quieres que al borrar la cuenta
      // también se borre su perfil de la base de datos.
      // await _firestore.collection('users').doc(user.uid).delete();

      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        try {
          if (user.providerData.any((p) => p.providerId == 'google.com')) {
            await signInWithGoogle();
          } else {
            return 'Debes volver a iniciar sesión para eliminar tu cuenta.';
          }
          // Reintentar eliminación tras re-autenticación
          await user.delete();
          return null;
        } catch (e) {
          return 'No se pudo re-autenticar. Intenta cerrar sesión y volver a iniciar sesión.';
        }
      }
      return e.message ?? 'Error al eliminar la cuenta.';
    }
  }
}
