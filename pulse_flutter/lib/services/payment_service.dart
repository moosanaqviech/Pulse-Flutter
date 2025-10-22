import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/deal.dart';
import '../models/saved_payment_method.dart';
import '../utils/payment_debugger.dart';

class PaymentService extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  List<SavedPaymentMethod> _savedPaymentMethods = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<SavedPaymentMethod> get savedPaymentMethods => _savedPaymentMethods;

  /// Load saved payment methods for user
  Future<void> loadSavedPaymentMethods(String userId) async {
    try {
      _setLoading(true);
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('payment_methods')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      _savedPaymentMethods = querySnapshot.docs
          .map((doc) => SavedPaymentMethod.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading saved payment methods: $e');
      _setError('Failed to load saved payment methods');
    } finally {
      _setLoading(false);
    }
  }

  /// Process payment with option to save card
 Future<bool> processPayment({
  required Deal deal,
  required String userId,
  required String purchaseId,
  bool saveCard = false,
  String? savedPaymentMethodId,
}) async {
  try {
    _setLoading(true);
    _clearError();

    // Add debugging
    PaymentDebugger.logStep('Starting payment service', 
      details: 'Deal: ${deal.id}, Amount: \$${deal.dealPrice}');

    String? clientSecret;

    if (savedPaymentMethodId != null) {
      // Use saved payment method for 1-tap purchase
      PaymentDebugger.startTimer('CREATE_PAYMENT_INTENT_SAVED');
      PaymentDebugger.logStep('Creating payment intent with saved method');
      
      clientSecret = await _createPaymentIntentWithSavedMethod(
        dealId: deal.id,
        userId: userId,
        purchaseId: purchaseId,
        amount: deal.dealPrice,
        description: '${deal.title} at ${deal.businessName}',
        paymentMethodId: savedPaymentMethodId,
      );
      
      PaymentDebugger.endTimer('CREATE_PAYMENT_INTENT_SAVED');
    } else {
      // Create new payment intent
      PaymentDebugger.startTimer('CREATE_PAYMENT_INTENT_NEW');
      PaymentDebugger.logStep('Creating new payment intent');
      
      clientSecret = await _createPaymentIntent(
        dealId: deal.id,
        userId: userId,
        purchaseId: purchaseId,
        amount: deal.dealPrice,
        description: '${deal.title} at ${deal.businessName}',
        setupFutureUsage: saveCard,
      );
      
      PaymentDebugger.endTimer('CREATE_PAYMENT_INTENT_NEW');
    }

    if (clientSecret == null) {
      _setError('Failed to initialize payment');
      return false;
    }

    PaymentDebugger.logStep('Payment Intent created successfully');

    // If using saved payment method, process automatically
    if (savedPaymentMethodId != null) {
      PaymentDebugger.startTimer('AUTOMATIC_PAYMENT');
      PaymentDebugger.logStep('Processing automatic payment');
      
      final result = await _processAutomaticPayment(clientSecret);
      
      PaymentDebugger.endTimer('AUTOMATIC_PAYMENT');
      return result;
    }

    // Initialize Payment Sheet for new payment
    PaymentDebugger.startTimer('INIT_PAYMENT_SHEET');
    PaymentDebugger.logStep('Initializing payment sheet');
    
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Pulse',
        style: ThemeMode.system,
        googlePay: const PaymentSheetGooglePay(
          merchantCountryCode: 'CA',
          currencyCode: 'CAD',
          testEnv: true,
        ),
        applePay: const PaymentSheetApplePay(
          merchantCountryCode: 'CA',
        ),
        primaryButtonLabel: saveCard ? 'Pay & Save Card' : 'Pay Now',
        billingDetailsCollectionConfiguration: const BillingDetailsCollectionConfiguration(
          email: CollectionMode.always,
          name: CollectionMode.always,
        ),
      ),
    );

    PaymentDebugger.endTimer('INIT_PAYMENT_SHEET');
    PaymentDebugger.logStep('Payment sheet initialized');

    // Present Payment Sheet
    PaymentDebugger.startTimer('PRESENT_PAYMENT_SHEET');
    PaymentDebugger.logStep('Presenting payment sheet to user');
    
    await Stripe.instance.presentPaymentSheet();
    
    PaymentDebugger.endTimer('PRESENT_PAYMENT_SHEET');
    PaymentDebugger.logStep('Payment sheet completed successfully');

    // If user chose to save card, save the payment method
    if (saveCard) {
      PaymentDebugger.startTimer('SAVE_PAYMENT_METHOD');
      PaymentDebugger.logStep('Saving payment method for future use');
      
      await _savePaymentMethodAfterPayment(userId, clientSecret);
      
      PaymentDebugger.endTimer('SAVE_PAYMENT_METHOD');
    }

    return true;

  } on StripeException catch (e) {
    PaymentDebugger.logStep('Stripe error', details: e.error.localizedMessage);
    _setError(_getStripeErrorMessage(e));
    return false;
  } catch (e) {
    PaymentDebugger.logStep('Payment service error', details: e.toString());
    _setError('Payment failed: ${e.toString()}');
    return false;
  } finally {
    _setLoading(false);
  }
}

/// Process automatic payment with saved payment method
  Future<bool> _processAutomaticPayment(String clientSecret) async {
    try {
      // Confirm payment intent on backend
      final callable = FirebaseFunctions.instance
          .httpsCallable('confirmPaymentIntent');

      final response = await callable.call({
        'clientSecret': clientSecret,
      });

      final data = response.data as Map<String, dynamic>;
      return data['success'] == true;

    } catch (e) {
      debugPrint('❌ Error in automatic payment: $e');
      throw e;
    }
  }

  /// Create Payment Intent using Firebase Cloud Function
  Future<String?> _createPaymentIntent({
    required String dealId,
    required String userId,
    required String purchaseId,
    required double amount,
    required String description,
    bool setupFutureUsage = false,
  }) async {
    try {
      debugPrint('🔵 Creating payment intent...');

      // Use the appropriate function based on whether we need to save the card
      final functionName = setupFutureUsage 
          ? 'createPaymentIntentWithSetup' 
          : 'createPaymentIntent';

      final callable = FirebaseFunctions.instance
          .httpsCallable(functionName);

      final params = {
        'dealId': dealId,
        'purchaseId': purchaseId,
        'amount': amount,
        'currency': 'cad', // Match your existing currency
      };

      // Add setupFutureUsage only if true
      if (setupFutureUsage) {
        params['setupFutureUsage'] = true;
      }

      final response = await callable.call(params);

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

  /// Create Payment Intent with saved payment method
  Future<String?> _createPaymentIntentWithSavedMethod({
    required String dealId,
    required String userId,
    required String purchaseId,
    required double amount,
    required String description,
    required String paymentMethodId,
  }) async {
    try {
      debugPrint('🔵 Creating payment intent with saved method...');

      final callable = FirebaseFunctions.instance
          .httpsCallable('createPaymentIntentWithSavedMethod');

      final response = await callable.call({
        'dealId': dealId,
        'purchaseId': purchaseId,
        'amount': amount,
        'currency': 'cad', // Match your existing currency
        'paymentMethodId': paymentMethodId,
      });

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
      debugPrint('❌ Error creating payment intent with saved method: $e');
      _setError('Network error: Unable to connect to payment server');
      return null;
    }
  }

  /// Save payment method after successful payment
  Future<void> _savePaymentMethodAfterPayment(String userId, String clientSecret) async {
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('savePaymentMethodAfterPayment');

      await callable.call({
        'userId': userId,
        'clientSecret': clientSecret,
      });

      // Reload saved payment methods
      await loadSavedPaymentMethods(userId);

    } catch (e) {
      debugPrint('❌ Error saving payment method: $e');
    }
  }

  /// Delete saved payment method
  Future<bool> deleteSavedPaymentMethod(String userId, String paymentMethodId) async {
    try {
      _setLoading(true);

      final callable = FirebaseFunctions.instance
          .httpsCallable('deleteSavedPaymentMethod');

      final response = await callable.call({
        'userId': userId,
        'paymentMethodId': paymentMethodId,
      });

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        // Remove from local list
        _savedPaymentMethods.removeWhere((pm) => pm.stripePaymentMethodId == paymentMethodId);
        notifyListeners();
        return true;
      }

      return false;

    } catch (e) {
      debugPrint('❌ Error deleting payment method: $e');
      _setError('Failed to delete payment method');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Set default payment method
  Future<bool> setDefaultPaymentMethod(String userId, String paymentMethodId) async {
    try {
      _setLoading(true);

      final callable = FirebaseFunctions.instance
          .httpsCallable('setDefaultPaymentMethod');

      final response = await callable.call({
        'userId': userId,
        'paymentMethodId': paymentMethodId,
      });

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        // Update local list - set all to non-default, then set selected as default
        for (int i = 0; i < _savedPaymentMethods.length; i++) {
          _savedPaymentMethods[i] = _savedPaymentMethods[i].copyWith(isDefault: false);
        }
        
        final index = _savedPaymentMethods.indexWhere(
          (pm) => pm.stripePaymentMethodId == paymentMethodId
        );
        
        if (index != -1) {
          _savedPaymentMethods[index] = _savedPaymentMethods[index].copyWith(isDefault: true);
        }
        
        notifyListeners();
        return true;
      }

      return false;

    } catch (e) {
      debugPrint('❌ Error setting default payment method: $e');
      _setError('Failed to set default payment method');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get user-friendly error message from StripeException
  String _getStripeErrorMessage(StripeException e) {
    final error = e.error;
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