import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/purchase.dart';

class VoucherDetailScreen extends StatelessWidget {
  final Purchase purchase;

  const VoucherDetailScreen({
    super.key,
    required this.purchase,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Voucher'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Banner
            _buildStatusBanner(context),
            
            // Voucher Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildVoucherCard(context),
            ),
            
            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildInstructions(context),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    Color bannerColor;
    IconData bannerIcon;
    String bannerText;

    if (purchase.isRedeemed) {
      bannerColor = Colors.grey;
      bannerIcon = Icons.check_circle;
      bannerText = 'This voucher has been redeemed';
    } else if (purchase.isExpired) {
      bannerColor = Colors.orange;
      bannerIcon = Icons.warning;
      bannerText = 'This voucher has expired';
    } else {
      bannerColor = Colors.green;
      bannerIcon = Icons.check_circle_outline;
      bannerText = 'Valid voucher - Ready to use';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: bannerColor,
      child: Row(
        children: [
          Icon(bannerIcon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bannerText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Deal Image
          if (purchase.imageUrl != null && purchase.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: purchase.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
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
                  child: Icon(
                    Icons.image_not_supported,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Deal Title
                Text(
                  purchase.dealTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Business Name
                Row(
                  children: [
                    const Icon(Icons.store, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        purchase.businessName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // QR Code
                if (purchase.qrCode != null) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: QrImageView(
                        data: purchase.qrCode!,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Center(
                    child: Text(
                      'Show this QR code at ${purchase.businessName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code,
                          size: 100,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'QR code will be generated shortly',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                const Divider(),
                
                const SizedBox(height: 16),
                
                // Voucher Details
                _buildDetailRow(
                  context,
                  'Amount Paid',
                  '\$${purchase.amount.toStringAsFixed(2)} CAD',
                  Colors.green,
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  context,
                  'Purchase Date',
                  DateFormat('MMM d, yyyy h:mm a').format(purchase.purchaseDate),
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  context,
                  'Valid Until',
                  DateFormat('MMM d, yyyy h:mm a').format(purchase.expirationDate),
                  purchase.isExpired ? Colors.red : Colors.black87,
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  context,
                  'Status',
                  _getStatusText(purchase),
                  _getStatusColor(purchase),
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  context,
                  'Voucher ID',
                  purchase.id.substring(0, 8).toUpperCase(),
                  Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, [
    Color? valueColor,
  ]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'How to Use',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            _buildInstructionStep('1', 'Visit ${purchase.businessName}'),
            const SizedBox(height: 8),
            _buildInstructionStep('2', 'Show this QR code to the staff'),
            const SizedBox(height: 8),
            _buildInstructionStep('3', 'They will scan it to redeem your deal'),
            const SizedBox(height: 8),
            _buildInstructionStep('4', 'Enjoy your purchase!'),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This voucher can only be used once and expires on ${DateFormat('MMM d, yyyy').format(purchase.expirationDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
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

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusText(Purchase purchase) {
    if (purchase.isRedeemed) return 'Redeemed';
    if (purchase.isExpired) return 'Expired';
    if (purchase.status == 'confirmed') return 'Active';
    return 'Pending';
  }

  Color _getStatusColor(Purchase purchase) {
    if (purchase.isRedeemed) return Colors.grey;
    if (purchase.isExpired) return Colors.orange;
    if (purchase.status == 'confirmed') return Colors.green;
    return Colors.blue;
  }
}