import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isLocationVisible;
  final GeoPoint? lastLocation;
  final int streakDays;
  final List<String> badges;
  final Map<String, dynamic> settings;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.isLocationVisible,
    this.lastLocation,
    required this.streakDays,
    required this.badges,
    required this.settings,
    required this.createdAt,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isLocationVisible,
    GeoPoint? lastLocation,
    int? streakDays,
    List<String>? badges,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isLocationVisible: isLocationVisible ?? this.isLocationVisible,
      lastLocation: lastLocation ?? this.lastLocation,
      streakDays: streakDays ?? this.streakDays,
      badges: badges ?? this.badges,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      isLocationVisible: map['isLocationVisible'] as bool? ?? false,
      lastLocation: map['lastLocation'] as GeoPoint?,
      streakDays: map['streakDays'] as int? ?? 0,
      badges: List<String>.from(map['badges'] ?? []),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'isLocationVisible': isLocationVisible,
      if (lastLocation != null) 'lastLocation': lastLocation,
      'streakDays': streakDays,
      'badges': badges,
      'settings': settings,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}