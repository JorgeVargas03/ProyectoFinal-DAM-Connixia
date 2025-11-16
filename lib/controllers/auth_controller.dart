// dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Intenta iniciar sesión y devuelve un String|null:
  /// - null = éxito
  /// - texto = mensaje de error para mostrar
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

  Future<void> signOut() => _auth.signOut();

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
      // Enviar verificación por correo (opcional pero recomendado)
      await cred.user?.sendEmailVerification();
      // Opcional: cerrar sesión para obligar verificación antes de usar la cuenta
      // await _auth.signOut();
      return null; // éxito
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
}
