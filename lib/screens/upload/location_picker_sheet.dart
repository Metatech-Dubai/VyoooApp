import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/models/post_location_model.dart';

Future<PostLocation?> showLocationPickerSheet(BuildContext context) {
  return showModalBottomSheet<PostLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A0020),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _LocationPickerBody(),
  );
}

class _LocationPickerBody extends StatefulWidget {
  const _LocationPickerBody();

  @override
  State<_LocationPickerBody> createState() => _LocationPickerBodyState();
}

class _LocationPickerBodyState extends State<_LocationPickerBody> {
  static const Color _pink = Color(0xFFDE106B);

  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _sessionToken;
  List<_PlacePrediction> _predictions = [];
  bool _searching = false;
  bool _gpsLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchPredictions(query.trim());
    });
  }

  Future<void> _fetchPredictions(String input) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
        'input': input,
        'key': AppConfig.googlePlacesApiKey,
        'sessiontoken': _sessionToken ?? '',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _searching = false;
          _error = 'Search failed. Try again.';
        });
        return;
      }
      final body = json.decode(res.body) as Map<String, dynamic>;
      final status = body['status'] as String? ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        setState(() {
          _searching = false;
          _error = 'Search unavailable.';
        });
        return;
      }
      final results = (body['predictions'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map((p) => _PlacePrediction(
                placeId: p['place_id'] as String? ?? '',
                description: p['description'] as String? ?? '',
                mainText: (p['structured_formatting'] as Map?)?['main_text'] as String? ?? '',
                secondaryText: (p['structured_formatting'] as Map?)?['secondary_text'] as String? ?? '',
              ))
          .toList();
      setState(() {
        _predictions = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Search failed. Check your connection.';
      });
    }
  }

  Future<void> _selectPrediction(_PlacePrediction prediction) async {
    setState(() => _searching = true);
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': prediction.placeId,
        'fields': 'place_id,name,formatted_address,geometry',
        'key': AppConfig.googlePlacesApiKey,
        'sessiontoken': _sessionToken ?? '',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      double? lat;
      double? lng;
      String? address;
      String name = prediction.mainText;
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final result = body['result'] as Map<String, dynamic>?;
        if (result != null) {
          name = (result['name'] as String?) ?? name;
          address = result['formatted_address'] as String?;
          final geo = result['geometry'] as Map<String, dynamic>?;
          final loc = geo?['location'] as Map<String, dynamic>?;
          lat = (loc?['lat'] as num?)?.toDouble();
          lng = (loc?['lng'] as num?)?.toDouble();
        }
      }
      _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
      if (!mounted) return;
      Navigator.of(context).pop(PostLocation(
        placeId: prediction.placeId,
        name: name,
        address: address,
        latitude: lat,
        longitude: lng,
        source: 'search',
      ));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(PostLocation(
        placeId: prediction.placeId,
        name: prediction.mainText.isNotEmpty ? prediction.mainText : prediction.description,
        address: prediction.secondaryText,
        source: 'search',
      ));
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _gpsLoading = true;
      _error = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _gpsLoading = false;
          _error = 'Location services are disabled. Enable them in Settings.';
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _gpsLoading = false;
          _error = 'Location permission denied. You can still search for a location.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      String name = 'Current location';
      String? address;
      try {
        final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
          'latlng': '${position.latitude},${position.longitude}',
          'key': AppConfig.googlePlacesApiKey,
          'result_type': 'street_address|locality|sublocality',
        });
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final body = json.decode(res.body) as Map<String, dynamic>;
          final results = body['results'] as List? ?? [];
          if (results.isNotEmpty) {
            final first = results[0] as Map<String, dynamic>;
            address = first['formatted_address'] as String?;
            final components = first['address_components'] as List? ?? [];
            for (final comp in components) {
              final types = (comp as Map)['types'] as List? ?? [];
              if (types.contains('locality') || types.contains('sublocality')) {
                name = comp['long_name'] as String? ?? name;
                break;
              }
            }
          }
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pop(PostLocation(
        name: name,
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
        source: 'gps',
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gpsLoading = false;
        _error = 'Could not get location. Try searching instead.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Location',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search location',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.5)),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _gpsLoading ? null : _useCurrentLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.my_location_rounded, color: _pink, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'Use current location',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      const Spacer(),
                      if (_gpsLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator(color: Colors.white24))
                  : _predictions.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'Search for a place or use current location'
                                : 'No results found',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _predictions.length,
                          separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                          itemBuilder: (_, i) {
                            final p = _predictions[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.location_on_outlined, color: Colors.white.withValues(alpha: 0.5)),
                              title: Text(
                                p.mainText.isNotEmpty ? p.mainText : p.description,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              subtitle: p.secondaryText.isNotEmpty
                                  ? Text(
                                      p.secondaryText,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onTap: () => _selectPrediction(p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacePrediction {
  const _PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
}
