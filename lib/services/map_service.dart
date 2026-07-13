import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class MapService {
  static const String _apiKey = 'H1X9pBLygoK2PAP3TAHC';
  static const String _baseUrl = 'https://api.maptiler.com';
  static const String _geocodingUrl = 'https://api.maptiler.com/geocoding';

  // Model untuk Hospital
  static Map<String, dynamic> parseHospitalFromFeature(
      Map<String, dynamic> feature, Position userLocation) {
    final properties = feature['properties'] ?? {};
    final geometry = feature['geometry'];
    final coordinates = geometry['coordinates'] as List;

    // Hitung jarak dari user
    final distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      coordinates[1], // latitude
      coordinates[0], // longitude
    );

    // Format jarak
    String formattedDistance;
    if (distance < 1000) {
      formattedDistance = '${distance.toStringAsFixed(0)} m';
    } else {
      formattedDistance = '${(distance / 1000).toStringAsFixed(1)} km';
    }

    return {
      'name': properties['name'] ?? 'Rumah Sakit',
      'address': properties['address'] ??
          properties['street'] ??
          'Alamat tidak tersedia',
      'distance': formattedDistance,
      'distanceInMeters': distance,
      'type': _getHospitalType(properties),
      'rating': _generateRating(properties),
      'latitude': coordinates[1],
      'longitude': coordinates[0],
      'phone': properties['phone'] ?? '-',
      'website': properties['website'] ?? '-',
    };
  }

  static String _getHospitalType(Map<String, dynamic> properties) {
    if (properties['class'] != null) {
      return properties['class'].toString();
    }
    return 'Rumah Sakit';
  }

  static double _generateRating(Map<String, dynamic> properties) {
    // Generate rating berdasarkan data yang ada atau default
    if (properties['rating'] != null) {
      return double.parse(properties['rating'].toString());
    }
    // Default rating antara 4.0 - 4.8
    return 4.0 + (properties['name']?.length ?? 10) % 9 / 10;
  }

  // Mendapatkan lokasi user saat ini
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Cek apakah location service aktif
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    // Cek permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // Dapatkan lokasi
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Mencari rumah sakit terdekat dari lokasi user
  static Future<List<Map<String, dynamic>>> searchNearbyHospitals({
    required double latitude,
    required double longitude,
    int limit = 20,
    double radiusInKm = 10,
  }) async {
    try {
      // MapTiler Geocoding API dengan filter hospital/clinic
      final url = Uri.parse(
        '$_baseUrl/geocoding/$longitude,$latitude.json?key=$_apiKey&types=poi&limit=$limit',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];

        final userPosition = Position(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        // Filter hanya yang relevan dengan hospital/health
        final hospitals = features
            .where((feature) {
              final properties = feature['properties'] ?? {};
              final placeType =
                  properties['place_type']?.toString().toLowerCase() ?? '';
              final name = properties['name']?.toString().toLowerCase() ?? '';
              final category =
                  properties['class']?.toString().toLowerCase() ?? '';

              return name.contains('hospital') ||
                  name.contains('rumah sakit') ||
                  name.contains('rs ') ||
                  name.contains('klinik') ||
                  name.contains('clinic') ||
                  category.contains('hospital') ||
                  category.contains('health') ||
                  placeType.contains('poi');
            })
            .map((feature) => parseHospitalFromFeature(feature, userPosition))
            .toList();

        // Sort berdasarkan jarak terdekat
        hospitals.sort((a, b) => (a['distanceInMeters'] as double)
            .compareTo(b['distanceInMeters'] as double));

        // Filter berdasarkan radius
        final radiusInMeters = radiusInKm * 1000;
        return hospitals
            .where((h) => h['distanceInMeters'] < radiusInMeters)
            .toList();
      } else {
        print('Error fetching hospitals: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching hospitals: $e');
      return [];
    }
  }

  // Mencari rumah sakit berdasarkan query
  static Future<List<Map<String, dynamic>>> searchHospitalsByQuery({
    required String query,
    required double latitude,
    required double longitude,
    int limit = 20,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocoding/$query.json?key=$_apiKey&proximity=$longitude,$latitude&types=poi&limit=$limit',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];

        final userPosition = Position(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        // Filter hanya yang relevan dengan hospital/health
        final hospitals = features
            .where((feature) {
              final properties = feature['properties'] ?? {};
              final name = properties['name']?.toString().toLowerCase() ?? '';
              final category =
                  properties['class']?.toString().toLowerCase() ?? '';

              return name.contains('hospital') ||
                  name.contains('rumah sakit') ||
                  name.contains('rs ') ||
                  name.contains('klinik') ||
                  name.contains('clinic') ||
                  category.contains('hospital') ||
                  category.contains('health');
            })
            .map((feature) => parseHospitalFromFeature(feature, userPosition))
            .toList();

        // Sort berdasarkan jarak terdekat
        hospitals.sort((a, b) => (a['distanceInMeters'] as double)
            .compareTo(b['distanceInMeters'] as double));

        return hospitals;
      } else {
        print('Error searching hospitals: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching hospitals by query: $e');
      return [];
    }
  }
}
