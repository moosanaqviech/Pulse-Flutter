// lib/widgets/deal_filter_chips.dart

import 'package:flutter/material.dart';

enum DealFilterType {
  category,
  tag,
  discount,
  timing,
}

class DealFilter {
  final String id;
  final String label;
  final IconData? icon; // nullable — tag filters use emoji in label instead
  final DealFilterType type;
  final bool Function(dynamic deal) predicate;

  const DealFilter({
    required this.id,
    required this.label,
    this.icon,
    required this.type,
    required this.predicate,
  });
}

class DealFilterChips extends StatelessWidget {
  final Set<String> selectedFilters;
  final Function(String filterId) onFilterToggle;
  final VoidCallback? onClearAll;
  final Map<String, int>? filterCounts;

  const DealFilterChips({
    super.key,
    required this.selectedFilters,
    required this.onFilterToggle,
    this.onClearAll,
    this.filterCounts,
  });

  static List<DealFilter> get availableFilters => [
    // ── Business category filters ──
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
    DealFilter(
      id: 'entertainment',
      label: 'Entertainment',
      icon: Icons.theater_comedy,
      type: DealFilterType.category,
      predicate: (deal) => deal.category.toLowerCase() == 'entertainment',
    ),

    // ── Tag filters (emoji in label, no icon) ──
    DealFilter(
      id: 'tag_new_item',
      label: '🆕 New',
      type: DealFilterType.tag,
      predicate: (deal) => deal.tags.contains('new_item'),
    ),
    DealFilter(
      id: 'tag_event_special',
      label: '🎉 Event',
      type: DealFilterType.tag,
      predicate: (deal) => deal.tags.contains('event_special'),
    ),
    DealFilter(
      id: 'tag_flash_sale',
      label: '⚡ Flash',
      type: DealFilterType.tag,
      predicate: (deal) => deal.tags.contains('flash_sale'),
    ),
    DealFilter(
      id: 'tag_happy_hour',
      label: '🍻 Happy Hour',
      type: DealFilterType.tag,
      predicate: (deal) => deal.tags.contains('happy_hour'),
    ),
    DealFilter(
      id: 'tag_game_day',
      label: '⚽ Game Day',
      type: DealFilterType.tag,
      predicate: (deal) => deal.tags.contains('game_day'),
    ),
    DealFilter(
      id: 'tag_grand_opening',
      label: '🎊 Grand Opening',
      type: DealFilterType.tag,
      predicate: (deal) => deal.tags.contains('grand_opening'),
    ),

    // ── Discount filters ──
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

    // ── Timing filters ──
    DealFilter(
      id: 'ending_soon',
      label: 'Ending soon',
      icon: Icons.timer,
      type: DealFilterType.timing,
      predicate: (deal) {
        final DateTime expiration = deal.expirationTime is DateTime
            ? deal.expirationTime
            : DateTime.fromMillisecondsSinceEpoch(deal.expirationTime);
        return expiration.difference(DateTime.now()).inHours <= 2;
      },
    ),
  ];

  // Row 1: business categories
  static List<DealFilter> _row1Filters() =>
      availableFilters.where((f) => f.type == DealFilterType.category).toList();

  // Row 2: tags + discount + timing
  static List<DealFilter> _row2Filters() =>
      availableFilters.where((f) => f.type != DealFilterType.category).toList();

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = selectedFilters.isNotEmpty;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Row 1: Business categories ──
            _buildFilterRow(
              context,
              filters: _row1Filters(),
              primaryColor: primaryColor,
            ),

            // ── Separator ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.grey.shade300,
              ),
            ),

            // ── Row 2: Tags + Deal types ──
            _buildFilterRow(
              context,
              filters: _row2Filters(),
              primaryColor: primaryColor,
            ),

            // ── Clear all (only when filters active) ──
            if (hasActiveFilters)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: GestureDetector(
                  onTap: onClearAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear_all, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Clear filters',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!hasActiveFilters) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Builds one horizontal scrollable row of chips.
  Widget _buildFilterRow(
    BuildContext context, {
    required List<DealFilter> filters,
    required Color primaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final filter = filters[index];
            final isSelected = selectedFilters.contains(filter.id);
            final count = filterCounts?[filter.id];
            return _buildChip(filter, isSelected, count, primaryColor);
          },
        ),
      ),
    );
  }

  /// Individual filter chip.
  Widget _buildChip(DealFilter filter, bool isSelected, int? count, Color primaryColor) {
    return GestureDetector(
      onTap: () => onFilterToggle(filter.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Only show Material icon if provided
            if (filter.icon != null) ...[
              Icon(
                filter.icon,
                size: 14,
                color: isSelected ? primaryColor : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              filter.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? primaryColor : Colors.grey.shade700,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withOpacity(0.2)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? primaryColor : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}