import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class MapService {
  static const String _maptilerApiKey = 'H1X9pBLygoK2PAP3TAHC';
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  // Mendapatkan lokasi user saat ini
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Cek apakah location service aktif
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Location services are disabled.');
      return null;
    }

    // Cek permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Location permissions are denied');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ Location permissions are permanently denied');
      return null;
    }

    // Dapatkan lokasi
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('✅ Got location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  // Mencari rumah sakit terdekat menggunakan Overpass API (OpenStreetMap)
  static Future<List<Map<String, dynamic>>> searchNearbyHospitals({
    required double latitude,
    required double longitude,
    int limit = 30,
    double radiusInKm = 15,
  }) async {
    try {
      print('🔍 Searching hospitals near: $latitude, $longitude');

      final radiusInMeters = (radiusInKm * 1000).toInt();

      // Overpass QL query untuk mencari rumah sakit dan klinik
      final query = '''
[out:json][timeout:25];
(
  node["amenity"="hospital"](around:$radiusInMeters,$latitude,$longitude);
  way["amenity"="hospital"](around:$radiusInMeters,$latitude,$longitude);
  node["amenity"="clinic"](around:$radiusInMeters,$latitude,$longitude);
  way["amenity"="clinic"](around:$radiusInMeters,$latitude,$longitude);
  node["healthcare"="hospital"](around:$radiusInMeters,$latitude,$longitude);
  way["healthcare"="hospital"](around:$radiusInMeters,$latitude,$longitude);
  node["healthcare"="clinic"](around:$radiusInMeters,$latitude,$longitude);
  way["healthcare"="clinic"](around:$radiusInMeters,$latitude,$longitude);
);
out center body;
>;
out skel qt;
''';

      print('🌐 Calling Overpass API...');

      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      ).timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List? ?? [];

        print('✅ Found ${elements.length} elements from OSM');

        List<Map<String, dynamic>> hospitals = [];

        for (var element in elements) {
          // Skip jika tidak ada nama atau koordinat
          final tags = element['tags'] as Map<String, dynamic>? ?? {};
          final name = tags['name'] ?? tags['name:id'] ?? tags['name:en'];

          if (name == null) continue;

          double? lat, lon;

          // Handle node vs way
          if (element['type'] == 'node') {
            lat = element['lat']?.toDouble();
            lon = element['lon']?.toDouble();
          } else if (element['type'] == 'way' && element['center'] != null) {
            lat = element['center']['lat']?.toDouble();
            lon = element['center']['lon']?.toDouble();
          }

          if (lat == null || lon == null) continue;

          // Hitung jarak dari user
          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            lat,
            lon,
          );

          // Format jarak
          String formattedDistance;
          if (distance < 1000) {
            formattedDistance = '${distance.toStringAsFixed(0)} m';
          } else {
            formattedDistance = '${(distance / 1000).toStringAsFixed(1)} km';
          }

          // Tentukan tipe fasilitas
          String facilityType = 'Rumah Sakit';
          final amenity = tags['amenity']?.toString().toLowerCase() ?? '';
          final healthcare = tags['healthcare']?.toString().toLowerCase() ?? '';

          if (amenity == 'clinic' || healthcare == 'clinic') {
            facilityType = 'Klinik';
          } else if (tags['healthcare:speciality'] != null) {
            facilityType = 'RS Spesialis';
          }

          // Buat alamat dari tags yang tersedia
          String address = _buildAddress(tags);

          hospitals.add({
            'name': name,
            'address': address,
            'distance': formattedDistance,
            'distanceInMeters': distance,
            'type': facilityType,
            'rating': _generateRating(name.toString()),
            'latitude': lat,
            'longitude': lon,
            'phone': tags['phone'] ?? tags['contact:phone'] ?? '-',
            'website': tags['website'] ?? tags['contact:website'] ?? '-',
            'openingHours': tags['opening_hours'] ?? '-',
            'emergency': tags['emergency'] == 'yes' ? true : false,
          });
        }

        // Sort berdasarkan jarak
        hospitals.sort((a, b) => (a['distanceInMeters'] as double)
            .compareTo(b['distanceInMeters'] as double));

        print('🏥 Total hospitals found: ${hospitals.length}');

        return hospitals.take(limit).toList();
      } else {
        print('❌ Overpass API error: ${response.statusCode}');
        print('Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception searching hospitals: $e');
      return [];
    }
  }

  // Mencari rumah sakit berdasarkan query user
  static Future<List<Map<String, dynamic>>> searchHospitalsByQuery({
    required String query,
    required double latitude,
    required double longitude,
    int limit = 30,
  }) async {
    try {
      print('🔍 Searching for: $query');

      // Pertama, cari semua RS terdekat
      final allHospitals = await searchNearbyHospitals(
        latitude: latitude,
        longitude: longitude,
        limit: 100, // Ambil lebih banyak untuk di-filter
        radiusInKm: 50, // Radius lebih luas untuk pencarian
      );

      // Filter berdasarkan query
      final queryLower = query.toLowerCase();
      final filteredHospitals = allHospitals.where((hospital) {
        final name = hospital['name'].toString().toLowerCase();
        final address = hospital['address'].toString().toLowerCase();
        final type = hospital['type'].toString().toLowerCase();

        return name.contains(queryLower) ||
            address.contains(queryLower) ||
            type.contains(queryLower);
      }).toList();

      print('🏥 Filtered results: ${filteredHospitals.length}');

      // Jika tidak ada hasil dari filter, coba pencarian Nominatim
      if (filteredHospitals.isEmpty) {
        return await _searchWithNominatim(query, latitude, longitude, limit);
      }

      return filteredHospitals.take(limit).toList();
    } catch (e) {
      print('❌ Exception: $e');
      return [];
    }
  }

  // Pencarian menggunakan Nominatim (OSM) sebagai fallback
  static Future<List<Map<String, dynamic>>> _searchWithNominatim(
    String query,
    double latitude,
    double longitude,
    int limit,
  ) async {
    try {
      final searchQuery = Uri.encodeComponent('$query rumah sakit');
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$searchQuery&format=json&limit=$limit&addressdetails=1&countrycodes=id',
      );

      print('🌐 Nominatim search: $url');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'Identia-App/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        List<Map<String, dynamic>> hospitals = [];

        for (var result in results) {
          final lat = double.tryParse(result['lat'].toString()) ?? 0;
          final lon = double.tryParse(result['lon'].toString()) ?? 0;

          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            lat,
            lon,
          );

          String formattedDistance;
          if (distance < 1000) {
            formattedDistance = '${distance.toStringAsFixed(0)} m';
          } else {
            formattedDistance = '${(distance / 1000).toStringAsFixed(1)} km';
          }

          hospitals.add({
            'name': result['display_name']?.split(',')[0] ?? 'Rumah Sakit',
            'address': result['display_name'] ?? 'Alamat tidak tersedia',
            'distance': formattedDistance,
            'distanceInMeters': distance,
            'type': 'Rumah Sakit',
            'rating': _generateRating(result['display_name']?.toString() ?? ''),
            'latitude': lat,
            'longitude': lon,
            'phone': '-',
            'website': '-',
          });
        }

        hospitals.sort((a, b) => (a['distanceInMeters'] as double)
            .compareTo(b['distanceInMeters'] as double));

        return hospitals;
      }
      return [];
    } catch (e) {
      print('❌ Nominatim error: $e');
      return [];
    }
  }

  // Helper untuk membuat alamat dari OSM tags
  static String _buildAddress(Map<String, dynamic> tags) {
    final parts = <String>[];

    if (tags['addr:street'] != null) {
      String street = tags['addr:street'];
      if (tags['addr:housenumber'] != null) {
        street += ' No.${tags['addr:housenumber']}';
      }
      parts.add(street);
    }

    if (tags['addr:suburb'] != null) parts.add(tags['addr:suburb']);
    if (tags['addr:city'] != null) parts.add(tags['addr:city']);
    if (tags['addr:district'] != null) parts.add(tags['addr:district']);

    if (parts.isEmpty) {
      // Fallback ke alamat yang tersedia
      return tags['address'] ?? tags['addr:full'] ?? 'Alamat tidak tersedia';
    }

    return parts.join(', ');
  }

  // Generate rating berdasarkan nama (konsisten untuk RS yang sama)
  static double _generateRating(String name) {
    if (name.isEmpty) return 4.0;

    // Hash sederhana dari nama untuk rating konsisten
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0xFFFFFFFF;
    }

    // Rating antara 4.0 - 4.9
    return 4.0 + (hash % 10) / 10;
  }
}
