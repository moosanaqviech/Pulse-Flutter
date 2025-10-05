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
    
    return Purchase(
      id: doc.id,
      userId: data['userId'] ?? '',
      dealId: data['dealId'] ?? '',
      dealTitle: data['dealTitle'] ?? '',
      businessName: data['businessName'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'pending',
      purchaseTime: data['purchaseTime'] ?? 0,
      expirationTime: data['expirationTime'] ?? 0,
      qrCode: data['qrCode'],
      imageUrl: data['imageUrl'],
      dealSnapshot: data['dealSnapshot'] as Map<String, dynamic>?,
    );
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
    );
  }

  @override
  String toString() {
    return 'Purchase(id: $id, dealTitle: $dealTitle, status: $status, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Purchase && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}