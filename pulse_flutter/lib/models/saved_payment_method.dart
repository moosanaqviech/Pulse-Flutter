import 'package:cloud_firestore/cloud_firestore.dart';

class SavedPaymentMethod {
  final String id;
  final String userId;
  final String stripePaymentMethodId;
  final String cardLast4;
  final String cardBrand;
  final String cardExpMonth;
  final String cardExpYear;
  final String? cardholderName;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedPaymentMethod({
    required this.id,
    required this.userId,
    required this.stripePaymentMethodId,
    required this.cardLast4,
    required this.cardBrand,
    required this.cardExpMonth,
    required this.cardExpYear,
    this.cardholderName,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory SavedPaymentMethod.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SavedPaymentMethod(
      id: doc.id,
      userId: data['userId'] ?? '',
      stripePaymentMethodId: data['stripePaymentMethodId'] ?? '',
      cardLast4: data['cardLast4'] ?? '',
      cardBrand: data['cardBrand'] ?? '',
      cardExpMonth: data['cardExpMonth'] ?? '',
      cardExpYear: data['cardExpYear'] ?? '',
      cardholderName: data['cardholderName'],
      isDefault: data['isDefault'] ?? false,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'stripePaymentMethodId': stripePaymentMethodId,
      'cardLast4': cardLast4,
      'cardBrand': cardBrand,
      'cardExpMonth': cardExpMonth,
      'cardExpYear': cardExpYear,
      'cardholderName': cardholderName,
      'isDefault': isDefault,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Get formatted card display text
  String get displayText {
    final brand = cardBrand.toUpperCase();
    return '$brand •••• $cardLast4';
  }

  /// Get card brand icon
  String get cardBrandIcon {
    switch (cardBrand.toLowerCase()) {
      case 'visa':
        return '💳'; // In real app, use proper Visa icon
      case 'mastercard':
        return '💳'; // In real app, use proper Mastercard icon
      case 'american_express':
      case 'amex':
        return '💳'; // In real app, use proper Amex icon
      case 'discover':
        return '💳'; // In real app, use proper Discover icon
      default:
        return '💳';
    }
  }

  /// Check if card is expired
  bool get isExpired {
    final now = DateTime.now();
    final expMonth = int.tryParse(cardExpMonth) ?? 1;
    final expYear = int.tryParse(cardExpYear) ?? now.year;
    
    // Card expires at the end of the expiration month
    final expirationDate = DateTime(expYear, expMonth + 1, 0);
    
    return now.isAfter(expirationDate);
  }

  /// Copy with method for updates
  SavedPaymentMethod copyWith({
    String? id,
    String? userId,
    String? stripePaymentMethodId,
    String? cardLast4,
    String? cardBrand,
    String? cardExpMonth,
    String? cardExpYear,
    String? cardholderName,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedPaymentMethod(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      stripePaymentMethodId: stripePaymentMethodId ?? this.stripePaymentMethodId,
      cardLast4: cardLast4 ?? this.cardLast4,
      cardBrand: cardBrand ?? this.cardBrand,
      cardExpMonth: cardExpMonth ?? this.cardExpMonth,
      cardExpYear: cardExpYear ?? this.cardExpYear,
      cardholderName: cardholderName ?? this.cardholderName,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'SavedPaymentMethod(id: $id, displayText: $displayText, isDefault: $isDefault, isExpired: $isExpired)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SavedPaymentMethod &&
        other.id == id &&
        other.stripePaymentMethodId == stripePaymentMethodId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ stripePaymentMethodId.hashCode;
  }
}