import 'package:flutter/material.dart';

class RatingWidget extends StatelessWidget {
  final int rating;
  final Function(int)? onRatingChanged;
  final double size;
  final bool readOnly;
  final Color color;
  final MainAxisSize mainAxisSize;

  const RatingWidget({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.size = 32.0,
    this.readOnly = false,
    this.color = Colors.amber,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: readOnly || onRatingChanged == null 
              ? null 
              : () => onRatingChanged!(index + 1),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.05),
            child: Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: color,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}

/// Display-only rating with average and count
class RatingDisplay extends StatelessWidget {
  final double averageRating;
  final int totalRatings;
  final double size;
  final bool showCount;

  const RatingDisplay({
    super.key,
    required this.averageRating,
    required this.totalRatings,
    this.size = 16.0,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star,
          color: Colors.amber,
          size: size,
        ),
        const SizedBox(width: 4),
        Text(
          averageRating.toStringAsFixed(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: size * 0.875,
          ),
        ),
        if (showCount) ...[
          Text(
            ' ($totalRatings)',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: size * 0.75,
            ),
          ),
        ],
      ],
    );
  }
}