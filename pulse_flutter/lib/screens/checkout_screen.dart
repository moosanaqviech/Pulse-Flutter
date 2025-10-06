import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deal.dart';
import '../services/payment_service.dart';
import '../services/purchase_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import 'voucher_detail_screen.dart';

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
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deal Summary Card
            _buildDealSummary(),
            
            const SizedBox(height: 24),
            
            // Payment Method Info Card
            _buildPaymentMethodInfo(),
            
            const SizedBox(height: 16),
            
            // Security Notice
            _buildSecurityNotice(),
            
            const SizedBox(height: 24),
            
            // Purchase Button
            _buildPurchaseButton(),
            
            const SizedBox(height: 16),
            
            // Terms and conditions
            _buildTerms(),
          ],
        ),
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
              'Order Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Deal image if available
            if (widget.deal.imageUrl != null && widget.deal.imageUrl!.isNotEmpty)
              Container(
                height: 120,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(widget.deal.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            
            Text(
              widget.deal.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              widget.deal.businessName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Deal Price:'),
                Text(
                  '\$${widget.deal.dealPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            
            if (widget.deal.originalPrice > widget.deal.dealPrice) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Original Price:',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  Text(
                    '\$${widget.deal.originalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'You Save:',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '\$${(widget.deal.originalPrice - widget.deal.dealPrice).toStringAsFixed(2)} (${widget.deal.discountPercentage}%)',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildPaymentMethodInfo() {
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
            
            const Row(
              children: [
                Icon(Icons.credit_card, color: Colors.blue),
                SizedBox(width: 12),
                Text('Credit / Debit Card'),
              ],
            ),
            
            const SizedBox(height: 12),
            
            const Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.green),
                SizedBox(width: 12),
                Text('Google Pay / Apple Pay'),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'You will be able to choose your payment method in the next step.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your payment information is encrypted and processed securely by Stripe',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton() {
    return Consumer2<PaymentService, AuthService>(
      builder: (context, paymentService, authService, _) {
        final isLoading = _isProcessing || paymentService.isLoading;
        final isDisabled = widget.deal.isSoldOut || widget.deal.isExpired;
        
        return Column(
          children: [
            CustomButton(
              text: isDisabled 
                  ? (widget.deal.isSoldOut ? 'Sold Out' : 'Expired')
                  : 'Continue to Payment',
              onPressed: (!isLoading && !isDisabled) ? _processPurchase : null,
              isLoading: isLoading,
              backgroundColor: isDisabled ? Colors.grey : null,
            ),
            
            if (isDisabled) ...[
              const SizedBox(height: 12),
              Text(
                widget.deal.isSoldOut 
                    ? 'This deal is currently sold out'
                    : 'This deal has expired',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTerms() {
    return Column(
      children: [
        const Text(
          'By completing this purchase, you agree to our Terms of Service and understand that:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '• Deals are non-refundable\n'
          '• Voucher expires on the date specified\n'
          '• One voucher per transaction\n'
          '• Cannot be combined with other offers',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Future<void> _processPurchase() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final paymentService = Provider.of<PaymentService>(context, listen: false);
    final purchaseService = Provider.of<PurchaseService>(context, listen: false);
    
    if (authService.currentUser == null) {
      _showErrorDialog('Please sign in to complete your purchase');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
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

      // Step 2: Process Stripe payment
      debugPrint('💳 Processing Stripe payment...');
      final paymentSuccess = await paymentService.processPayment(
        deal: widget.deal,
        userId: authService.currentUser!.uid,
        purchaseId: purchaseId,
      );

      if (!paymentSuccess) {
        debugPrint('❌ Stripe payment failed');
        if (mounted) {
          final errorMsg = paymentService.errorMessage;
          if (errorMsg != null && !errorMsg.contains('cancel')) {
            _showErrorDialog(errorMsg);
          }
        }
        return;
      }

      debugPrint('✅ Stripe payment successful');

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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Payment Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your card has not been charged',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}