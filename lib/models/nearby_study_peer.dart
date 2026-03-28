class NearbyStudyPeer {
  const NearbyStudyPeer({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.studyStatus,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String studyStatus;
  final double latitude;
  final double longitude;
  final double distanceMeters;

  NearbyStudyPeer copyWith({double? distanceMeters}) {
    return NearbyStudyPeer(
      id: id,
      displayName: displayName,
      avatarUrl: avatarUrl,
      studyStatus: studyStatus,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }
}