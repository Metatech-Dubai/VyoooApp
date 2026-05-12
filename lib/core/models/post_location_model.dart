import 'package:cloud_firestore/cloud_firestore.dart';

class PostLocation {
  const PostLocation({
    this.placeId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    required this.source,
    this.selectedAt,
  });

  final String? placeId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String source;
  final Timestamp? selectedAt;

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'source': source,
      'selectedAt': selectedAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory PostLocation.fromMap(Map<String, dynamic> map) {
    return PostLocation(
      placeId: map['placeId'] as String?,
      name: (map['name'] as String?) ?? '',
      address: map['address'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      source: (map['source'] as String?) ?? 'search',
      selectedAt: map['selectedAt'] as Timestamp?,
    );
  }
}
