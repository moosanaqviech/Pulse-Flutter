// pulse_flutter/lib/services/voucher_notification_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../models/purchase.dart';
import '../screens/voucher_detail_screen.dart';

class VoucherNotificationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _voucherSubscription;
  
  Map<String, Purchase> _lastKnownVouchers = {};
  bool _isListening = false;

  bool get isListening => _isListening;

  /// Start listening for voucher updates for a specific user
  void startListening(String userId, Function(VoucherUpdate) onUpdate) {
    if (_isListening) {
      stopListening();
    }

    _isListening = true;
    
    _voucherSubscription = _firestore
        .collection('purchases')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['confirmed', 'redeemed'])
        .snapshots()
        .listen(
          (snapshot) {
            try {
              _handleVoucherUpdates(snapshot, onUpdate);
            } catch (e) {
              debugPrint('Error handling voucher updates: $e');
            }
          },
          onError: (error) {
            debugPrint('Voucher subscription error: $error');
          },
        );
  }

  /// Stop listening for voucher updates
  void stopListening() {
    _voucherSubscription?.cancel();
    _voucherSubscription = null;
    _isListening = false;
    _lastKnownVouchers.clear();
  }

  void _handleVoucherUpdates(
    QuerySnapshot snapshot, 
    Function(VoucherUpdate) onUpdate
  ) {
    try {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        final purchase = Purchase.fromFirestore(change.doc);
        final purchaseId = purchase.id;

        switch (change.type) {
          case DocumentChangeType.added:
            // New voucher created
            _lastKnownVouchers[purchaseId] = purchase;
            if (purchase.hasQRCode) {
              onUpdate(VoucherUpdate(
                type: VoucherUpdateType.created,
                purchase: purchase,
                message: 'New voucher is ready to use!',
              ));
            }
            break;

          case DocumentChangeType.modified:
            final lastKnown = _lastKnownVouchers[purchaseId];
            
            if (lastKnown != null) {
              // Check if QR code was just generated
              if (!lastKnown.hasQRCode && purchase.hasQRCode) {
                onUpdate(VoucherUpdate(
                  type: VoucherUpdateType.qrGenerated,
                  purchase: purchase,
                  message: 'Your voucher QR code is ready!',
                ));
              }
              
              // Check if voucher was redeemed
              if (!lastKnown.isRedeemed && purchase.isRedeemed) {
                onUpdate(VoucherUpdate(
                  type: VoucherUpdateType.redeemed,
                  purchase: purchase,
                  message: 'Your voucher has been redeemed!',
                ));
              }
            }
            
            _lastKnownVouchers[purchaseId] = purchase;
            break;

          case DocumentChangeType.removed:
            _lastKnownVouchers.remove(purchaseId);
            break;
        }
      }
    } catch (e) {
      debugPrint('Error processing voucher updates: $e');
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

enum VoucherUpdateType {
  created,
  qrGenerated,
  redeemed,
}

class VoucherUpdate {
  final VoucherUpdateType type;
  final Purchase purchase;
  final String message;

  VoucherUpdate({
    required this.type,
    required this.purchase,
    required this.message,
  });
}

// Extension to show notifications in UI
extension VoucherNotificationUI on VoucherUpdate {
  void showNotification(BuildContext context) {
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      
      // Clear any existing snackbars
      messenger.clearSnackBars();
      
      Color backgroundColor;
      IconData icon;
      
      switch (type) {
        case VoucherUpdateType.created:
          backgroundColor = Colors.blue;
          icon = Icons.local_offer;
          break;
        case VoucherUpdateType.qrGenerated:
          backgroundColor = Colors.green;
          icon = Icons.qr_code;
          break;
        case VoucherUpdateType.redeemed:
          backgroundColor = Colors.green;
          icon = Icons.check_circle;
          break;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      purchase.dealTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              try {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => VoucherDetailScreen(purchase: purchase),
                  ),
                );
              } catch (e) {
                debugPrint('Error navigating to voucher detail: $e');
              }
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing voucher notification: $e');
    }
  }
}