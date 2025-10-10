// pulse_flutter/lib/screens/voucher_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/purchase.dart';
import '../services/purchase_service.dart';
import '../services/auth_service.dart';
import 'voucher_detail_screen.dart';

class VoucherListScreen extends StatefulWidget {
  const VoucherListScreen({super.key});

  @override
  State<VoucherListScreen> createState() => _VoucherListScreenState();
}

class _VoucherListScreenState extends State<VoucherListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadVouchers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVouchers() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final purchaseService = Provider.of<PurchaseService>(context, listen: false);
    
    if (authService.currentUser != null) {
      await purchaseService.loadPurchases(authService.currentUser!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vouchers'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Active', icon: Icon(Icons.check_circle_outline)),
            Tab(text: 'Used', icon: Icon(Icons.check_circle)),
            Tab(text: 'Expired', icon: Icon(Icons.access_time)),
          ],
        ),
      ),
      body: Consumer<PurchaseService>(
        builder: (context, purchaseService, child) {
          if (purchaseService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (purchaseService.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading vouchers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    purchaseService.errorMessage!,
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadVouchers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Active Vouchers
              _buildVoucherList(
                purchaseService.activePurchases,
                'No active vouchers',
                'Your active vouchers will appear here',
                Icons.local_offer,
              ),
              
              // Redeemed Vouchers
              _buildVoucherList(
                purchaseService.redeemedPurchases,
                'No redeemed vouchers',
                'Vouchers you\'ve used will appear here',
                Icons.history,
              ),
              
              // Expired Vouchers
              _buildVoucherList(
                purchaseService.expiredPurchases,
                'No expired vouchers',
                'Expired vouchers will appear here',
                Icons.access_time,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoucherList(
    List<Purchase> vouchers,
    String emptyTitle,
    String emptySubtitle,
    IconData emptyIcon,
  ) {
    if (vouchers.isEmpty) {
      return _buildEmptyState(emptyTitle, emptySubtitle, emptyIcon);
    }

    return RefreshIndicator(
      onRefresh: _loadVouchers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vouchers.length,
        itemBuilder: (context, index) {
          final voucher = vouchers[index];
          return _buildVoucherCard(voucher);
        },
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(); // Go back to deals
            },
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Browse Deals'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(Purchase voucher) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VoucherDetailScreen(purchase: voucher),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(voucher),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(voucher),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(voucher),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\$${voucher.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Main Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Deal Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (voucher.imageUrl != null && voucher.imageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: voucher.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.local_offer),
                          ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Deal Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voucher.dealTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.store,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                voucher.businessName,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildDateInfo(voucher),
                      ],
                    ),
                  ),
                  
                  // Arrow Icon
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInfo(Purchase voucher) {
    if (voucher.isRedeemed && voucher.redeemedAt != null) {
      return Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 14,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Used ${DateFormat('MMM d, yyyy').format(voucher.redeemedAt!)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (voucher.isExpired) {
      return Row(
        children: [
          Icon(
            Icons.access_time,
            size: 14,
            color: Colors.red.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Expired ${DateFormat('MMM d, yyyy').format(voucher.expirationDate)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Icon(
            Icons.schedule,
            size: 14,
            color: Colors.blue.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Valid until ${DateFormat('MMM d, yyyy').format(voucher.expirationDate)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
  }

  Color _getStatusColor(Purchase voucher) {
    if (voucher.isRedeemed) {
      return Colors.green;
    } else if (voucher.isExpired) {
      return Colors.red;
    } else {
      return Colors.blue;
    }
  }

  IconData _getStatusIcon(Purchase voucher) {
    if (voucher.isRedeemed) {
      return Icons.check_circle;
    } else if (voucher.isExpired) {
      return Icons.access_time;
    } else {
      return Icons.check_circle_outline;
    }
  }

  String _getStatusText(Purchase voucher) {
    if (voucher.isRedeemed) {
      return 'REDEEMED';
    } else if (voucher.isExpired) {
      return 'EXPIRED';
    } else {
      return 'ACTIVE';
    }
  }
}