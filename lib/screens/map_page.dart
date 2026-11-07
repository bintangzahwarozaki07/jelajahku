
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../database/database_helper.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  static const LatLng _ngawiCenter = LatLng(-7.455, 111.355);

  List<Map<String, dynamic>> _destinations = [];
  LatLng? _currentPosition;
  Map<String, dynamic>? _selectedDestination;

  List<LatLng> _routePoints = [];

  double? _routeDistanceKm;
  double? _routeDurationMinutes;

  bool _isLoading = true;
  bool _isLocating = false;
  bool _isOpeningNavigation = false;
  bool _isLoadingRoute = false;

  String? _loadError;
  String? _routeError;

  int _routeRequestId = 0;

  String _statusMessage =
      'Pilih destinasi wisata atau tekan tombol lokasi Anda.';

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  Future<void> _loadDestinations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rows = await DatabaseHelper.instance.getDestinations();

      if (!mounted) return;

      setState(() {
        _destinations = rows.where((row) {
          final latitude = row['latitude'];
          final longitude = row['longitude'];

          return latitude is num && longitude is num;
        }).toList();

        _isLoading = false;
        _loadError = null;

        _statusMessage =
            '${_destinations.length} destinasi dengan koordinat tersedia. '
            'Pilih salah satu destinasi pada peta.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = error.toString();
        _statusMessage = 'Gagal memuat destinasi dari database.';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _statusMessage = 'Sedang mencari lokasi Anda...';
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Layanan lokasi belum aktif. Aktifkan GPS atau Location Services.',
        );
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi belum diberikan.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Izin lokasi ditolak permanen. Ubah izin melalui pengaturan perangkat atau browser.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final newPosition = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = newPosition;

        _statusMessage =
            'Lokasi berhasil ditemukan!\n'
            'Latitude: ${position.latitude.toStringAsFixed(6)}\n'
            'Longitude: ${position.longitude.toStringAsFixed(6)}';
      });

      _mapController.move(newPosition, 15);

      if (_selectedDestination != null) {
        await _fetchRoute();
      }
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '');

      setState(() {
        _statusMessage = message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  LatLng _positionFromRow(Map<String, dynamic> row) {
    return LatLng(
      (row['latitude'] as num).toDouble(),
      (row['longitude'] as num).toDouble(),
    );
  }

  Future<void> _fetchRoute() async {
    if (_currentPosition == null || _selectedDestination == null) {
      return;
    }

    final requestId = ++_routeRequestId;

    final origin = _currentPosition!;
    final destination =
        _positionFromRow(_selectedDestination!);

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
      _routePoints = [];
      _routeDistanceKm = null;
      _routeDurationMinutes = null;
    });

    try {
      // OSRM menggunakan urutan longitude,latitude.
      final coordinates =
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}';

      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/$coordinates',
        {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
        },
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw Exception(
          'Server rute memberikan respons ${response.statusCode}.',
        );
      }

      final data = jsonDecode(response.body);

      if (data['code'] != 'Ok' ||
          data['routes'] == null ||
          (data['routes'] as List).isEmpty) {
        throw Exception(
          'Rute jalan tidak ditemukan untuk lokasi tersebut.',
        );
      }

      final route = data['routes'][0];

      final geometry = route['geometry']['coordinates'] as List;

      final points = geometry.map<LatLng>((coordinate) {
        return LatLng(
          (coordinate[1] as num).toDouble(),
          (coordinate[0] as num).toDouble(),
        );
      }).toList();

      final distanceKm =
          (route['distance'] as num).toDouble() / 1000;

      final durationMinutes =
          (route['duration'] as num).toDouble() / 60;

      if (!mounted || requestId != _routeRequestId) return;

      setState(() {
        _routePoints = points;
        _routeDistanceKm = distanceKm;
        _routeDurationMinutes = durationMinutes;
        _isLoadingRoute = false;

        _statusMessage =
            'Rute perjalanan berhasil ditemukan.\n'
            'Tujuan: ${_selectedDestination!['name']}';
      });

      // Menyesuaikan peta agar seluruh rute terlihat.
      if (points.length >= 2) {
        final bounds = LatLngBounds.fromPoints(points);

        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(45),
            maxZoom: 15,
          ),
        );
      }
    } catch (error) {
      if (!mounted || requestId != _routeRequestId) return;

      setState(() {
        _isLoadingRoute = false;
        _routeError = error.toString().replaceFirst('Exception: ', '');
        _routePoints = [];
        _routeDistanceKm = null;
        _routeDurationMinutes = null;
      });
    }
  }

  void _showDestination(Map<String, dynamic> destination) {
    final position = _positionFromRow(destination);

    setState(() {
      _selectedDestination = destination;

      _statusMessage =
          '${destination['name']}\n'
          '${destination['location']}\n'
          'Kategori: ${destination['category']}\n'
          'Latitude: ${position.latitude}\n'
          'Longitude: ${position.longitude}';

      _routePoints = [];
      _routeDistanceKm = null;
      _routeDurationMinutes = null;
      _routeError = null;
    });

    _mapController.move(position, 14);

    if (_currentPosition != null) {
      _fetchRoute();
    }
  }

  String _formatDuration(double minutes) {
    final totalMinutes = minutes.round();

    if (totalMinutes < 60) {
      return '$totalMinutes menit';
    }

    final hours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;

    if (remainingMinutes == 0) {
      return '$hours jam';
    }

    return '$hours jam $remainingMinutes menit';
  }

  Future<void> _openNavigation() async {
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih destinasi terlebih dahulu.'),
        ),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Temukan lokasi Anda terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() {
      _isOpeningNavigation = true;
    });

    try {
      final destinationPosition =
          _positionFromRow(_selectedDestination!);

      final origin =
          '${_currentPosition!.latitude},${_currentPosition!.longitude}';

      final destination =
          '${destinationPosition.latitude},${destinationPosition.longitude}';

      final uri = Uri.https(
        'www.google.com',
        '/maps/dir/',
        {
          'api': '1',
          'origin': origin,
          'destination': destination,
          'travelmode': 'driving',
        },
      );

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Google Maps.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka navigasi: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningNavigation = false;
        });
      }
    }
  }

  List<Marker> _buildMarkers() {
    final markers = _destinations.map((destination) {
      final position = _positionFromRow(destination);

      final isSelected =
          _selectedDestination?['id'] == destination['id'];

      return Marker(
        point: position,
        width: 150,
        height: 75,
        child: GestureDetector(
          onTap: () => _showDestination(destination),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                color: isSelected
                    ? Colors.orange
                    : const Color(0xFFE53935),
                size: isSelected ? 43 : 38,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  destination['name'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 50,
          height: 50,
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 38,
          ),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    if (_routePoints.length < 2) {
      return [];
    }

    return [
      Polyline(
        points: _routePoints,
        strokeWidth: 5,
        color: Colors.blue,
      ),
    ];
  }

  Widget _buildDestinationSelector() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedDestination?['id'] as int?,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Pilih destinasi tujuan',
        prefixIcon: const Icon(
          Icons.place,
          color: Color(0xFF16865B),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      items: _destinations.map((destination) {
        return DropdownMenuItem<int>(
          value: destination['id'] as int,
          child: Text(
            destination['name'] as String,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (id) {
        if (id == null) return;

        final destination = _destinations.firstWhere(
          (item) => item['id'] == id,
        );

        _showDestination(destination);
      },
    );
  }

  Widget _buildRouteInfo() {
    if (_currentPosition == null) {
      return const Text(
        'Temukan lokasi Anda untuk menghitung rute perjalanan.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black54,
        ),
      );
    }

    if (_isLoadingRoute) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF16865B),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sedang menghitung rute jalan...',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      );
    }

    if (_routeError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.deepOrange,
                  size: 18,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rute jalan belum tersedia',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              _routeError!,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 5),
            const Text(
              'Periksa koneksi internet lalu coba hitung kembali.',
              style: TextStyle(fontSize: 11),
            ),
            TextButton.icon(
              onPressed: _fetchRoute,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba hitung ulang'),
            ),
          ],
        ),
      );
    }

    if (_routeDistanceKm == null ||
        _routeDurationMinutes == null) {
      return const Text(
        'Pilih destinasi dan hitung rute untuk melihat informasi perjalanan.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black54,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.route,
                color: Color(0xFF16865B),
                size: 20,
              ),
              SizedBox(width: 7),
              Text(
                'Informasi Rute Perjalanan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRouteMetric(
                  Icons.directions_car,
                  'Jarak jalan',
                  '${_routeDistanceKm!.toStringAsFixed(2)} km',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRouteMetric(
                  Icons.access_time,
                  'Estimasi waktu',
                  _formatDuration(_routeDurationMinutes!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Text(
            'Estimasi berdasarkan rute kendaraan dari layanan OSRM. '
            'Waktu sebenarnya dapat berubah sesuai kondisi lalu lintas.',
            style: TextStyle(
              fontSize: 10,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMetric(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF16865B),
                size: 17,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF16865B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationInfo() {
    if (_selectedDestination == null) {
      return const Text(
        'Belum ada destinasi yang dipilih.',
        style: TextStyle(
          color: Colors.black54,
          fontSize: 13,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedDestination!['name'] as String,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _selectedDestination!['location'] as String,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Kategori: ${_selectedDestination!['category']}',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Peta JelajahKu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16865B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Muat ulang destinasi',
            onPressed: _loadDestinations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 42,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Destinasi gagal dimuat.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _loadError!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadDestinations,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: const MapOptions(
                          initialCenter: _ngawiCenter,
                          initialZoom: 9.5,
                          minZoom: 5,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.jelajahku.jelajahku',
                            maxZoom: 19,
                          ),
                          PolylineLayer(
                            polylines: _buildPolylines(),
                          ),
                          MarkerLayer(
                            markers: _buildMarkers(),
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                '© OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
          ),

          // Panel informasi dibuat scrollable agar tidak overflow.
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              maxHeight: 360,
            ),
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.explore,
                        color: Color(0xFF16865B),
                        size: 25,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Jelajahi Kabupaten Ngawi',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_destinations.length} destinasi dengan koordinat tersimpan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDestinationSelector(),
                  const SizedBox(height: 10),
                  _buildDestinationInfo(),
                  const SizedBox(height: 10),
                  _buildRouteInfo(),
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isLocating ? null : _getCurrentLocation,
                      icon: _isLocating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(
                        _isLocating
                            ? 'Mencari Lokasi...'
                            : 'Temukan Lokasi Saya',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16865B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _isOpeningNavigation
                          ? null
                          : _openNavigation,
                      icon: _isOpeningNavigation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.directions),
                      label: const Text('Navigasi ke Destinasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1877D2),
                        foregroundColor: Colors.white,
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
        ],
      ),
    );
  }
}
