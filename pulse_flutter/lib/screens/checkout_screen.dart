import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deal.dart';
import '../models/saved_payment_method.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import '../screens/voucher_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Deal deal;

  const CheckoutScreen({
    super.key,
    required this.deal,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _saveCard = true; // Changed from false to true - default selected
  SavedPaymentMethod? _selectedPaymentMethod;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPaymentMethods();
  }

  Future<void> _loadSavedPaymentMethods() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final paymentService = Provider.of<PaymentService>(context, listen: false);
    
    if (authService.currentUser != null) {
      await paymentService.loadSavedPaymentMethods(authService.currentUser!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<PaymentService>(
        builder: (context, paymentService, child) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDealSummary(),
                      const SizedBox(height: 24),
                      _buildPaymentMethodSelection(paymentService),
                      const SizedBox(height: 24),
                      _buildOrderSummary(),
                    ],
                  ),
                ),
              ),
              _buildBottomSection(paymentService),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDealSummary() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.deal.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.deal.businessName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Regular Price',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '\$${widget.deal.originalPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Deal Price',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '\$${widget.deal.dealPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelection(PaymentService paymentService) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Method',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Saved payment methods
            if (paymentService.savedPaymentMethods.isNotEmpty) ...[
              Text(
                'Saved Cards',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              ...paymentService.savedPaymentMethods.map((paymentMethod) {
                return _buildSavedPaymentMethodTile(paymentMethod);
              }),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            
            // New payment method option
            _buildNewPaymentMethodTile(),
            
            // Save card checkbox (only show for new payment)
            if (_selectedPaymentMethod == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _saveCard ? Colors.green.shade50 : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _saveCard ? Colors.green.shade200 : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: CheckboxListTile(
                  title: const Text(
                    'Save this card for future purchases',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.flash_on,
                            size: 16,
                            color: _saveCard ? Colors.green.shade600 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Enable 1-tap checkout for faster payments',
                              style: TextStyle(
                                color: _saveCard ? Colors.green.shade700 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  value: _saveCard,
                  onChanged: (value) {
                    setState(() {
                      _saveCard = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPaymentMethodTile(SavedPaymentMethod paymentMethod) {
    final isSelected = _selectedPaymentMethod?.id == paymentMethod.id;
    final isExpired = paymentMethod.isExpired;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: isExpired ? null : () {
          setState(() {
            _selectedPaymentMethod = isSelected ? null : paymentMethod;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected 
                  ? Theme.of(context).primaryColor 
                  : (isExpired ? Colors.red.shade300 : Colors.grey.shade300),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isExpired 
                ? Colors.red.shade50 
                : (isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null),
          ),
          child: Row(
            children: [
              Text(
                paymentMethod.cardBrandIcon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paymentMethod.displayText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isExpired ? Colors.red.shade700 : null,
                      ),
                    ),
                    Text(
                      isExpired 
                          ? 'Expired ${paymentMethod.cardExpMonth}/${paymentMethod.cardExpYear}'
                          : 'Expires ${paymentMethod.cardExpMonth}/${paymentMethod.cardExpYear}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isExpired ? Colors.red.shade600 : Colors.grey[600],
                      ),
                    ),
                    if (paymentMethod.isDefault)
                      Text(
                        'Default',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected && !isExpired)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                ),
              if (!isExpired)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteSavedPaymentMethod(paymentMethod);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Card'),
                    ),
                  ],
                  child: const Icon(Icons.more_vert),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewPaymentMethodTile() {
    final isSelected = _selectedPaymentMethod == null;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = null;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            const Icon(Icons.add_card, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use New Card',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Credit/Debit Card, Google Pay, Apple Pay',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final dealPrice = widget.deal.dealPrice;
    final originalPrice = widget.deal.originalPrice;
    final savings = originalPrice - dealPrice;
    final taxRate = _getTaxRate();
    final taxAmount = dealPrice * taxRate;
    final totalPrice = dealPrice + taxAmount;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary TEST',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Original price (if there's a discount)
            if (savings > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Original Price'),
                  Text(
                    '\$${originalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // Deal price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Deal Price'),
                Text('\$${dealPrice.toStringAsFixed(2)}'),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Tax
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tax (HST)', style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                )),
                Text(
                  '\$${taxAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            
            // Discount amount (if applicable)
            if (savings > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount'),
                  Text(
                    '-\$${savings.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green.shade600),
                  ),
                ],
              ),
            ],
            
            const Divider(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${totalPrice.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.savings, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      savings > 0 
                          ? 'You save \$${savings.toStringAsFixed(2)} with this deal!'
                          : 'Great deal price!',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(PaymentService paymentService) {
    final dealPrice = widget.deal.dealPrice;
    final taxAmount = dealPrice * _getTaxRate();
    final totalPrice = dealPrice + taxAmount;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show error if failed to load saved payment methods
            if (paymentService.errorMessage != null && 
                paymentService.errorMessage!.contains('Failed to load saved payment methods'))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade600),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Failed to load saved payment methods',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

            // Show other payment errors
            if (paymentService.errorMessage != null && 
                !paymentService.errorMessage!.contains('Failed to load saved payment methods'))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        paymentService.errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isProcessing || paymentService.isLoading) 
                    ? null 
                    : _handlePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: (_isProcessing || paymentService.isLoading)
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Processing...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_selectedPaymentMethod != null)
                            const Icon(Icons.flash_on, size: 20),
                          Text(
                            _selectedPaymentMethod != null
                                ? '1-Tap Pay \$${totalPrice.toStringAsFixed(2)}'
                                : 'Pay \$${totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              _selectedPaymentMethod != null
                  ? 'Payment will be processed using your saved ${_selectedPaymentMethod!.cardBrand.toUpperCase()} ending in ${_selectedPaymentMethod!.cardLast4}'
                  : 'Secure payment powered by Stripe',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final paymentService = Provider.of<PaymentService>(context, listen: false);
      final purchaseService = Provider.of<PurchaseService>(context, listen: false);

      // Step 1: Create purchase record
      debugPrint('📝 Creating purchase record...');
      final purchaseId = await purchaseService.createPurchase(
        userId: authService.currentUser!.uid,
        deal: widget.deal,
      );

      if (purchaseId == null) {
        throw Exception('Failed to create purchase record');
      }

      debugPrint('✅ Purchase record created: $purchaseId');

      // Step 2: Process payment (with or without saved method)
      debugPrint('💳 Processing payment...');
      final paymentSuccess = await paymentService.processPayment(
        deal: widget.deal,
        userId: authService.currentUser!.uid,
        purchaseId: purchaseId,
        saveCard: _saveCard,
        savedPaymentMethodId: _selectedPaymentMethod?.stripePaymentMethodId,
      );

      if (!paymentSuccess) {
        debugPrint('❌ Payment failed');
        if (mounted) {
          final errorMsg = paymentService.errorMessage;
          if (errorMsg != null && !errorMsg.contains('cancel')) {
            _showErrorDialog(errorMsg);
          }
        }
        return;
      }

      debugPrint('✅ Payment successful');

      // Step 3: Confirm payment and generate QR code
      debugPrint('🔄 Confirming payment and generating QR code...');
      final purchase = await purchaseService.confirmPayment(
        purchaseId: purchaseId,
        userId: authService.currentUser!.uid,
      );

      if (purchase == null) {
        throw Exception('Failed to confirm payment');
      }

      debugPrint('✅ Payment confirmed with QR code');

      // Step 4: Navigate to voucher screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VoucherDetailScreen(purchase: purchase),
          ),
        );
      }

    } catch (e) {
      debugPrint('❌ Error in purchase flow: $e');
      if (mounted) {
        _showErrorDialog('An unexpected error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _deleteSavedPaymentMethod(SavedPaymentMethod paymentMethod) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: Text('Are you sure you want to delete ${paymentMethod.displayText}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final paymentService = Provider.of<PaymentService>(context, listen: false);

      final success = await paymentService.deleteSavedPaymentMethod(
        authService.currentUser!.uid,
        paymentMethod.stripePaymentMethodId,
      );

      if (success && mounted) {
        // If deleted payment method was selected, clear selection
        if (_selectedPaymentMethod?.id == paymentMethod.id) {
          setState(() {
            _selectedPaymentMethod = null;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${paymentMethod.displayText} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
double _getTaxRate() {
    // You can implement province-specific tax rates here
    // For now, using Ontario HST as default
    return 0.13; // 13% HST for Ontario
  }