import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pulse_flutter/mixins/distance_calculator_mixin.dart';

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

class _DealBottomSheetState extends State<DealBottomSheet> with DistanceCalculatorMixin{
  bool _isProcessing1Tap = false;
  SavedPaymentMethod? _defaultCard;
  bool _hasSavedCards = false;
  bool _isLoadingCards = false;
  int _currentImageIndex = 0;
  @override
  void initState() {
    super.initState();
    initDistanceCalculation(widget.deal, autoRefresh: true);
    _loadSavedPaymentMethods();
  }

@override
  void dispose() {
    // Clean up distance calculation resources
    disposeDistanceCalculation();
    super.dispose();
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
        
        // ✅ KEY CHANGE: Image carousel at the TOP, outside scroll view
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Image carousel WITHOUT padding
                if (widget.deal.imageUrl != null && widget.deal.imageUrl!.isNotEmpty)
                  _buildHeroImage(context),
                
                // ✅ Rest of content WITH padding
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextContent(context),
                      
                      const SizedBox(height: 16),
                      
                      // Price Section with Tax Breakdown
                      _buildPriceSectionWithTax(context),
                      
                      const SizedBox(height: 20),
                      
                      // Purchase Buttons Section
                      _buildPurchaseButtons(context),
                      
                      // Add bottom padding for safe area
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
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
          const Text(
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
                  const Text(
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
                  'Expires: ${(widget.deal.expirationTime)}',
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
// ============================================
// FINAL WORKING VERSION - Replace your _buildHeroImage() with this
// ============================================

Widget _buildHeroImage(BuildContext context) {
  final images = widget.deal.imageUrls.isNotEmpty 
    ? widget.deal.imageUrls 
    : (widget.deal.imageUrl != null ? [widget.deal.imageUrl!] : []);
  
  if (images.isEmpty) {
    return _buildCategoryPlaceholder();
  }
  
  final imageHeight = MediaQuery.of(context).size.width * (3 / 2); // 2:3 aspect ratio
  
  return AspectRatio(
    aspectRatio: 2/3,
    child: Stack(
      children: [
        // ✅ PageView - The main scrollable content
        Positioned.fill(
          child: PageView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: images.length,
            onPageChanged: (index) {
              print('📸 Swiped to image ${index + 1}/${images.length}');
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => _buildCategoryPlaceholder(),
              );
            },
          ),
        ),
        
        // ✅ Gradient overlay - with IgnorePointer so it doesn't block swipes!
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ),
        ),
        
        // ✅ TOP-LEFT: Discount badge - with IgnorePointer
        Positioned(
          top: 12,
          left: 12,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${widget.deal.discountPercentage}% OFF',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        
        // ✅ TOP-RIGHT: Image counter - with IgnorePointer
        if (images.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        
        // ✅ BOTTOM-CENTER: Dot indicators - with IgnorePointer
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white54,
                      boxShadow: _currentImageIndex == index
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}


 Widget _buildHeroImageOld(BuildContext context) {
  final images = widget.deal.imageUrls.isNotEmpty 
    ? widget.deal.imageUrls 
    : (widget.deal.imageUrl != null ? [widget.deal.imageUrl!] : []);
  
  if (images.isEmpty) {
    return _buildCategoryPlaceholder();
  }
  
  final screenWidth = MediaQuery.of(context).size.width;
  final imageHeight = screenWidth * 0.8; // ✅ 80% of screen width (not 2:3 ratio)
  
  return Stack(
    children: [
      SizedBox(
        height: imageHeight,
        width: screenWidth,
        child: PageView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: images.length,
          onPageChanged: (index) {
            print('📸 Swiped to image ${index + 1}/${images.length}');
            setState(() => _currentImageIndex = index);
          },
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => _buildCategoryPlaceholder(),
            );
          },
        ),
      ),
      
      // Gradient overlay
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
              stops: [0.6, 1.0],
            ),
          ),
        ),
      ),
      
      // Discount badge
      Positioned(
        top: 12,
        left: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '${widget.deal.discountPercentage}% OFF',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
      
      // Image counter
      if (images.length > 1)
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentImageIndex + 1}/${images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      
      // Dot indicators
      if (images.length > 1)
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentImageIndex == index
                    ? Colors.white
                    : Colors.white54,
                  boxShadow: _currentImageIndex == index
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

  Widget _buildCategoryPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.deal.categoryEmoji,
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 8),
          Text(
            widget.deal.categoryDisplayName,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16), // More breathing room
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title - 2 lines max
           
          
          
          const SizedBox(height: 6),
          // Business name with subtle styling
          Text(
            widget.deal.businessName,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),
           InkWell(
          onTap: () => _showAddressOptions(),
          child: 
          // Business address with subtle styling
          Text(
            widget.deal.businessAddress,
            style: TextStyle(
              color: Colors.blue.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
           ),
          /*const SizedBox(height: 6),
          buildDistanceWidget(
            widget.deal,
            onRefresh: () => refreshDistance(widget.deal),
          ),*/
          // Price row - PROMINENT
          Row(
            children: [
              // Original price - crossed out
              Text(
                '\$${widget.deal.originalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  decoration: TextDecoration.lineThrough,
                  decorationThickness: 2,
                ),
              ),
              const SizedBox(width: 8),
              // New price - BIG
              Text(
                '\$${widget.deal.dealPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24, // Much bigger
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              
             
              const Spacer(),
            
             
            ],
          ),
          const SizedBox(height: 6),
          Row(
            
             children: [
          // Business name with subtle styling
          Expanded(
          child : Text(
            widget.deal.description,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          )
             ]
          )
        ],
      ),
    );
  }

  // Helper: Category-based placeholder when no image
  Widget _buildCategoryPlaceholderOld() {
    final categoryImages = {
      'Restaurant': '🍽️',
      'Cafe': '☕',
      'Bar': '🍺',
      'Shop': '🛍️',
    };
    
    return Center(
      child: Text(
        categoryImages[widget.deal.category] ?? '🎉',
        style: const TextStyle(fontSize: 64),
      ),
    );
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

  

  double _getTaxRate() {
    // You can implement province-specific tax rates here
    // For now, using Ontario HST as default
    return 0.13; // 13% HST for Ontario
  }

  void _showAddressOptions() {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.deal.businessName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.deal.businessAddress,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openDirections();
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _copyAddress();
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

// Open directions in maps
void _openDirections() {
  // You can implement with url_launcher package
  final encodedAddress = Uri.encodeComponent(widget.deal.businessAddress);
  final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
  
  // For now, show a snackbar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Opening directions to ${widget.deal.businessName}'),
      duration: const Duration(seconds: 2),
    ),
  );
  
  // With url_launcher, you would do:
  // if (await canLaunchUrl(Uri.parse(mapsUrl))) {
  //   await launchUrl(Uri.parse(mapsUrl));
  // }
}

// Copy address to clipboard
void _copyAddress() {
  // You can implement with flutter/services package
  // Clipboard.setData(ClipboardData(text: widget.deal.businessAddress));
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Address copied to clipboard'),
      duration: Duration(seconds: 2),
    ),
  );
}

/// Get remaining time in hours
double _getRemainingHours() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final remainingMillis = widget.deal.expirationTime - now;
  
  if (remainingMillis <= 0) {
    return 0.0; // Expired
  }
  
  return remainingMillis / (1000 * 60 * 60); // Convert to hours
}

/// Get formatted time remaining string
String _getFormattedTimeRemaining() {
  final remainingHours = _getRemainingHours();
  
  if (remainingHours <= 0) {
    return 'Expired';
  } else if (remainingHours < 1) {
    final minutes = (remainingHours * 60).round();
    return '${minutes}m left';
  } else if (remainingHours < 24) {
    return '${remainingHours.toStringAsFixed(1)}h left';
  } else {
    final days = (remainingHours / 24).floor();
    final hours = (remainingHours % 24).round();
    if (hours == 0) {
      return '${days}d left';
    } else {
      return '${days}d ${hours}h left';
    }
  }
}

Widget _buildTitleSection(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.deal.title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 6),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // ✅ Distance badge
          buildDistanceWidget(widget.deal),
        ],
      ),
    ],
  );
}

Widget _buildDescriptionSection(BuildContext context) {
  return Container(
    constraints: BoxConstraints(
      maxHeight: 60, // ✅ Limit description height
    ),
    child: Text(
      widget.deal.description,
      style: Theme.of(context).textTheme.bodyMedium,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget _buildPriceSection(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        // Price row
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.deal.originalPrice != widget.deal.dealPrice) ...[
                  Text(
                    '\$${widget.deal.originalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  '\$${widget.deal.dealPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (widget.deal.discountPercentage > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.deal.discountPercentage}% OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Deal info row
        Row(
          children: [
            Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              _getFormattedTimeRemaining(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Icon(Icons.inventory, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              '${widget.deal.remainingQuantity} left',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


}

