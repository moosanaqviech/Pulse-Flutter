// pulse_flutter/lib/widgets/deal_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/deal.dart';
import '../providers/favorites_provider.dart';

class DealCard extends StatelessWidget {
  final Deal deal;
  final VoidCallback? onTap;
  final bool showFavoriteButton;
  final bool compact;

  const DealCard({
    super.key,
    required this.deal,
    this.onTap,
    this.showFavoriteButton = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactCard(context);
    } else {
      return _buildFullCard(context);
    }
  }

  Widget _buildFullCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(  // Using the same pattern as deal_bottom_sheet.dart
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(context),
            _buildContentSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(  // Using the same pattern as other working widgets
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildCompactImage(),
              const SizedBox(width: 12),
              Expanded(child: _buildCompactContent(context)),
              if (showFavoriteButton) _buildFavoriteButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: deal.imageUrl != null && deal.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: deal.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildImagePlaceholder(),
                    errorWidget: (context, url, error) => _buildImagePlaceholder(),
                  )
                : _buildImagePlaceholder(),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: _buildDiscountBadge(),
        ),
        if (showFavoriteButton)
          Positioned(
            top: 8,
            right: 8,
            child: _buildFavoriteButton(context), // Removed Material wrapper
          ),
        if (deal.remainingQuantity <= 5)
          Positioned(
            bottom: 8,
            left: 8,
            child: _buildLimitedBadge(),
          ),
      ],
    );
  }

  Widget _buildContentSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deal.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            deal.businessName,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_calculateDistance().toStringAsFixed(1)} km away',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
              _buildPriceSection(),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatusRow(),
        ],
      ),
    );
  }

  Widget _buildCompactImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 60,
        height: 60,
        child: deal.imageUrl != null && deal.imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: deal.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildImagePlaceholder(),
                errorWidget: (context, url, error) => _buildImagePlaceholder(),
              )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          deal.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          deal.businessName,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildDiscountBadge(compact: true),
            const SizedBox(width: 8),
            Expanded(child: _buildPriceSection(compact: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildDiscountBadge({bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
      ),
      child: Text(
        '${deal.discountPercentage}% OFF',
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLimitedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Only ${deal.remainingQuantity} left',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        final isFavorite = favoritesProvider.isFavorite(deal.id!);
        
        return GestureDetector(
          onTap: () async {
            // Stop event propagation
            await favoritesProvider.toggleFavorite(deal);
            
            if (!context.mounted) return;
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isFavorite 
                      ? '${deal.title} removed from favorites'
                      : '${deal.title} added to favorites',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          // Add this to prevent the tap from bubbling up to parent
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.all(4), // Add margin to prevent accidental taps
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              // Add a subtle border to make it more obvious
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.grey.shade600,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriceSection({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (deal.originalPrice > deal.dealPrice && !compact)
          Text(
            '\$${deal.originalPrice.toStringAsFixed(2)}',
            style: TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        Text(
          '\$${deal.dealPrice.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: compact ? 14 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 14,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Text(
          _getTimeRemaining(),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        if (deal.totalQuantity -deal.remainingQuantity > 0) ...[
          Icon(
            Icons.people,
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            '${deal.totalQuantity -deal.remainingQuantity} claimed',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  double _calculateDistance() {
    // TODO: Implement actual distance calculation using user's location
    // For now, return a mock distance
    return 2.5;
  }

  String _getTimeRemaining() {
    final now = DateTime.now();
    final expirationDate = DateTime.fromMillisecondsSinceEpoch(deal.expirationTime);
    final difference = expirationDate.difference(now);
    
    if (difference.isNegative) {
      return 'Expired';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m left';
    } else {
      return 'Expires soon';
    }
  }
}