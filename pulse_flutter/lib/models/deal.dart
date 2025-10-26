import 'package:cloud_firestore/cloud_firestore.dart';

class Deal {
  final String id;
  final String title;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final double originalPrice;
  final double dealPrice;
  final int totalQuantity;
  final int remainingQuantity;
  final String businessName;
  final String businessAddress;
  final int expirationTime;
  final String? imageUrl;
  final bool isActive;

  Deal({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.originalPrice,
    required this.dealPrice,
    required this.totalQuantity,
    required this.remainingQuantity,
    required this.businessName,
    required this.businessAddress,
    required this.expirationTime,
    this.imageUrl,
    this.isActive = true,
  });

  // Calculate discount percentage
  int get discountPercentage {
    if (originalPrice <= 0) return 0;
    return ((originalPrice - dealPrice) / originalPrice * 100).round();
  }

  // Check if deal is expired
  bool get isExpired {
    return DateTime.now().millisecondsSinceEpoch > expirationTime;
  }

  // Check if deal is sold out
  bool get isSoldOut {
    return remainingQuantity <= 0;
  }

  // Get expiration date
  DateTime get expirationDate {
    return DateTime.fromMillisecondsSinceEpoch(expirationTime);
  }

  // Get category emoji
  String get categoryEmoji {
    switch (category.toLowerCase()) {
      case 'restaurant':
        return '🍽️';
      case 'cafe':
        return '☕';
      case 'shop':
        return '🛍️';
      case 'activity':
        return '🎯';
      default:
        return '⭐';
    }
  }

  // Get category display name
  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'restaurant':
        return 'Restaurant';
      case 'cafe':
        return 'Café';
      case 'shop':
        return 'Shop';
      case 'activity':
        return 'Activity';
      default:
        return 'Other';
    }
  }

  // Create Deal from Firestore document
  factory Deal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    print('🔍 Loading deal: ${doc.id}');
    print('🔍 expirationTime raw: ${data['expirationTime']}');
    print('🔍 expirationTime type: ${data['expirationTime'].runtimeType}');
    return Deal(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      originalPrice: (data['originalPrice'] ?? 0.0).toDouble(),
      dealPrice: (data['dealPrice'] ?? 0.0).toDouble(),
      totalQuantity: data['totalQuantity'] ?? 0,
      remainingQuantity: data['remainingQuantity'] ?? 0,
      businessName: data['businessName'] ?? '',
      businessAddress: data['businessAddress']?? '',
      expirationTime: _parseExpirationTime(data['expirationTime']),
      imageUrl: data['imageUrl'],
      isActive: data['isActive'] ?? true,
    );
  }

  // Convert Deal to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'originalPrice': originalPrice,
      'dealPrice': dealPrice,
      'totalQuantity': totalQuantity,
      'remainingQuantity': remainingQuantity,
      'businessName': businessName,
      'expirationTime': expirationTime,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }


static int _parseExpirationTime(dynamic value) {
    try {
      if (value == null) {
        return DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch;
      }
      
      if (value is int) {
        return value;  // Old format
      }
      
      if (value is Timestamp) {
        return value.toDate().millisecondsSinceEpoch;  // NEW format
      }
      
      if (value is String) {
        return DateTime.parse(value).millisecondsSinceEpoch;
      }
      
      if (value is DateTime) {
        return value.millisecondsSinceEpoch;
      }
      
      print('⚠️ Unknown expirationTime type: ${value.runtimeType}');
      return DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch;
      
    } catch (e) {
      print('❌ Error parsing expirationTime: $e');
      return DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch;
    }
  }
  // Create a copy with updated values
  Deal copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? latitude,
    double? longitude,
    double? originalPrice,
    double? dealPrice,
    int? totalQuantity,
    int? remainingQuantity,
    String? businessName,
    int? expirationTime,
    String? imageUrl,
    bool? isActive,
  }) {
    return Deal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      originalPrice: originalPrice ?? this.originalPrice,
      dealPrice: dealPrice ?? this.dealPrice,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      expirationTime: expirationTime ?? this.expirationTime,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'Deal(id: $id, title: $title, businessName: $businessName, dealPrice: $dealPrice)';
  }



  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Deal && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  
}