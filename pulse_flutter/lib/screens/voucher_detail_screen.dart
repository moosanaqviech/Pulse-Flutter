// pulse_flutter/lib/screens/voucher_detail_screen.dart
// Working enhanced version based on your original code

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/purchase.dart';
import '../services/purchase_service.dart';

class VoucherDetailScreen extends StatefulWidget {
  final Purchase purchase;

  const VoucherDetailScreen({
    super.key,
    required this.purchase,
  });

  @override
  State<VoucherDetailScreen> createState() => _VoucherDetailScreenState();
}

class _VoucherDetailScreenState extends State<VoucherDetailScreen> {
  late Purchase currentPurchase;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    currentPurchase = widget.purchase;
  }

  Future<void> _refreshVoucherStatus() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      final purchaseService = Provider.of<PurchaseService>(context, listen: false);
      final updatedPurchase = await purchaseService.getPurchase(currentPurchase.id);
      
      if (updatedPurchase != null && mounted) {
        setState(() {
          currentPurchase = updatedPurchase;
        });
        
        // Show snackbar if status changed
        if (updatedPurchase.isRedeemed && !widget.purchase.isRedeemed) {
          _showRedeemedNotification();
        }
      }
    } catch (e) {
      debugPrint('Error refreshing voucher status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showRedeemedNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Voucher has been redeemed!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Voucher'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshVoucherStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshVoucherStatus,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Status Banner
              _buildStatusBanner(context),
              
              // Voucher Card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildVoucherCard(context),
              ),
              
              // QR Code Actions (if active)
              if (currentPurchase.isActive && currentPurchase.hasQRCode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildQRActions(context),
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
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    Color bannerColor;
    IconData bannerIcon;
    String bannerText;

    if (currentPurchase.isRedeemed) {
      bannerColor = Colors.green;
      bannerIcon = Icons.check_circle;
      bannerText = 'This voucher has been redeemed';
    } else if (currentPurchase.isExpired) {
      bannerColor = Colors.orange;
      bannerIcon = Icons.warning;
      bannerText = 'This voucher has expired';
    } else {
      bannerColor = Colors.blue;
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
          if (currentPurchase.imageUrl != null && currentPurchase.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: currentPurchase.imageUrl!,
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
                  currentPurchase.dealTitle,
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
                        currentPurchase.businessName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // QR Code
                if (currentPurchase.qrCode != null && currentPurchase.qrCode!.isNotEmpty) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: currentPurchase.isActive ? Colors.green : Colors.grey.shade300, 
                          width: currentPurchase.isActive ? 3 : 2
                        ),
                      ),
                      child: QrImageView(
                        data: currentPurchase.qrCode!,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Center(
                    child: Text(
                      currentPurchase.isActive 
                        ? 'Show this QR code at ${currentPurchase.businessName}'
                        : currentPurchase.isRedeemed 
                          ? 'This voucher has been redeemed'
                          : 'This voucher has expired',
                      style: TextStyle(
                        fontSize: 12,
                        color: currentPurchase.isActive 
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
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
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refreshVoucherStatus,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
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
                  '\$${currentPurchase.amount.toStringAsFixed(2)} CAD',
                  Colors.green,
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  context,
                  'Purchase Date',
                  DateFormat('MMM d, yyyy h:mm a').format(currentPurchase.purchaseDate),
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  context,
                  'Valid Until',
                  DateFormat('MMM d, yyyy h:mm a').format(currentPurchase.expirationDate),
                  currentPurchase.isExpired ? Colors.red : Colors.black87,
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  context,
                  'Status',
                  _getStatusText(currentPurchase),
                  _getStatusColor(currentPurchase),
                ),
                
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  context,
                  'Voucher ID',
                  currentPurchase.id.length >= 8 
                    ? currentPurchase.id.substring(0, 8).toUpperCase()
                    : currentPurchase.id.toUpperCase(),
                  Colors.grey.shade600,
                ),
                
                // Redeemed info
                if (currentPurchase.isRedeemed && currentPurchase.redeemedAt != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    'Redeemed At',
                    DateFormat('MMM d, yyyy h:mm a').format(currentPurchase.redeemedAt!),
                    Colors.green,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRActions(BuildContext context) {
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
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyVoucherCode(),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Code'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareVoucher(),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                  'How to Use Your Voucher',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            _buildInstructionStep('1', 'Visit ${currentPurchase.businessName}'),
            const SizedBox(height: 8),
            _buildInstructionStep('2', 'Show this QR code to the staff'),
            const SizedBox(height: 8),
            _buildInstructionStep('3', 'Staff will scan the code to redeem your deal'),
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
                      'This voucher can only be used once and expires on ${DateFormat('MMM d, yyyy').format(currentPurchase.expirationDate)}',
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
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
    if (purchase.isRedeemed) return Colors.green;
    if (purchase.isExpired) return Colors.orange;
    if (purchase.status == 'confirmed') return Colors.green;
    return Colors.blue;
  }

  void _copyVoucherCode() {
    if (currentPurchase.qrCode != null) {
      Clipboard.setData(ClipboardData(text: currentPurchase.qrCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voucher code copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareVoucher() {
    // You can implement share functionality here using share_plus package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}