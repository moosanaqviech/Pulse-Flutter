import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;

class CustomMarkerGenerator {
  // Create a custom marker with just category icon - clean and simple
  static Future<BitmapDescriptor> createDealMarker({
    required String category,
    required double price, // Keep for compatibility but won't display
    required double originalPrice,
    required int discountPercentage,
    required bool isActive,
    required bool isPopular,
    double neonAnimationPhase = 0.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(120, 140); // Smaller, cleaner size

    // Main marker container
    _drawMarkerContainer(canvas, size, isActive, isPopular);
    
    // Category icon with neon effect - 20% smaller
    _drawCategoryIcon(canvas, category, size, neonAnimationPhase);

    // Marker pointer (bottom triangle)
    _drawMarkerPointer(canvas, size, isActive);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

 static Future<BitmapDescriptor> createDealMarkerWithCount({
  required String category,
  required double price,
  required double originalPrice,
  required int discountPercentage,
  required bool isActive,
  required bool isPopular,
  required int dealCount,
  double neonAnimationPhase = 0.0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(120, 140);

  // Main marker container
  _drawMarkerContainer(canvas, size, isActive, isPopular);
  
  // Category icon
  _drawCategoryIcon(canvas, category, size, neonAnimationPhase);

  // Deal count badge (if more than 1 deal)
  if (dealCount > 1) {
    _drawDealCountBadge(canvas, size, dealCount);
  }

  // Marker pointer (bottom triangle)
  _drawMarkerPointer(canvas, size, isActive);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  
  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}

// ADD this helper method to CustomMarkerGenerator class:

static void _drawDealCountBadge(Canvas canvas, Size size, int count) {
  final badgeRadius = 14.0;
  final badgeCenter = Offset(size.width - badgeRadius - 4, badgeRadius + 4);
  
  // Badge background
  final badgePaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.fill;
  
  canvas.drawCircle(badgeCenter, badgeRadius, badgePaint);
  
  // White border
  final borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  
  canvas.drawCircle(badgeCenter, badgeRadius, borderPaint);
  
  // Count text
  final textPainter = TextPainter(
    text: TextSpan(
      text: count.toString(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      badgeCenter.dx - textPainter.width / 2,
      badgeCenter.dy - textPainter.height / 2,
    ),
  );
}
  // Enhanced marker with animation capability - simple version
  static Future<BitmapDescriptor> createAnimatedDealMarker({
    required String category,
    required double price,
    required double originalPrice,
    required int discountPercentage,
    required bool isActive,
    required bool isPopular,
    required bool isPulsing,
    double neonAnimationPhase = 0.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(140, 160);

    // Animated pulse rings for popular deals
    if (isPopular && isPulsing) {
      _drawPulseRings(canvas, size);
    }

    // Main marker
    _drawMarkerContainer(canvas, size, isActive, isPopular);
    _drawCategoryIcon(canvas, category, size, neonAnimationPhase);
    _drawMarkerPointer(canvas, size, isActive);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  static void _drawMarkerContainer(Canvas canvas, Size size, bool isActive, bool isPopular) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isPopular 
          ? [const Color(0xFFFF6B6B), const Color(0xFFFF5252)]
          : isActive 
            ? [const Color(0xFF4CAF50), const Color(0xFF45A049)]
            : [const Color(0xFF9E9E9E), const Color(0xFF757575)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height - 20));

    // Main rounded rectangle
    final roundedRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 10, size.width - 20, size.height - 30),
      const Radius.circular(16),
    );
    
    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawRRect(
      roundedRect.shift(const Offset(2, 2)), 
      shadowPaint
    );
    
    // Main container
    canvas.drawRRect(roundedRect, paint);
    
    // White inner container for content
    final innerPaint = Paint()..color = Colors.white;
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(15, 15, size.width - 30, size.height - 40),
      const Radius.circular(12),
    );
    canvas.drawRRect(innerRect, innerPaint);

    // Popularity pulse effect for hot deals
    if (isPopular) {
      final pulsePaint = Paint()
        ..color = const Color(0xFFFF6B6B).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(5, 5, size.width - 10, size.height - 25),
          const Radius.circular(20),
        ),
        pulsePaint
      );
    }
  }

  static void _drawCategoryIcon(Canvas canvas, String category, Size size, double animationPhase) {
    final center = Offset(size.width / 2, size.height / 2 - 10); // Centered in marker
    final iconSize = size.width * 0.65; // Much larger - fills most of the rectangle
    
    // Draw neon glow effect around the square boundary
    if (animationPhase > 0) {
      _drawSquareNeonGlow(canvas, size, animationPhase);
    }

    // Get category-specific color
    final iconPaint = Paint()
      ..color = _getCategoryColor(category)
      ..style = PaintingStyle.fill;

    // Draw category-specific icons that fill the rectangle
    switch (category.toLowerCase()) {
      case 'restaurant':
        _drawRestaurantIcon(canvas, center, iconSize, iconPaint);
        break;
      case 'cafe':
        _drawCafeIcon(canvas, center, iconSize, iconPaint);
        break;
      case 'shop':
        _drawShopIcon(canvas, center, iconSize, iconPaint);
        break;
      case 'activity':
        _drawActivityIcon(canvas, center, iconSize, iconPaint);
        break;
      case 'salon':
        _drawSalonIcon(canvas, center, iconSize, iconPaint);
        break;
      case 'fitness':
        _drawFitnessIcon(canvas, center, iconSize, iconPaint);
        break;
      default:
        _drawDefaultIcon(canvas, center, iconSize, iconPaint);
    }
  }

  static void _drawSquareNeonGlow(Canvas canvas, Size size, double animationPhase) {
    final neonColors = [
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFF00FF00), // Green  
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFFFFFF00), // Yellow
      const Color(0xFF00FFFF), // Back to cyan for smooth loop
    ];

    // Get the square boundary (main marker area without pointer)
    final squareRect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 30);

    // Create multiple rotating neon rings around the square
    for (int ring = 0; ring < 3; ring++) {
      final expansion = ring * 4.0 + 8.0;
      final expandedRect = Rect.fromLTWH(
        squareRect.left - expansion,
        squareRect.top - expansion,
        squareRect.width + (expansion * 2),
        squareRect.height + (expansion * 2),
      );
      
      final ringPhase = (animationPhase + ring * 0.33) % 1.0;
      
      // Draw the rotating neon effect around square perimeter
      _drawSquareNeonRing(canvas, expandedRect, ringPhase, neonColors, ring);
    }
  }

  static void _drawSquareNeonRing(Canvas canvas, Rect rect, double phase, List<Color> colors, int ringIndex) {
    final perimeter = 2 * (rect.width + rect.height);
    final segmentCount = 60;
    
    for (int i = 0; i < segmentCount; i++) {
      final t = (i / segmentCount + phase) % 1.0;
      final position = t * perimeter;
      
      // Calculate position along square perimeter
      Offset point;
      if (position <= rect.width) {
        // Top edge
        point = Offset(rect.left + position, rect.top);
      } else if (position <= rect.width + rect.height) {
        // Right edge
        point = Offset(rect.right, rect.top + (position - rect.width));
      } else if (position <= 2 * rect.width + rect.height) {
        // Bottom edge
        point = Offset(rect.right - (position - rect.width - rect.height), rect.bottom);
      } else {
        // Left edge
        point = Offset(rect.left, rect.bottom - (position - 2 * rect.width - rect.height));
      }
      
      // Calculate color based on position and animation
      final colorIndex = ((i / segmentCount) + phase) % 1.0;
      final color = _interpolateNeonColor(colors, colorIndex);
      
      // Create glow effect with multiple layers
      for (int layer = 0; layer < 3; layer++) {
        final glowPaint = Paint()
          ..color = color.withOpacity(0.6 - layer * 0.15)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 + layer * 1.5);
        
        canvas.drawCircle(point, 3.0 + layer * 0.5, glowPaint);
      }
      
      // Draw the bright core
      final corePaint = Paint()
        ..color = color.withOpacity(0.9)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(point, 1.5, corePaint);
    }
  }

  static Color _interpolateNeonColor(List<Color> colors, double position) {
    position = position % 1.0;
    final segmentSize = 1.0 / (colors.length - 1);
    final segment = (position / segmentSize).floor();
    final localPosition = (position % segmentSize) / segmentSize;
    
    if (segment >= colors.length - 1) {
      return colors.last;
    }
    
    final color1 = colors[segment];
    final color2 = colors[segment + 1];
    
    return Color.lerp(color1, color2, localPosition) ?? color1;
  }

  // Get distinctive color for each business category
  static Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'restaurant':
        return const Color(0xFFD32F2F); // Rich red
      case 'cafe':
        return const Color(0xFF8D6E63); // Coffee brown
      case 'shop':
        return const Color(0xFF1976D2); // Blue
      case 'activity':
        return const Color(0xFFFFB300); // Amber/gold
      case 'salon':
        return const Color(0xFFE91E63); // Pink
      case 'fitness':
        return const Color(0xFF388E3C); // Green
      default:
        return const Color(0xFF6A1B9A); // Purple
    }
  }

  static void _drawMarkerPointer(Canvas canvas, Size size, bool isActive) {
    final pointerPaint = Paint()
      ..color = isActive ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E)
      ..style = PaintingStyle.fill;

    final pointerPath = Path();
    pointerPath.moveTo(size.width / 2, size.height - 5);
    pointerPath.lineTo(size.width / 2 - 10, size.height - 20);
    pointerPath.lineTo(size.width / 2 + 10, size.height - 20);
    pointerPath.close();

    // Shadow for pointer
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    canvas.drawPath(pointerPath.shift(const Offset(1, 1)), shadowPaint);
    canvas.drawPath(pointerPath, pointerPaint);
  }

  static void _drawPulseRings(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 10);
    final pulsePaint = Paint()
      ..color = const Color(0xFFFF6B6B).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, 30.0 + (i * 15), pulsePaint);
    }
  }

  // Category icon drawing methods - large versions that fill the rectangle
  static void _drawRestaurantIcon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    
    // Fork (left side) - much larger
    final forkWidth = size * 0.2;
    final forkHeight = size * 0.8;
    
    // Fork handle
    path.addRect(Rect.fromCenter(
      center: Offset(center.dx - size * 0.2, center.dy + size * 0.05),
      width: forkWidth * 0.6,
      height: forkHeight * 0.6,
    ));
    
    // Fork prongs - larger and more visible
    for (int i = 0; i < 4; i++) {
      final prongX = center.dx - size * 0.2 - forkWidth * 0.4 + (i * forkWidth * 0.27);
      path.addRect(Rect.fromCenter(
        center: Offset(prongX, center.dy - size * 0.25),
        width: forkWidth * 0.12,
        height: forkHeight * 0.45,
      ));
    }
    
    // Knife (right side) - much larger
    final knifeWidth = size * 0.15;
    final knifeHeight = size * 0.8;
    
    // Knife handle
    path.addRect(Rect.fromCenter(
      center: Offset(center.dx + size * 0.2, center.dy + size * 0.2),
      width: knifeWidth,
      height: knifeHeight * 0.5,
    ));
    
    // Knife blade - large and prominent
    final bladePath = Path();
    bladePath.moveTo(center.dx + size * 0.2 - knifeWidth * 0.5, center.dy - size * 0.3);
    bladePath.lineTo(center.dx + size * 0.2 + knifeWidth * 0.5, center.dy - size * 0.3);
    bladePath.lineTo(center.dx + size * 0.2, center.dy - size * 0.05);
    bladePath.close();
    path.addPath(bladePath, Offset.zero);

    canvas.drawPath(path, paint);
  }

  static void _drawCafeIcon(Canvas canvas, Offset center, double size, Paint paint) {
    final cupWidth = size * 0.6;
    final cupHeight = size * 0.7;
    
    // Large cup body that fills most of the space
    final cupRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: cupWidth, height: cupHeight),
      Radius.circular(size * 0.08),
    );
    
    canvas.drawRRect(cupRect, paint);
    
    // Large handle
    final handlePaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.08;
    
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx + cupWidth * 0.4, center.dy),
        width: cupWidth * 0.45,
        height: cupHeight * 0.5,
      ),
      -math.pi / 2,
      math.pi,
      false,
      handlePaint,
    );
    
    // Multiple steam lines - larger and more prominent
    final steamPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.05
      ..strokeCap = StrokeCap.round;
    
    for (int i = 0; i < 3; i++) {
      final steamPath = Path();
      final startX = center.dx - cupWidth * 0.2 + i * cupWidth * 0.2;
      final startY = center.dy - cupHeight * 0.4;
      
      steamPath.moveTo(startX, startY);
      steamPath.quadraticBezierTo(
        startX + size * 0.06, startY - size * 0.1,
        startX, startY - size * 0.2,
      );
      steamPath.quadraticBezierTo(
        startX - size * 0.06, startY - size * 0.3,
        startX, startY - size * 0.4,
      );
      
      canvas.drawPath(steamPath, steamPaint);
    }
    
    // Coffee surface detail
    final surfacePaint = Paint()
      ..color = paint.color.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - cupHeight * 0.25),
        width: cupWidth * 0.8,
        height: cupWidth * 0.2,
      ),
      surfacePaint,
    );
  }

  static void _drawShopIcon(Canvas canvas, Offset center, double size, Paint paint) {
    final bagWidth = size * 0.65;
    final bagHeight = size * 0.8;
    
    // Large shopping bag body
    final bagRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: bagWidth, height: bagHeight),
      Radius.circular(size * 0.06),
    );
    
    canvas.drawRRect(bagRect, paint);
    
    // Large handles
    final handlePaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.06;
    
    // Left handle
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx - bagWidth * 0.2, center.dy - bagHeight * 0.25),
        width: bagWidth * 0.25,
        height: bagHeight * 0.3,
      ),
      0,
      math.pi,
      false,
      handlePaint,
    );
    
    // Right handle
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx + bagWidth * 0.2, center.dy - bagHeight * 0.25),
        width: bagWidth * 0.25,
        height: bagHeight * 0.3,
      ),
      0,
      math.pi,
      false,
      handlePaint,
    );
    
    // Shopping bag details
    final detailPaint = Paint()
      ..color = paint.color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.04;
    
    // Fold line
    canvas.drawLine(
      Offset(center.dx - bagWidth * 0.4, center.dy - bagHeight * 0.1),
      Offset(center.dx + bagWidth * 0.4, center.dy - bagHeight * 0.1),
      detailPaint,
    );
    
    // Logo area (rectangle on bag)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + bagHeight * 0.1),
        width: bagWidth * 0.4,
        height: bagHeight * 0.25,
      ),
      detailPaint,
    );
  }

  static void _drawActivityIcon(Canvas canvas, Offset center, double size, Paint paint) {
    final starPath = Path();
    final points = 5;
    final outerRadius = size * 0.35; // Much larger
    final innerRadius = size * 0.18;
    
    // Draw outer star
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi) / points - math.pi / 2;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();
    
    canvas.drawPath(starPath, paint);
    
    // Inner star detail
    final innerStarPath = Path();
    final innerOuterRadius = size * 0.22;
    final innerInnerRadius = size * 0.12;
    
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi) / points - math.pi / 2;
      final radius = i.isEven ? innerOuterRadius : innerInnerRadius;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        innerStarPath.moveTo(x, y);
      } else {
        innerStarPath.lineTo(x, y);
      }
    }
    innerStarPath.close();
    
    final innerPaint = Paint()
      ..color = paint.color.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(innerStarPath, innerPaint);
    
    // Center circle
    canvas.drawCircle(center, size * 0.06, paint);
  }

  static void _drawSalonIcon(Canvas canvas, Offset center, double size, Paint paint) {
    // Large scissors that fill the space
    
    // Left scissor blade
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - size * 0.15, center.dy - size * 0.15),
        width: size * 0.18,
        height: size * 0.35,
      ),
      paint,
    );
    
    // Right scissor blade  
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + size * 0.15, center.dy + size * 0.15),
        width: size * 0.18,
        height: size * 0.35,
      ),
      paint,
    );
    
    // Scissor handles (rings)
    final handlePaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.04;
    
    canvas.drawCircle(
      Offset(center.dx - size * 0.25, center.dy + size * 0.2), 
      size * 0.08, 
      handlePaint
    );
    canvas.drawCircle(
      Offset(center.dx + size * 0.25, center.dy - size * 0.2), 
      size * 0.08, 
      handlePaint
    );
    
    // Connection/pivot line
    final pivotPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.06
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      Offset(center.dx - size * 0.08, center.dy - size * 0.08),
      Offset(center.dx + size * 0.08, center.dy + size * 0.08),
      pivotPaint,
    );
    
    // Pivot point
    canvas.drawCircle(center, size * 0.05, paint);
  }

  static void _drawFitnessIcon(Canvas canvas, Offset center, double size, Paint paint) {
    // Large dumbbell that fills the space
    
    // Left weight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx - size * 0.25, center.dy),
          width: size * 0.15,
          height: size * 0.4,
        ),
        Radius.circular(size * 0.03),
      ),
      paint,
    );
    
    // Right weight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx + size * 0.25, center.dy),
          width: size * 0.15,
          height: size * 0.4,
        ),
        Radius.circular(size * 0.03),
      ),
      paint,
    );
    
    // Connecting bar
    final barPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.08
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      Offset(center.dx - size * 0.17, center.dy),
      Offset(center.dx + size * 0.17, center.dy),
      barPaint,
    );
    
    // Grip details on the bar
    final gripPaint = Paint()
      ..color = paint.color.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.03;
    
    for (int i = -2; i <= 2; i++) {
      if (i != 0) {
        canvas.drawLine(
          Offset(center.dx + i * size * 0.04, center.dy - size * 0.08),
          Offset(center.dx + i * size * 0.04, center.dy + size * 0.08),
          gripPaint,
        );
      }
    }
    
    // Weight plates details
    final platePaint = Paint()
      ..color = paint.color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.02;
    
    // Left weight details
    canvas.drawLine(
      Offset(center.dx - size * 0.25, center.dy - size * 0.15),
      Offset(center.dx - size * 0.25, center.dy + size * 0.15),
      platePaint,
    );
    
    // Right weight details
    canvas.drawLine(
      Offset(center.dx + size * 0.25, center.dy - size * 0.15),
      Offset(center.dx + size * 0.25, center.dy + size * 0.15),
      platePaint,
    );
  }

  static void _drawDefaultIcon(Canvas canvas, Offset center, double size, Paint paint) {
    final tagWidth = size * 0.6;
    final tagHeight = size * 0.5;
    
    // Large tag that fills most of the space
    final tagPath = Path();
    tagPath.moveTo(center.dx - tagWidth * 0.5, center.dy - tagHeight * 0.5);
    tagPath.lineTo(center.dx + tagWidth * 0.2, center.dy - tagHeight * 0.5);
    tagPath.lineTo(center.dx + tagWidth * 0.5, center.dy);
    tagPath.lineTo(center.dx + tagWidth * 0.2, center.dy + tagHeight * 0.5);
    tagPath.lineTo(center.dx - tagWidth * 0.5, center.dy + tagHeight * 0.5);
    tagPath.close();
    
    canvas.drawPath(tagPath, paint);
    
    // Large tag hole
    final holePaint = Paint()
      ..color = paint.color.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(center.dx - tagWidth * 0.25, center.dy),
      size * 0.08,
      holePaint,
    );
    
    // Tag string/cord
    final stringPaint = Paint()
      ..color = paint.color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.03
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      Offset(center.dx - tagWidth * 0.25, center.dy - size * 0.08),
      Offset(center.dx - tagWidth * 0.25, center.dy - tagHeight * 0.7),
      stringPaint,
    );
  }
}