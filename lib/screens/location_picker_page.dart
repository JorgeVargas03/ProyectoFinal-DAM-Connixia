import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/location_controller.dart';
import '../services/geocoding_service.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final LocationController _locationCtrl = LocationController();
  final GeocodingService _geocoding = GeocodingService();
  
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  LatLng? _currentPosition;
  String _address = 'Selecciona una ubicación en el mapa';
  bool _loading = true;
  bool _fetchingAddress = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    _currentPosition = await _locationCtrl.getCurrentPosition();
    if (_currentPosition != null) {
      _selectedPosition = _currentPosition;
      _fetchAddress(_currentPosition!);
    }
    setState(() => _loading = false);
  }

  Future<void> _fetchAddress(LatLng position) async {
    setState(() => _fetchingAddress = true);
    final address = await _geocoding.getAddressFromCoordinates(
      position.latitude,
      position.longitude,
    );
    setState(() {
      _address = address ?? 'Dirección no disponible';
      _fetchingAddress = false;
    });
  }

  void _onMapTap(LatLng position) {
    setState(() => _selectedPosition = position);
    _fetchAddress(position);
  }

  void _confirmLocation() {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una ubicación')),
      );
      return;
    }

    Navigator.pop(context, {
      'lat': _selectedPosition!.latitude,
      'lng': _selectedPosition!.longitude,
      'address': _address,
    });
  }

  void _goToMyLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 16),
      );
      setState(() => _selectedPosition = _currentPosition);
      _fetchAddress(_currentPosition!);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seleccionar ubicación')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentPosition == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No se pudo obtener tu ubicación'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirmLocation,
            tooltip: 'Confirmar ubicación',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 16,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _selectedPosition != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedPosition!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                    ),
                  }
                : {},
          ),

          // Panel de información
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ubicación seleccionada',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_fetchingAddress)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Obteniendo dirección...'),
                      ],
                    )
                  else
                    Text(
                      _address,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  if (_selectedPosition != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_selectedPosition!.latitude.toStringAsFixed(6)}, '
                      'Lng: ${_selectedPosition!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _confirmLocation,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Confirmar ubicación'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón de ubicación actual
          Positioned(
            bottom: 220,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _goToMyLocation,
              tooltip: 'Mi ubicación',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
