import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pulse_flutter/mixins/distance_calculator_mixin.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/deal.dart';
import '../models/saved_payment_method.dart';
import '../services/analytics_service.dart';
import '../services/facebook_service.dart';
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
  double? _businessRating;
  int? _totalRatings;
  bool _loadingRating = true;
  bool _isDescriptionExpanded = false;
  @override
  void initState() {
    super.initState();
    initDistanceCalculation(widget.deal, autoRefresh: true);
     WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadSavedPaymentMethods();
  });
    _loadBusinessRating();
    // Track view when user opens deal details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.trackDealView(widget.deal.id);
    });
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
 Widget buildX(BuildContext context) {
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
                      _buildTextContentOld(context),
                      
                      const SizedBox(height: 16),
                      
                      // Price Section with Tax Breakdown
                      _buildPriceSectionWithTaxOld(context),
                      
                      const SizedBox(height: 20),
                      // Purchase Buttons Section
                      _buildPurchaseButtons(context),
                      
                      
                      // Add bottom padding for safe area
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                      // Add bottom padding to prevent content hiding under button
                      const SizedBox(height: 100), // ← Important!
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


  Widget _buildPriceSectionWithTaxOld(BuildContext context) {
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
                  'Expires: ${(DateTime.fromMillisecondsSinceEpoch( widget.deal.expirationTime))}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Remaining quantity
          /*Row(
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
          ),*/
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
        if(widget.deal.discountPercentage > 0) 
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
          
        // ✅ TOP-RIGHT: Image counter - with IgnorePointer below remaining quantity
        if (images.length > 1)
          Positioned(
            top: widget.deal.remainingQuantity <= 5 ? 50 : 12,
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
        
        //✅ TOP-RIGHT: Remaining quantity below image counter
        if (widget.deal.remainingQuantity <= 5 && widget.deal.remainingQuantity > 0)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Only ${widget.deal.remainingQuantity} left!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
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

        // Time remaining indicator (Bottom-right of image)
        if (_showTimeRemaining())
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getTimeRemainingText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]
              )
              )
            ),

         // Fixed Positioned widget for business info overlay
        // Subtle business info overlay - individual containers like distance
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Business name and rating - compact container
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 1, 109, 1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.yellowAccent.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.deal.businessName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Add rating if available
                      if (_businessRating != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...List.generate(5, (index) => Icon(
                              index < _businessRating!.round() 
                                ? Icons.star 
                                : Icons.star_border,
                              size: 12,
                              color: Colors.amber.shade400,
                            )),
                            const SizedBox(width: 4),
                            Text(
                              '${_businessRating!.toStringAsFixed(1)} ($_totalRatings)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Distance - keep as is but match styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                  
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.navigation, 
                      size: 14, 
                      color: Color.fromARGB(255, 7, 116, 226),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      distanceDisplayText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 7, 116, 226),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        ],
    ),
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
  


Widget _buildAddressLine(BuildContext context) {
  return Row(
    children: [
      // Location icon
      Icon(
        Icons.location_on_outlined, // or Icons.location_on for filled version
        size: 16,
        color: Colors.blue.shade600,
      ),
      const SizedBox(width: 4), // Space between icon and text
      
      // Business address with subtle styling
      Expanded( // Wrap in Expanded to prevent overflow
        child: InkWell(
          onTap: () => _showAddressOptions(),
          child: Text(
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
      ),
      
      const SizedBox(height: 12),
    ],
  );
}
Widget _buildTextContent(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Category badge with text (not just emoji)
      /*Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          /*children: [
            Text(widget.deal.categoryEmoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              widget.deal.category.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],*/
        ),
      ),*/
      
      const SizedBox(height: 12),
      
      // Deal title - make it the hero
      /*Text(
        widget.deal.title,
        style: const TextStyle(
          fontSize: 24, // Bigger!
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      
      const SizedBox(height: 12),*/
      
      // Business info + distance is on image overlay
      /*Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Business name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.deal.businessName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Add rating if available
                  if (_businessRating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) => Icon(
                          index < _businessRating!.round() 
                            ? Icons.star 
                            : Icons.star_border,
                          size: 14,
                          color: Colors.amber,
                        )),
                        const SizedBox(width: 6),
                        Text(
                          '${_businessRating!.toStringAsFixed(1)} ($_totalRatings)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Distance - make it prominent
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.navigation, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text(
                    distanceDisplayText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      */
      
      
      //const SizedBox(height: 12),
      
      // Deal title - make it the hero
      Text(
        widget.deal.title,
        style: const TextStyle(
          fontSize: 24, // Bigger!
          fontWeight: FontWeight.bold,
          height: 1.2,
          color: Colors.grey
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 12),
      // Description
      const SizedBox(height: 12),
      _buildExpandableDescription()
    ],
  );
}


  Widget _buildTextContentOld(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(1), // More breathing room
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title - 2 lines max
        
        const SizedBox(height: 5),
        
        // Business name with rating
        Row(
          children: [
            Expanded(
              child: Text(
                widget.deal.businessName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
           
       
            // ✅ ADD RATING HERE
            if (!_loadingRating && _businessRating != null && _totalRatings != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 14,
                ),
                const SizedBox(width: 2),
                Text(
                  _businessRating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  ' ($_totalRatings)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ] else if (_loadingRating) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey.shade400,
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 6),
          // Business address with subtle styling
        InkWell(
          onTap: () => _showAddressOptions(),
          child: Text(
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
        _buildExpandableDescription()
        
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
      unawaited(FacebookService.trackPurchase(amount: widget.deal.dealPrice, currency: "CAD"));
      
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
Future<void> _openDirections() async {
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
   if (await canLaunchUrl(Uri.parse(mapsUrl))) {
     await launchUrl(Uri.parse(mapsUrl));
   }
}

// Copy address to clipboard
void _copyAddress() {
  // You can implement with flutter/services package
  Clipboard.setData(ClipboardData(text: widget.deal.businessAddress));
  
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
    constraints: const BoxConstraints(
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

Widget _buildExpandableDescription() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.deal.description,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          maxLines: 2,
          textDirection: Directionality.of(context),
          
        );
        textPainter.layout(maxWidth: constraints.maxWidth);
        final isOverflowing = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.deal.description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              maxLines: _isDescriptionExpanded ? null : 2,
              overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            
            if (isOverflowing)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isDescriptionExpanded = !_isDescriptionExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _isDescriptionExpanded ? 'Show less' : 'Show more',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
Future<void> _loadBusinessRating() async {
  if (widget.deal.businessId.isEmpty) {
    setState(() => _loadingRating = false);
    return;
  }

  try {
    final businessDoc = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.deal.businessId)
        .get();

    if (businessDoc.exists) {
      final data = businessDoc.data();
      if (mounted) {
        setState(() {
          _businessRating = data?['averageRating'] != null
              ? (data!['averageRating'] as num).toDouble()
              : null;
          _totalRatings = data?['totalRatings'];
          _loadingRating = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _loadingRating = false);
      }
    }
  } catch (e) {
    print('Error loading business rating: $e');
    if (mounted) {
      setState(() => _loadingRating = false);
    }
  }
}

Widget _buildPriceSectionWithTax(BuildContext context) {
  final dealPrice = widget.deal.dealPrice;
  final originalPrice = widget.deal.originalPrice;
  final savings = originalPrice - dealPrice;
  final taxRate = _getTaxRate();
  final taxAmount = dealPrice * taxRate;
  final totalPrice = dealPrice + taxAmount;

  return Column(
    children: [
      // Main price display with original price strikethrough
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (savings > 0)
                Text(
                  '\$${originalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey.shade500,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${dealPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 26, // Make it huge!
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
          
          // Smaller Savings badge to match main price size
          if (savings > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Reduced padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600],
                ),
                borderRadius: BorderRadius.circular(16), // Slightly smaller radius
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3), // Fixed color from green to red
                    blurRadius: 6, // Reduced blur
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Important: shrink to content
                children: [
                  const Text(
                    'SAVE',
                    style: TextStyle(
                      fontSize: 8, // Reduced from 10
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '\$${savings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16, // Reduced from 24 to match proportionally
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${widget.deal.discountPercentage}%',
                    style: const TextStyle(
                      fontSize: 9, // Reduced from 11
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      
      const SizedBox(height: 5),
      
      // Simplified total with tax (expandable)
      ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        backgroundColor: Colors.grey.shade50,
        collapsedBackgroundColor: Colors.grey.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total (incl. tax)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '\$${totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _buildPriceRow('Deal Price', '\$${dealPrice.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _buildPriceRow('Tax (HST 13%)', '\$${taxAmount.toStringAsFixed(2)}', isSubtle: true),
                const Divider(height: 20),
                _buildPriceRow(
                  'Final Total', 
                  '\$${totalPrice.toStringAsFixed(2)}',
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}
Widget _buildPriceRow(String label, String value, {bool isSubtle = false, bool isBold = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: isSubtle ? Colors.grey.shade600 : Colors.black87,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          color: isSubtle ? Colors.grey.shade600 : Colors.black87,
        ),
      ),
    ],
  );
}

DateTime? _getExpirationDateTime() {
  
  return DateTime.fromMillisecondsSinceEpoch(
    widget.deal.expirationTime * 1000
  );
}

// Alternative cleaner version using the helper:
bool _showTimeRemaining() {
  final expirationDateTime = _getExpirationDateTime();
  if (expirationDateTime == null) return false;
  
  final now = DateTime.now();
  final timeLeft = widget.deal.expirationDate.difference(now);
  return timeLeft.inHours <= 24 && timeLeft.inHours > 0;
}

String _getTimeRemainingText() {

  final now = DateTime.now();
  final timeLeft = widget.deal.expirationDate.difference(now);
  
  if (timeLeft.inHours > 0) {
    return '${timeLeft.inHours}h left';
  } else if (timeLeft.inMinutes > 0) {
    return '${timeLeft.inMinutes}m left';
  } else if (timeLeft.inSeconds > 0) {
    return 'Ending soon';
  } else {
    return 'Expired';
  }
}

@override
Widget build(BuildContext context) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        
        // SCROLLABLE CONTENT
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image carousel
                if (widget.deal.imageUrl != null && widget.deal.imageUrl!.isNotEmpty)
                  _buildHeroImage(context),
                
                // Content with padding
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAddressLine(context),
                      const Divider(),
                      const SizedBox(height: 3),
                      _buildPriceSectionWithTax(context),
                      const SizedBox(height: 16),
                      _buildTextContent(context),
                      const SizedBox(height: 16),
                      _buildDealInfo(context),
                      
                      // Add bottom padding to prevent content hiding under button
                      const SizedBox(height: 100), // ← Important!
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // STICKY BOTTOM CTA
        _buildStickyBottomCTA(context),
      ],
    ),
  );
}

Widget _buildStickyBottomCTA(BuildContext context) {
  final dealPrice = widget.deal.dealPrice;
  final taxAmount = dealPrice * _getTaxRate();
  final totalPrice = dealPrice + taxAmount;
  final isDisabled = widget.deal.isSoldOut || widget.deal.isExpired;

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, -3),
        ),
      ],
    ),
    child: SafeArea(
      top: false, // Only apply safe area to bottom
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingCards)
              const Center(child: CircularProgressIndicator())
            else if (isDisabled)
              _buildDisabledButton()
            else if (_hasSavedCards && _defaultCard != null)
              _build1TapButton(totalPrice)
            else
              _buildRegularButton(totalPrice),
          ],
        ),
      ),
    ),
  );
}

Widget _build1TapButton(double totalPrice) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      
      
      
      // 1-Tap Button
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isProcessing1Tap ? null : () => _handle1TapPurchase(totalPrice),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: _isProcessing1Tap ? 0 : 4,
            shadowColor: Colors.green.withOpacity(0.4),
          ),
          child: _isProcessing1Tap
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
                    Text(
                      'Processing...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flash_on, size: 22),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '1-Tap Buy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
      
      const SizedBox(height: 10),
      // Payment method preview (compact)
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  _defaultCard!.cardBrandIcon,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                TextButton(
                    onPressed: widget.onPurchase,
                    style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                    child: Text(
                  '•••• ${_defaultCard!.cardLast4}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                  ),
                
              ],
            ),
          ),
        ],
      ),
      

      /*const SizedBox(height: 8),
      
      // Alternative payment link (compact)
      TextButton(
        onPressed: widget.onPurchase,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        child: Text(
          'Use different payment',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),*/
    ],
  );
}

Widget _buildRegularButton(double totalPrice) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      onPressed: widget.onPurchase,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart, size: 20),
          const SizedBox(width: 12),
          Text(
            'Buy Now • \$${totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDisabledButton() {
  return Container(
    width: double.infinity,
    height: 56,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Center(
      child: Text(
        widget.deal.isSoldOut ? 'Sold Out' : 'Expired',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
      ),
    ),
  );
}
}

