import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ImageUploadService {
  static const String _baseUrl = 'https://api-adana-pilates.onrender.com/adana-api/v1/users';
  static const int _maxFileSizeBytes = 10 * 1024 * 1024;

  static Future<Map<String, dynamic>> uploadProfileImage(File imageFile, String filename) async {
    try {
      // Validación de tamaño antes de subir
      final fileSize = await imageFile.length();
      if (fileSize > _maxFileSizeBytes) {
        return {
          'success': false,
          'message': 'La imagen supera el límite de 10 MB (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB). Por favor, intenta con otra imagen.',
        };
      }
      
      var uri = Uri.parse('$_baseUrl/upload/image');
      var request = http.MultipartRequest('POST', uri);

      final mimeType = lookupMimeType(imageFile.path);
      final mimeTypeData = mimeType?.split('/');

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: mimeTypeData != null
              ? MediaType(mimeTypeData[0], mimeTypeData[1])
              : null,
        ),
      );

      request.fields['filename'] = filename;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'profileImageUrl': responseData['profileImageUrl'],
          'message': responseData['message'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Error al subir la imagen',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  /// Borra una imagen de perfil de Cloudinary.
  /// Recibe el ID de usuario de Firebase para construir el publicId.
  static Future<Map<String, dynamic>> deleteProfileImage(String firebaseUserId) async {
    try {
      final uri = Uri.parse('$_baseUrl/delete/image/$firebaseUserId');
      final response = await http.delete(uri);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Imagen eliminada correctamente',
        };
      } else {
        return {
          'success': false,
          'message': 'Error al eliminar la imagen en el servidor',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión al intentar eliminar la imagen: $e',
      };
    }
  }
}
