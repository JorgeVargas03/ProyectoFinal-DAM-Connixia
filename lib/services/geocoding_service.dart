import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeocodingService {
  // API Key de Google Maps desde variables de entorno
  static String get _apiKey => dotenv.env['MAPS_API_KEY'] ?? '';

  /// Obtiene la dirección a partir de coordenadas (Reverse Geocoding)
  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'latlng=$lat,$lng&key=$_apiKey&language=es',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        } else {
          debugPrint('Geocoding error: ${data['status']}');
        }
      }
    } catch (e) {
      debugPrint('Error en geocoding: $e');
    }
    return null;
  }

  /// Obtiene coordenadas a partir de una dirección (Geocoding)
  Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'address=${Uri.encodeComponent(address)}&key=$_apiKey&language=es',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return {
            'lat': location['lat'],
            'lng': location['lng'],
          };
        } else {
          debugPrint('Geocoding error: ${data['status']}');
        }
      }
    } catch (e) {
      debugPrint('Error en geocoding: $e');
    }
    return null;
  }
}
