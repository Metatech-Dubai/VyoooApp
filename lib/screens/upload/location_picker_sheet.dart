import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/location/places_location_service.dart';
import '../../core/models/post_location_model.dart';
import '../../core/theme/app_light_surface.dart';
import '../../core/widgets/app_bottom_sheet.dart';

Future<PostLocation?> showLocationPickerSheet(BuildContext context) {
  return showModalBottomSheet<PostLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LocationPickerBody(),
  );
}

class _LocationPickerBody extends StatefulWidget {
  const _LocationPickerBody();

  @override
  State<_LocationPickerBody> createState() => _LocationPickerBodyState();
}

class _LocationPickerBodyState extends State<_LocationPickerBody> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late String _sessionToken;
  List<PlacePrediction> _predictions = [];
  bool _searching = false;
  bool _gpsLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sessionToken = PlacesLocationService.newSessionToken();
    _searchController.addListener(() => setState(() {}));
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
      final results = await PlacesLocationService.fetchPredictions(
        input: input,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      setState(() {
        _predictions = results;
        _searching = false;
      });
    } on PlacesLocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Search failed. Check your connection.';
      });
    }
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    setState(() => _searching = true);
    try {
      final location = await PlacesLocationService.resolvePredictionLocation(
        prediction: prediction,
        sessionToken: _sessionToken,
      );
      _sessionToken = PlacesLocationService.newSessionToken();
      if (!mounted) return;
      Navigator.of(context).pop(location);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(
        PlacesLocationService.manualLocation(
          city: prediction.mainText.isNotEmpty
              ? prediction.mainText
              : prediction.description,
        ),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _gpsLoading = true;
      _error = null;
    });
    try {
      final resolved = await PlacesLocationService.currentLocation();
      if (!mounted) return;
      Navigator.of(context).pop(resolved.location);
    } on PlacesLocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsLoading = false;
        _error = e.message;
      });
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
        child: AppBottomSheet.shell(
          child: Column(
            children: [
              AppBottomSheet.dragHandle(),
              Text(
                'Add Location',
                style: TextStyle(
                  color: AppLightSurface.primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppLightSurface.cardFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppLightSurface.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(
                      color: AppLightSurface.primaryText,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search city or region',
                      hintStyle: TextStyle(color: AppLightSurface.mutedText),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppLightSurface.mutedText,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppLightSurface.mutedText,
                              ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppLightSurface.cardFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppLightSurface.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          color: AppColors.brandPink,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Use current location',
                          style: TextStyle(
                            color: AppLightSurface.primaryText,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        if (_gpsLoading)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppLightSurface.mutedText,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: _searching
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppLightSurface.mutedText,
                        ),
                      )
                    : _predictions.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'Search for a city or use current location'
                                  : 'No results found',
                              style: TextStyle(
                                color: AppLightSurface.mutedText,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _predictions.length,
                            separatorBuilder: (context, index) => Divider(
                              color: AppLightSurface.divider,
                              height: 1,
                            ),
                            itemBuilder: (_, i) {
                              final p = _predictions[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.location_city_outlined,
                                  color: AppLightSurface.mutedText,
                                ),
                                title: Text(
                                  p.mainText.isNotEmpty
                                      ? p.mainText
                                      : p.description,
                                  style: TextStyle(
                                    color: AppLightSurface.primaryText,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: p.secondaryText.isNotEmpty
                                    ? Text(
                                        p.secondaryText,
                                        style: TextStyle(
                                          color: AppLightSurface.secondaryText,
                                          fontSize: 12,
                                        ),
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
      ),
    );
  }
}
