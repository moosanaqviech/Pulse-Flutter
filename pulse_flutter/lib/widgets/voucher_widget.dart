// voucher_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../models/purchase.dart';

class VoucherWidget extends StatelessWidget {
  final Purchase voucher;
  final VoidCallback? onTap;
  final bool showQRCode;
  final double? width;
  final double? height;

  const VoucherWidget({
    super.key,
    required this.voucher,
    this.onTap,
    this.showQRCode = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height ?? 280,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main voucher card
            _buildMainCard(context),
            
            // Status badge
            if (voucher.isRedeemed || voucher.isExpired)
              _buildStatusBadge(context),
            
            // Perforated edge
            _buildPerforatedEdge(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        border: Border.all(
          color: _getBorderColor(),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Top section with image and basic info
          _buildTopSection(context),
          
          // Dotted divider
          _buildDottedDivider(),
          
          // Bottom section with QR code or details
          _buildBottomSection(context),
        ],
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Deal image
            _buildDealImage(),
            
            const SizedBox(width: 16),
            
            // Deal info
            Expanded(
              child: _buildDealInfo(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade200,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: voucher.imageUrl != null && voucher.imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: voucher.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.local_offer, color: Colors.grey),
                ),
              )
            : const Icon(
                Icons.local_offer,
                size: 40,
                color: Colors.grey,
              ),
      ),
    );
  }

  Widget _buildDealInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Business name
        Text(
          voucher.businessName,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // Deal title
        Text(
          voucher.dealTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 8),
        
        // Price and savings
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '\$${voucher.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            if (voucher.dealSnapshot != null && voucher.dealSnapshot!['originalPrice'] != null)
              Text(
                '\$${voucher.dealSnapshot!['originalPrice'].toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  decoration: TextDecoration.lineThrough,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDottedDivider() {
    return Row(
      children: [
        // Left semicircle cutout
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        
        // Dotted line
        Expanded(
          child: Container(
            height: 1,
            child: CustomPaint(
              painter: DottedLinePainter(
                color: Colors.grey.shade300,
              ),
            ),
          ),
        ),
        
        // Right semicircle cutout
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: showQRCode ? _buildQRSection() : _buildDetailsSection(context),
      ),
    );
  }

  Widget _buildQRSection() {
    if (!voucher.hasQRCode || voucher.isRedeemed || voucher.isExpired) {
      return _buildStatusMessage();
    }

    return Row(
      children: [
        // QR Code
        Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: QrImageView(
            data: voucher.qrCode!,
            version: QrVersions.auto,
            size: 64,
            backgroundColor: Colors.white,
          ),
        ),
        
        const SizedBox(width: 16),
        
        // QR instructions
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Show QR Code',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                'Present this code at ${voucher.businessName} to redeem your offer',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Expires: ${DateFormat('MMM d, yyyy').format(voucher.expirationDate)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voucher Details',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        
        const SizedBox(height: 8),
        
        _buildDetailRow('Purchased', DateFormat('MMM d, yyyy').format(voucher.purchaseDate)),
        _buildDetailRow('Expires', DateFormat('MMM d, yyyy').format(voucher.expirationDate)),
        _buildDetailRow('Status', _getStatusText()),
        
        if (voucher.redeemedAt != null)
          _buildDetailRow('Redeemed', DateFormat('MMM d, yyyy').format(voucher.redeemedAt!)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage() {
    String message;
    IconData icon;
    Color color;

    if (voucher.isRedeemed) {
      message = 'This voucher has been redeemed';
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (voucher.isExpired) {
      message = 'This voucher has expired';
      icon = Icons.schedule;
      color = Colors.red;
    } else {
      message = 'QR code not available';
      icon = Icons.error_outline;
      color = Colors.orange;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    if (!voucher.isRedeemed && !voucher.isExpired) return const SizedBox.shrink();

    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: voucher.isRedeemed ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          voucher.isRedeemed ? 'REDEEMED' : 'EXPIRED',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPerforatedEdge() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: CustomPaint(
        painter: PerforatedEdgePainter(
          color: _getBorderColor(),
        ),
      ),
    );
  }

  Color _getBorderColor() {
    if (voucher.isRedeemed) return Colors.green.shade300;
    if (voucher.isExpired) return Colors.red.shade300;
    return Colors.green;
  }

  String _getStatusText() {
    if (voucher.isRedeemed) return 'Redeemed';
    if (voucher.isExpired) return 'Expired';
    return 'Active';
  }
}

// Custom painter for dotted line
class DottedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  DottedLinePainter({
    required this.color,
    this.dashWidth = 4,
    this.dashSpace = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Custom painter for perforated edges
class PerforatedEdgePainter extends CustomPainter {
  final Color color;
  final double perfSize;
  final double perfSpacing;

  PerforatedEdgePainter({
    required this.color,
    this.perfSize = 6,
    this.perfSpacing = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Calculate divider position (60% from top)
    final double dividerY = size.height * 0.6;

    // Draw perforations along the divider
    double currentX = perfSpacing;
    while (currentX < size.width - perfSpacing) {
      canvas.drawCircle(
        Offset(currentX, dividerY),
        perfSize / 2,
        paint,
      );
      currentX += perfSpacing;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}