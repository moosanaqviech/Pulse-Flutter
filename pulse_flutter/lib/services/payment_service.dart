import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/deal.dart';

class PaymentService extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Process payment using Stripe Payment Sheet
  Future<bool> processPayment({
    required Deal deal,
    required String userId,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('🔵 Starting payment process for deal: ${deal.id}');

      // Step 1: Create Payment Intent via Cloud Function
      final clientSecret = await _createPaymentIntent(
        dealId: deal.id,
        userId: userId,
        amount: deal.dealPrice,
        description: '${deal.title} at ${deal.businessName}',
      );

      if (clientSecret == null) {
        _setError('Failed to initialize payment');
        return false;
      }

      debugPrint('✅ Payment Intent created');

      // Step 2: Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Pulse',
          style: ThemeMode.system,
          // Enable Google Pay
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            currencyCode: 'USD',
            testEnv: true, // Set to false for production
          ),
          // Enable Apple Pay (iOS only)
          applePay: const PaymentSheetApplePay(
            merchantCountryCode: 'US',
          ),
        ),
      );

      debugPrint('✅ Payment Sheet initialized');

      // Step 3: Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      debugPrint('✅ Payment completed successfully');

      return true;

    } on StripeException catch (e) {
      debugPrint('❌ Stripe Error: ${e.error.localizedMessage}');
      _setError(_getStripeErrorMessage(e));
      return false;
    } catch (e) {
      debugPrint('❌ Payment Error: $e');
      _setError('Payment failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Create Payment Intent using Firebase Cloud Function
  Future<String?> _createPaymentIntent({
    required String dealId,
    required String userId,
    required double amount,
    required String description,
  }) async {
    try {
      debugPrint('🔵 Creating payment intent...');
      debugPrint('   Deal ID: $dealId');
      debugPrint('   Amount: \${amount.toStringAsFixed(2)}');

      // Call Firebase Cloud Function
      final callable = FirebaseFunctions.instance
          .httpsCallable('createPaymentIntent');

      final response = await callable.call({
        'dealId': dealId,
        'amount': amount,
        'currency': 'usd',
      });

      debugPrint('✅ Payment intent response received');

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        return data['clientSecret'] as String?;
      } else {
        _setError(data['error']?.toString() ?? 'Failed to create payment intent');
        return null;
      }

    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Cloud Function Error: ${e.code} - ${e.message}');
      _setError(_getFirebaseFunctionError(e));
      return null;
    } catch (e) {
      debugPrint('❌ Error creating payment intent: $e');
      _setError('Network error: Unable to connect to payment server');
      return null;
    }
  }

  /// Get user-friendly error message from StripeException
  String _getStripeErrorMessage(StripeException e) {
    final error = e.error;
    
    // Check for common error codes
    final code = error.code?.toString().toLowerCase() ?? '';
    
    if (code.contains('cancel') || e.error.message?.contains('cancel') == true) {
      return 'Payment cancelled';
    }
    
    if (code.contains('card_declined') || code.contains('declined')) {
      return 'Your card was declined. Please try a different payment method.';
    }
    
    if (code.contains('expired')) {
      return 'Your card has expired. Please use a different card.';
    }
    
    if (code.contains('insufficient')) {
      return 'Insufficient funds. Please try a different card.';
    }
    
    if (code.contains('incorrect_cvc') || code.contains('invalid_cvc')) {
      return 'Invalid security code (CVC). Please check and try again.';
    }
    
    if (code.contains('incorrect_number') || code.contains('invalid_number')) {
      return 'Invalid card number. Please check and try again.';
    }
    
    if (code.contains('processing_error')) {
      return 'Error processing payment. Please try again.';
    }
    
    // Return localized message or generic error
    return error.localizedMessage ?? 
           error.message ?? 
           'Payment failed. Please try again.';
  }

  /// Get user-friendly error from Firebase Function error
  String _getFirebaseFunctionError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in to complete your purchase';
      case 'not-found':
        return 'Deal not found or no longer available';
      case 'resource-exhausted':
        return 'This deal is sold out';
      case 'failed-precondition':
        return 'Deal is no longer available';
      case 'invalid-argument':
        return 'Invalid payment information';
      case 'permission-denied':
        return 'You don\'t have permission to make this purchase';
      case 'unavailable':
        return 'Payment service temporarily unavailable. Please try again.';
      default:
        return e.message ?? 'Payment failed. Please try again.';
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