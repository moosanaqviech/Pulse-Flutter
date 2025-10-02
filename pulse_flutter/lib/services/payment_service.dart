import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/deal.dart';
import '../utils/constants.dart';

class PaymentService extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> processPayment({
    required Deal deal,
    required String userId,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Step 1: Create Payment Intent on backend
      final clientSecret = await _createPaymentIntent(
        dealId: deal.id,
        userId: userId,
        amount: deal.dealPrice,
        description: '${deal.title} at ${deal.businessName}',
      );

      if (clientSecret == null) {
        return false;
      }

      // Step 2: Confirm payment with Stripe
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      // Step 3: Confirm payment on backend (handled by webhook)
      return true;
    } on StripeException catch (e) {
      _setError(_getStripeErrorMessage(e));
      return false;
    } catch (e) {
      _setError('Payment failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> _createPaymentIntent({
    required String dealId,
    required String userId,
    required double amount,
    required String description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${Constants.firebaseFunctionsUrl}/createPaymentIntent'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'dealId': dealId,
          'userId': userId,
          'amount': amount,
          'currency': 'usd',
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['clientSecret'];
        } else {
          _setError(data['error'] ?? 'Failed to create payment intent');
          return null;
        }
      } else {
        _setError('Server error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _setError('Network error: $e');
      return null;
    }
  }

  String _getStripeErrorMessage(StripeException e) {
    // Use the error type or message directly since FailureCode enum values vary
    final errorCode = e.error.code?.toString().toLowerCase() ?? '';
    final errorType = e.error.type?.toString().toLowerCase() ?? '';
    
    if (errorCode.contains('card_declined') || errorType.contains('card_error')) {
      return 'Your card was declined.';
    } else if (errorCode.contains('expired') || errorCode.contains('expiry')) {
      return 'Your card has expired.';
    } else if (errorCode.contains('cvc') || errorCode.contains('security')) {
      return 'Your card\'s security code is incorrect.';
    } else if (errorCode.contains('incorrect_number') || errorCode.contains('invalid_number')) {
      return 'Your card number is incorrect.';
    } else if (errorCode.contains('insufficient_funds')) {
      return 'Your card has insufficient funds.';
    } else if (errorCode.contains('processing')) {
      return 'An error occurred while processing your card.';
    } else if (errorCode.contains('authentication')) {
      return 'Your card requires authentication.';
    } else {
      // Fall back to the localized message or a generic error
      return e.error.localizedMessage ?? 
             e.error.message ?? 
             'Payment failed. Please try again.';
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