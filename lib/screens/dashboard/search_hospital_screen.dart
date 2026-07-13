import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';
import '../../services/map_service_new.dart';

class SearchHospitalScreen extends StatefulWidget {
  const SearchHospitalScreen({super.key});

  @override
  State<SearchHospitalScreen> createState() => _SearchHospitalScreenState();
}

class _SearchHospitalScreenState extends State<SearchHospitalScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredHospitals = [];
  Position? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  final List<Map<String, dynamic>> _hospitals = [];

  @override
  void initState() {
    super.initState();
    _loadNearbyHospitals();
  }

  Future<void> _loadNearbyHospitals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Dapatkan lokasi user
      final position = await MapService.getCurrentLocation();

      if (position == null) {
        setState(() {
          _errorMessage =
              'Tidak dapat mengakses lokasi. Pastikan GPS aktif dan izin lokasi diberikan.';
          _isLoading = false;
        });
        return;
      }

      _currentPosition = position;

      // Cari rumah sakit terdekat
      final hospitals = await MapService.searchNearbyHospitals(
        latitude: position.latitude,
        longitude: position.longitude,
        limit: 30,
        radiusInKm: 15,
      );

      setState(() {
        _filteredHospitals = hospitals;
        _isLoading = false;
      });

      if (hospitals.isEmpty) {
        setState(() {
          _errorMessage = 'Tidak ada rumah sakit ditemukan di sekitar Anda.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _filterHospitals(String query) async {
    if (_currentPosition == null) {
      return;
    }

    // Cancel timer sebelumnya
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      // Jika query kosong, load nearby hospitals
      await _loadNearbyHospitals();
      return;
    }

    // Debounce untuk real-time search (300ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Cari rumah sakit berdasarkan query
        final hospitals = await MapService.searchHospitalsByQuery(
          query: query,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          limit: 30,
        );

        if (mounted) {
          setState(() {
            _filteredHospitals = hospitals;
            _isLoading = false;
          });

          if (hospitals.isEmpty) {
            setState(() {
              _errorMessage = 'Tidak ada hasil ditemukan untuk "$query"';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Terjadi kesalahan: $e';
            _isLoading = false;
          });
        }
      }
    });
  }

  // Buka Google Maps untuk navigasi
  Future<void> _openMapsNavigation(double lat, double lon, String name) async {
    final encodedName = Uri.encodeComponent(name);
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&destination_place_id=$encodedName&travelmode=driving',
    );

    final googleMapsAppUrl = Uri.parse(
      'google.navigation:q=$lat,$lon',
    );

    try {
      // Coba buka Google Maps app dulu
      if (await canLaunchUrl(googleMapsAppUrl)) {
        await launchUrl(googleMapsAppUrl);
      } else if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka Google Maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Buka telepon
  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber == '-' || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon tidak tersedia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final phoneUrl = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(phoneUrl)) {
      await launchUrl(phoneUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Cari Rumah Sakit',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Location Status Bar
          if (_currentPosition != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppColors.primaryBlue.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.my_location,
                      size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lokasi: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadNearbyHospitals,
                    tooltip: 'Refresh lokasi',
                  ),
                ],
              ),
            ),

          // Search Bar
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {}); // Update untuk menampilkan tombol clear
                    },
                    onSubmitted: _filterHospitals,
                    decoration: InputDecoration(
                      hintText: 'Cari rumah sakit...',
                      hintStyle: const TextStyle(color: AppColors.textLight),
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.textMedium),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppColors.textMedium),
                              onPressed: () {
                                _searchController.clear();
                                _loadNearbyHospitals();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      _filterHospitals(_searchController.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cari'),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Mencari rumah sakit terdekat...',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 80,
                              color: AppColors.textLight.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadNearbyHospitals,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : _filteredHospitals.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 80,
                                  color: AppColors.textLight.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Tidak ada hasil ditemukan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            itemCount: _filteredHospitals.length,
                            itemBuilder: (context, index) {
                              final hospital = _filteredHospitals[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      _showHospitalDetails(context, hospital);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBlue
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.local_hospital,
                                              color: AppColors.primaryBlue,
                                              size: 30,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  hospital['name']!.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textDark,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  hospital['address']!
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.textMedium,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on,
                                                      size: 14,
                                                      color:
                                                          AppColors.textLight,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      hospital['distance']!
                                                          .toString(),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            AppColors.textLight,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    const Icon(
                                                      Icons.star,
                                                      size: 14,
                                                      color: AppColors.warning,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      (hospital['rating']
                                                              as num)
                                                          .toStringAsFixed(1),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            AppColors.textLight,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: AppColors.textLight,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showHospitalDetails(
      BuildContext context, Map<String, dynamic> hospital) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hospital['type'] == 'Klinik'
                        ? Icons.medical_services
                        : Icons.local_hospital,
                    color: AppColors.primaryBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospital['name']!.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hospital['emergency'] == true
                              ? Colors.red.withOpacity(0.1)
                              : AppColors.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          hospital['type']!.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: hospital['emergency'] == true
                                ? Colors.red
                                : AppColors.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(Icons.location_on, hospital['address']!.toString()),
            _buildDetailRow(
                Icons.directions_walk, 'Jarak: ${hospital['distance']}'),
            _buildDetailRow(Icons.star,
                '${(hospital['rating'] as num).toStringAsFixed(1)} Rating'),
            if (hospital['phone'] != null && hospital['phone'] != '-')
              _buildDetailRow(Icons.phone, hospital['phone']!.toString()),
            if (hospital['openingHours'] != null &&
                hospital['openingHours'] != '-')
              _buildDetailRow(
                  Icons.access_time, hospital['openingHours']!.toString()),
            if (hospital['emergency'] == true)
              _buildDetailRow(Icons.emergency, 'Unit Gawat Darurat tersedia',
                  isEmergency: true),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openMapsNavigation(
                        hospital['latitude'] as double,
                        hospital['longitude'] as double,
                        hospital['name'].toString(),
                      );
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _makePhoneCall(hospital['phone']?.toString() ?? '-');
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Hubungi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: AppColors.primaryBlue),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text,
      {bool isEmergency = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isEmergency ? Colors.red : AppColors.primaryBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isEmergency ? Colors.red : AppColors.textDark,
                fontWeight: isEmergency ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
