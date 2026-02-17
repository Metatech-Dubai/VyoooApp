import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore user document model. Do NOT store password.
class AppUserModel {
  const AppUserModel({
    required this.uid,
    required this.email,
    this.username,
    this.dob,
    this.profileImage,
    this.interests = const [],
    this.onboardingCompleted = false,
    required this.createdAt,
  });

  final String uid;
  final String email;
  final String? username;
  final String? dob;
  final String? profileImage;
  final List<String> interests;
  final bool onboardingCompleted;
  final Timestamp createdAt;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username ?? '',
      'dob': dob ?? '',
      'profileImage': profileImage ?? '',
      'interests': interests,
      'onboardingCompleted': onboardingCompleted,
      'createdAt': createdAt,
    };
  }

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    final interestsRaw = json['interests'];
    final interestsList = interestsRaw is List
        ? (interestsRaw).map((e) => e.toString()).toList()
        : <String>[];

    return AppUserModel(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String?,
      dob: json['dob'] as String?,
      profileImage: json['profileImage'] as String?,
      interests: interestsList,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] is Timestamp
          ? json['createdAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  AppUserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? dob,
    String? profileImage,
    List<String>? interests,
    bool? onboardingCompleted,
    Timestamp? createdAt,
  }) {
    return AppUserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      dob: dob ?? this.dob,
      profileImage: profileImage ?? this.profileImage,
      interests: interests ?? this.interests,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
