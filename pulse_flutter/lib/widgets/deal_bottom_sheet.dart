import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/deal.dart';
import '../models/saved_payment_method.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import '../screens/voucher_detail_screen.dart';
import 'custom_button.dart';

class DealBottomSheet extends StatefulWidget {
  final Deal deal;
  final VoidCallback onPurchase;

  const DealBottomSheet({
    super.key,
    required this.deal,
    required this.onPurchase,
  });

  @override
  State<DealBottomSheet> createState() => _DealBottomSheetState();
}

class _DealBottomSheetState extends State<DealBottomSheet> {
  bool _isProcessing1Tap = false;
  SavedPaymentMethod? _defaultCard;
  bool _hasSavedCards = false;
  bool _isLoadingCards = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPaymentMethods();
  }

  Future<void> _loadSavedPaymentMethods() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final paymentService = Provider.of<PaymentService>(context, listen: false);
    
    if (authService.currentUser != null) {
      setState(() {
        _isLoadingCards = true;
      });

      try {
        await paymentService.loadSavedPaymentMethods(authService.currentUser!.uid);
        
        if (mounted) {
          setState(() {
            _hasSavedCards = paymentService.savedPaymentMethods.isNotEmpty;
            _defaultCard = paymentService.savedPaymentMethods
                .where((card) => card.isDefault && !card.isExpired)
                .firstOrNull;
            _isLoadingCards = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingCards = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Deal Image
                  if (widget.deal.imageUrl != null && widget.deal.imageUrl!.isNotEmpty)
                    _buildDealImage(),
                  
                  const SizedBox(height: 16),
                  
                  // Deal Title and Business
                  Text(
                    widget.deal.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Text(
                        widget.deal.categoryEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.deal.businessName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    widget.deal.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Price Section with Tax Breakdown
                  _buildPriceSectionWithTax(context),
                  
                  const SizedBox(height: 20),
                  
                  // Deal Info
                  _buildDealInfo(context),
                  
                  const SizedBox(height: 24),
                  
                  // Purchase Buttons Section
                  _buildPurchaseButtons(context),
                  
                  // Add bottom padding for safe area
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDealImage() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 300,
          minHeight: 150,
        ),
        child: Container(
          width: double.infinity,
          child: CachedNetworkImage(
            imageUrl: widget.deal.imageUrl!,
            fit: BoxFit.contain, // Shows full image without cropping
            placeholder: (context, url) => Container(
              height: 200,
              color: Colors.grey.shade200,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: Colors.grey.shade200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Image not available',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSectionWithTax(BuildContext context) {
    final dealPrice = widget.deal.dealPrice;
    final originalPrice = widget.deal.originalPrice;
    final savings = originalPrice - dealPrice;
    final taxRate = _getTaxRate();
    final taxAmount = dealPrice * taxRate;
    final totalPrice = dealPrice + taxAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Savings banner (if applicable)
        if (savings > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.savings, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You save \$${savings.toStringAsFixed(2)} (${widget.deal.discountPercentage}% off)!',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Simple total price display
        _buildExpandablePriceBreakdown(
          dealPrice: dealPrice,
          originalPrice: originalPrice,
          savings: savings,
          taxAmount: taxAmount,
          totalPrice: totalPrice,
        ),
      ],
    );
  }

  Widget _buildExpandablePriceBreakdown({
    required double dealPrice,
    required double originalPrice,
    required double savings,
    required double taxAmount,
    required double totalPrice,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            '\$${totalPrice.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
      subtitle: Text(
        'Tap for price breakdown',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Original price (if there's a discount)
              if (savings > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Original Price',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '\$${originalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
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
                  Text(
                    '\$${dealPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Tax
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tax (HST)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '\$${taxAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              
              // Discount (if applicable)
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
              
              const Divider(height: 20),
              
              // Total (repeated in breakdown for clarity)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '\$${totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDealInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Expiration
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Expires: ${_formatExpirationDate()}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Remaining quantity
          Row(
            children: [
              Icon(Icons.inventory, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.deal.remainingQuantity} remaining',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButtons(BuildContext context) {
    final dealPrice = widget.deal.dealPrice;
    final taxAmount = dealPrice * _getTaxRate();
    final totalPrice = dealPrice + taxAmount;
    final isDisabled = widget.deal.isSoldOut || widget.deal.isExpired;

    if (isDisabled) {
      return Column(
        children: [
          CustomButton(
            text: widget.deal.isSoldOut ? 'Sold Out' : 'Expired',
            onPressed: null,
            backgroundColor: Colors.grey,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              widget.deal.isSoldOut 
                  ? 'This deal is currently sold out'
                  : 'This deal has expired',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    if (_isLoadingCards) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasSavedCards && _defaultCard != null) {
      // Show 1-tap option for users with saved cards
      return Column(
        children: [
          // 1-Tap Purchase Button (Primary)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isProcessing1Tap ? null : () => _handle1TapPurchase(totalPrice),
              icon: _isProcessing1Tap 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.flash_on, size: 20),
              label: Text(
                _isProcessing1Tap 
                    ? 'Processing...' 
                    : '1-Tap Buy \$${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Payment method preview
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_defaultCard!.cardBrandIcon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Paying with ${_defaultCard!.cardBrand.toUpperCase()} •••• ${_defaultCard!.cardLast4}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Alternative: Review order button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onPurchase,
              child: const Text('Review Order'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Show regular purchase button for users without saved cards
      return CustomButton(
        text: 'Buy Now \$${totalPrice.toStringAsFixed(2)}',
        onPressed: widget.onPurchase,
        backgroundColor: Theme.of(context).primaryColor,
      );
    }
  }

  Future<void> _handle1TapPurchase(double totalPrice) async {
    if (_defaultCard == null || _isProcessing1Tap) return;

    setState(() {
      _isProcessing1Tap = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final paymentService = Provider.of<PaymentService>(context, listen: false);
      final purchaseService = Provider.of<PurchaseService>(context, listen: false);

      // Step 1: Create purchase record
      debugPrint('📝 Creating purchase record for 1-tap...');
      final purchaseId = await purchaseService.createPurchase(
        userId: authService.currentUser!.uid,
        deal: widget.deal,
      );

      if (purchaseId == null) {
        throw Exception('Failed to create purchase record');
      }

      // Step 2: Process payment with saved method
      debugPrint('💳 Processing 1-tap payment...');
      final paymentSuccess = await paymentService.processPayment(
        deal: widget.deal,
        userId: authService.currentUser!.uid,
        purchaseId: purchaseId,
        savedPaymentMethodId: _defaultCard!.stripePaymentMethodId,
      );

      if (!paymentSuccess) {
        throw Exception(paymentService.errorMessage ?? 'Payment failed');
      }

      // Step 3: Confirm payment and generate QR code
      debugPrint('🔄 Confirming 1-tap payment...');
      final purchase = await purchaseService.confirmPayment(
        purchaseId: purchaseId,
        userId: authService.currentUser!.uid,
      );

      if (purchase == null) {
        throw Exception('Failed to confirm payment');
      }

      // Step 4: Close bottom sheet and navigate to voucher screen
      if (mounted) {
        Navigator.of(context).pop(); // Close bottom sheet
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VoucherDetailScreen(purchase: purchase),
          ),
        );
      }

    } catch (e) {
      debugPrint('❌ Error in 1-tap purchase: $e');
      if (mounted) {
        _showErrorDialog('1-Tap purchase failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing1Tap = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Error'),
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

  String _formatExpirationDate() {
    final date = DateTime.fromMillisecondsSinceEpoch(widget.deal.expirationTime);
    return DateFormat('MMM d, yyyy').format(date);
  }

  double _getTaxRate() {
    // You can implement province-specific tax rates here
    // For now, using Ontario HST as default
    return 0.13; // 13% HST for Ontario
  }
}