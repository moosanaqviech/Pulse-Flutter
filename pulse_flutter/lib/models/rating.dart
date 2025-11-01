import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id;
  final String userId;
  final String businessId;
  final String businessName;
  final String? dealId;
  final String? dealTitle;
  final int stars;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Rating({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.businessName,
    this.dealId,
    this.dealTitle,
    required this.stars,
    this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'businessId': businessId,
      'businessName': businessName,
      'dealId': dealId,
      'dealTitle': dealTitle,
      'stars': stars,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Rating.fromMap(Map<String, dynamic> map, String id) {
    return Rating(
      id: id,
      userId: map['userId'] ?? '',
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      dealId: map['dealId'],
      dealTitle: map['dealTitle'],
      stars: map['stars'] ?? 0,
      comment: map['comment'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Rating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Rating.fromMap(data, doc.id);
  }

  Rating copyWith({
    String? id,
    String? userId,
    String? businessId,
    String? businessName,
    String? dealId,
    String? dealTitle,
    int? stars,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Rating(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      dealId: dealId ?? this.dealId,
      dealTitle: dealTitle ?? this.dealTitle,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}