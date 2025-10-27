// pulse_flutter/lib/models/purchase.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Purchase {
  final String id;
  final String userId;
  final String dealId;
  final String dealTitle;
  final String businessName;
  final double amount;
  final String status; // 'pending', 'confirmed', 'redeemed', 'expired'
  final int purchaseTime;
  final int expirationTime;
  final String? qrCode;
  final String? imageUrl;
  final Map<String, dynamic>? dealSnapshot;
  final DateTime? redeemedAt; // NEW: When voucher was redeemed
  final String? redeemedBy; // NEW: Who redeemed it (business user ID)

  Purchase({
    required this.id,
    required this.userId,
    required this.dealId,
    required this.dealTitle,
    required this.businessName,
    required this.amount,
    required this.status,
    required this.purchaseTime,
    required this.expirationTime,
    this.qrCode,
    this.imageUrl,
    this.dealSnapshot,
    this.redeemedAt,
    this.redeemedBy,
  });

  // Check if purchase is expired
  bool get isExpired {
    return DateTime.now().millisecondsSinceEpoch > expirationTime;
  }

  // Check if purchase is redeemed
  bool get isRedeemed {
    return status == 'redeemed';
  }

  // Check if purchase is active (confirmed and not expired/redeemed)
  bool get isActive {
    return status == 'confirmed' && !isExpired && !isRedeemed;
  }

  // Check if has QR code
  bool get hasQRCode {
    return qrCode != null && qrCode!.isNotEmpty;
  }

  // Get purchase date
  DateTime get purchaseDate {
    return DateTime.fromMillisecondsSinceEpoch(purchaseTime);
  }

  // Get expiration date
  DateTime get expirationDate {
    return DateTime.fromMillisecondsSinceEpoch(expirationTime);
  }

  // Create Purchase from Firestore document
  factory Purchase.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Purchase.fromMap(data, doc.id);
  }

  // Create Purchase from Map with optional ID
  factory Purchase.fromMap(Map<String, dynamic> data, [String? docId]) {
    return Purchase(
      id: docId ?? data['id'] ?? '',
      userId: data['userId'] ?? '',
      dealId: data['dealId'] ?? '',
      dealTitle: data['dealTitle'] ?? '',
      businessName: data['businessName'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'pending',
      purchaseTime: _parseTimestampToInt(data['purchaseTime']),
      expirationTime: _parseTimestampToInt(data['expirationTime']),
      qrCode: data['qrCode'],
      imageUrl: data['imageUrl'],
      dealSnapshot: data['dealSnapshot'] as Map<String, dynamic>?,
      redeemedAt: data['redeemedAt'] != null 
        ? _parseTimestamp(data['redeemedAt'])
        : null,
      redeemedBy: data['redeemedBy'],
    );
  }

  // Helper method to parse timestamps from various formats
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now();
    }

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }

    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }

    return DateTime.now();
  }

  // Convert Purchase to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'dealId': dealId,
      'dealTitle': dealTitle,
      'businessName': businessName,
      'amount': amount,
      'status': status,
      'purchaseTime': purchaseTime,
      'expirationTime': expirationTime,
      'qrCode': qrCode,
      'imageUrl': imageUrl,
      'dealSnapshot': dealSnapshot,
      'redeemedAt': redeemedAt?.millisecondsSinceEpoch,
      'redeemedBy': redeemedBy,
    };
  }

  // Create a copy with updated values
  Purchase copyWith({
    String? id,
    String? userId,
    String? dealId,
    String? dealTitle,
    String? businessName,
    double? amount,
    String? status,
    int? purchaseTime,
    int? expirationTime,
    String? qrCode,
    String? imageUrl,
    Map<String, dynamic>? dealSnapshot,
    DateTime? redeemedAt,
    String? redeemedBy,
  }) {
    return Purchase(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dealId: dealId ?? this.dealId,
      dealTitle: dealTitle ?? this.dealTitle,
      businessName: businessName ?? this.businessName,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      purchaseTime: purchaseTime ?? this.purchaseTime,
      expirationTime: expirationTime ?? this.expirationTime,
      qrCode: qrCode ?? this.qrCode,
      imageUrl: imageUrl ?? this.imageUrl,
      dealSnapshot: dealSnapshot ?? this.dealSnapshot,
      redeemedAt: redeemedAt ?? this.redeemedAt,
      redeemedBy: redeemedBy ?? this.redeemedBy,
    );
  }

  static int _parseTimestampToInt(dynamic value) {
  if (value == null) return 0;
  
  if (value is int) {
    return value;  // Old format
  }
  
  if (value is Timestamp) {
    return value.toDate().millisecondsSinceEpoch;  // New format
  }
  
  return 0;
}

  @override
  String toString() {
    return 'Purchase(id: $id, dealTitle: $dealTitle, status: $status, amount: $amount, isRedeemed: $isRedeemed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Purchase && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}