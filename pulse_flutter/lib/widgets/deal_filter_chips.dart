// lib/widgets/deal_filter_chips.dart

import 'package:flutter/material.dart';

enum DealFilterType {
  category,
  discount,
  timing,
}

class DealFilter {
  final String id;
  final String label;
  final IconData icon;
  final DealFilterType type;
  final bool Function(dynamic deal) predicate;

  const DealFilter({
    required this.id,
    required this.label,
    required this.icon,
    required this.type,
    required this.predicate,
  });
}

class DealFilterChips extends StatelessWidget {
  final Set<String> selectedFilters;
  final Function(String filterId) onFilterToggle;
  final VoidCallback? onClearAll;
  final Map<String, int>? filterCounts; // Optional: show count per filter

  const DealFilterChips({
    super.key,
    required this.selectedFilters,
    required this.onFilterToggle,
    this.onClearAll,
    this.filterCounts,
  });

  static List<DealFilter> get availableFilters => [
    // Category filters
    DealFilter(
      id: 'restaurant',
      label: 'Food',
      icon: Icons.restaurant,
      type: DealFilterType.category,
      predicate: (deal) => deal.category.toLowerCase() == 'restaurant',
    ),
    DealFilter(
      id: 'cafe',
      label: 'Cafe',
      icon: Icons.coffee,
      type: DealFilterType.category,
      predicate: (deal) => deal.category.toLowerCase() == 'cafe',
    ),
    DealFilter(
      id: 'salon',
      label: 'Salon',
      icon: Icons.content_cut,
      type: DealFilterType.category,
      predicate: (deal) => deal.category.toLowerCase() == 'salon',
    ),
    DealFilter(
      id: 'fitness',
      label: 'Fitness',
      icon: Icons.fitness_center,
      type: DealFilterType.category,
      predicate: (deal) => deal.category.toLowerCase() == 'fitness',
    ),
    DealFilter(
      id: 'shop',
      label: 'Shop',
      icon: Icons.shopping_bag,
      type: DealFilterType.category,
      predicate: (deal) => deal.category.toLowerCase() == 'shop',
    ),
    
    // Discount filters
    DealFilter(
      id: 'hot_deals',
      label: '50%+ off',
      icon: Icons.local_fire_department,
      type: DealFilterType.discount,
      predicate: (deal) => deal.discountPercentage >= 50,
    ),
    DealFilter(
      id: 'good_deals',
      label: '30%+ off',
      icon: Icons.thumb_up,
      type: DealFilterType.discount,
      predicate: (deal) => deal.discountPercentage >= 30,
    ),
    
    // Timing filters
    DealFilter(
      id: 'ending_soon',
      label: 'Ending soon',
      icon: Icons.timer,
      type: DealFilterType.timing,
      predicate: (deal) {
        // Handle both DateTime and int (milliseconds) formats
        final DateTime expiration = deal.expirationTime is DateTime 
            ? deal.expirationTime 
            : DateTime.fromMillisecondsSinceEpoch(deal.expirationTime);
        final timeLeft = expiration.difference(DateTime.now());
        return timeLeft.inHours <= 2 && !timeLeft.isNegative;
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // Clear all button (only show if filters selected)
          if (selectedFilters.isNotEmpty) ...[
            _ClearAllChip(onTap: onClearAll),
            const SizedBox(width: 8),
          ],
          
          // Filter chips
          ...availableFilters.map((filter) {
            final isSelected = selectedFilters.contains(filter.id);
            final count = filterCounts?[filter.id];
            
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                filter: filter,
                isSelected: isSelected,
                count: count,
                onTap: () => onFilterToggle(filter.id),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final DealFilter filter;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.filter,
    required this.isSelected,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filter.icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                filter.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[800],
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withOpacity(0.2) 
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearAllChip extends StatelessWidget {
  final VoidCallback? onTap;

  const _ClearAllChip({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red[50],
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, size: 16, color: Colors.red[700]),
              const SizedBox(width: 4),
              Text(
                'Clear',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}