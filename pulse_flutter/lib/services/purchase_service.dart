import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/purchase.dart';
import '../models/deal.dart';

class PurchaseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Purchase> _purchases = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Purchase> get purchases => _purchases;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get active purchases (confirmed and not expired/redeemed)
  List<Purchase> get activePurchases {
    return _purchases.where((p) => p.isActive).toList();
  }

  // Get redeemed purchases
  List<Purchase> get redeemedPurchases {
    return _purchases.where((p) => p.isRedeemed).toList();
  }

  // Get expired purchases
  List<Purchase> get expiredPurchases {
    return _purchases.where((p) => p.isExpired && !p.isRedeemed).toList();
  }

  /// Load all purchases for a user
  Future<void> loadPurchases(String userId) async {
    try {
      _setLoading(true);
      _clearError();

      final querySnapshot = await _firestore
          .collection('purchases')
          .where('userId', isEqualTo: userId)
          .orderBy('purchaseTime', descending: true)
          .get();

      _purchases = querySnapshot.docs
          .map((doc) => Purchase.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading purchases: $e');
      _setError('Failed to load purchase history');
    } finally {
      _setLoading(false);
    }
  }

  /// Get a specific purchase by ID
  Future<Purchase?> getPurchase(String purchaseId) async {
    try {
      final doc = await _firestore.collection('purchases').doc(purchaseId).get();
      
      if (doc.exists) {
        return Purchase.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting purchase: $e');
      return null;
    }
  }

  /// Confirm payment after successful Stripe charge
  /// This calls the Firebase Cloud Function to update purchase status and generate QR code
  Future<Purchase?> confirmPayment({
    required String purchaseId,
    required String userId,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('🔵 Confirming payment for purchase: $purchaseId');

      // Call Firebase Cloud Function to confirm payment
      final callable = FirebaseFunctions.instance
          .httpsCallable('confirmPayment');

      // IMPORTANT: Send purchaseId, not paymentIntentId
      final response = await callable.call({
        'purchaseId': purchaseId,  // This is the correct parameter name
        'userId': userId,
      });

      debugPrint('✅ Payment confirmed response: ${response.data}');

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        // Fetch the updated purchase with QR code
        final purchase = await getPurchase(purchaseId);
        
        if (purchase != null) {
          // Update local list
          final index = _purchases.indexWhere((p) => p.id == purchaseId);
          if (index != -1) {
            _purchases[index] = purchase;
          } else {
            _purchases.insert(0, purchase);
          }
          notifyListeners();
          
          return purchase;
        } else {
          debugPrint('⚠️ Purchase confirmed but could not fetch updated data');
          // Still return success - create a purchase object from the response
          return Purchase(
            id: purchaseId,
            userId: userId,
            dealId: '',
            dealTitle: '',
            businessId: '',
            businessName: '',
            amount: 0,
            status: 'confirmed',
            purchaseTime: DateTime.now().millisecondsSinceEpoch,
            expirationTime: DateTime.now().millisecondsSinceEpoch,
            qrCode: data['qrCode'] as String?,
          );
        }
      } else {
        _setError(data['error']?.toString() ?? 'Failed to confirm payment');
      }
      
      return null;

    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Cloud Function Error: ${e.code} - ${e.message}');
      debugPrint('❌ Details: ${e.details}');
      _setError(_getFirebaseFunctionError(e));
      return null;
    } catch (e) {
      debugPrint('❌ Error confirming payment: $e');
      _setError('Failed to confirm payment: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Create initial purchase record (called before Stripe payment)
  Future<String?> createPurchase({
    required String userId,
    required Deal deal,
  }) async {
    try {
      debugPrint('🔵 Creating purchase record for deal: ${deal.id}');

      final purchaseData = {
        'userId': userId,
        'dealId': deal.id,
        'dealTitle': deal.title,
        'businessId': deal.businessId,
        'businessName': deal.businessName,
        'amount': deal.dealPrice,
        'status': 'pending',
        'purchaseTime': DateTime.now().millisecondsSinceEpoch,
        'expirationTime': deal.expirationTime,
        'imageUrl': deal.imageUrl,
        'dealSnapshot': deal.toMap(),
      };

      final docRef = await _firestore.collection('purchases').add(purchaseData);
      
      debugPrint('✅ Purchase record created: ${docRef.id}');
      
      return docRef.id;

    } catch (e) {
      debugPrint('❌ Error creating purchase: $e');
      return null;
    }
  }

  /// Redeem a voucher (mark as redeemed)
  Future<bool> redeemVoucher(String purchaseId) async {
    try {
      await _firestore.collection('purchases').doc(purchaseId).update({
        'status': 'redeemed',
        'redeemedAt': FieldValue.serverTimestamp(),
      });

      // Update local list
      final index = _purchases.indexWhere((p) => p.id == purchaseId);
      if (index != -1) {
        _purchases[index] = _purchases[index].copyWith(status: 'redeemed');
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('Error redeeming voucher: $e');
      return false;
    }
  }

  /// Get user-friendly error from Firebase Function error
  String _getFirebaseFunctionError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in to view your purchases';
      case 'not-found':
        return 'Purchase not found';
      case 'permission-denied':
        return 'You don\'t have permission to access this purchase';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'invalid-argument':
        return 'Invalid request: ${e.message}';
      default:
        return e.message ?? 'An error occurred';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}