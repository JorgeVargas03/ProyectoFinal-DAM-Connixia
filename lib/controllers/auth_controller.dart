// auth_controller.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
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

  Future<String?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final emailTrim = email.trim();
    final emailRegex = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
    if (emailTrim.isEmpty) return 'El correo es obligatorio.';
    if (!emailRegex.hasMatch(emailTrim)) return 'Formato de correo inválido.';
    if (password.isEmpty) return 'La contraseña es obligatoria.';
    if (password.length < 6) return 'La contraseña debe tener al menos 6 caracteres.';

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: emailTrim,
        password: password,
      );
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

  Future<String?> signInWithGoogle() async {
    try {
      // Inicializa GoogleSignIn con tu serverClientId
      await _googleSignIn.initialize(
        serverClientId: '736317810114-v6bmruruuluns7o1lmn76l3d3pva98i5.apps.googleusercontent.com',
      );

      // Autentica (versión 7 usa authenticate en lugar de signIn)
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) {
        return 'Inicio de sesión cancelado';
      }

      // Obtiene el idToken
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        return 'Error: No se pudo obtener el ID Token de Google';
      }

      // Crea la credencial de Firebase solo con el idToken
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      // Inicia sesión en Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user == null) {
        return 'Error: No se pudo completar el inicio de sesión';
      }

      return null; // Éxito
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException en Google Sign-In: ${e.code} - ${e.message}');
      return e.message ?? 'Error de autenticación con Google';
    } catch (e, st) {
      debugPrint('Error inesperado en Google Sign-In: $e\n$st');
      return 'Error inesperado al iniciar sesión con Google.';
    }
  }


  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error durante cierre de sesión: $e');
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Error al enviar email de recuperación.';
    }
  }

  Future<String?> deleteAccount() async {
    final user = _auth.currentUser;

    if (user == null) return 'No hay usuario autenticado.';

    try {
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      // Necesita verificarse recientemente
      if (e.code == 'requires-recent-login') {
        try {
          if (user.providerData.any((p) => p.providerId == 'google.com')) {
            // Verificarse con Google
            await signInWithGoogle();
          } else {
            return 'Debes volver a iniciar sesión para eliminar tu cuenta.';
          }

          // Intentar eliminar otra vez
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
