import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/location/places_location_service.dart';

void main() {
  test('manualLocation trims and sets source', () {
    final loc = PlacesLocationService.manualLocation(
      city: ' Dubai ',
      countryOrRegion: ' UAE ',
    );
    expect(loc.name, 'Dubai, UAE');
    expect(loc.source, 'manual');
    expect(loc.latitude, isNull);
  });

  test('manualLocation city only', () {
    final loc = PlacesLocationService.manualLocation(city: 'London');
    expect(loc.name, 'London');
  });

  test('parseAddressComponents extracts city and country', () {
    final parts = PlacesLocationService.parseAddressComponents([
      {
        'long_name': 'Dubai',
        'types': ['locality', 'political'],
      },
      {
        'long_name': 'Dubai',
        'types': ['administrative_area_level_1', 'political'],
      },
      {
        'long_name': 'United Arab Emirates',
        'types': ['country', 'political'],
      },
    ]);
    expect(parts.city, 'Dubai');
    expect(parts.countryOrRegion, 'United Arab Emirates');
    expect(parts.displayLabel, 'Dubai, United Arab Emirates');
  });

  test('parseAddressComponents includes state before country', () {
    final parts = PlacesLocationService.parseAddressComponents([
      {
        'long_name': 'San Francisco',
        'types': ['locality', 'political'],
      },
      {
        'long_name': 'California',
        'types': ['administrative_area_level_1', 'political'],
      },
      {
        'long_name': 'United States',
        'types': ['country', 'political'],
      },
    ]);
    expect(parts.city, 'San Francisco');
    expect(parts.countryOrRegion, 'California, United States');
  });
}
