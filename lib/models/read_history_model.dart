import 'package:cloud_firestore/cloud_firestore.dart';

class ReadHistoryModel {
  final String id;
  final DateTime readAt;

  const ReadHistoryModel({
    required this.id,
    required this.readAt,
  });

  ReadHistoryModel copyWith({
    String? id,
    DateTime? readAt,
  }) {
    return ReadHistoryModel(
      id: id ?? this.id,
      readAt: readAt ?? this.readAt,
    );
  }

  factory ReadHistoryModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ReadHistoryModel(
      id: documentId,
      readAt: (map['readAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'readAt': Timestamp.fromDate(readAt),
    };
  }
}
