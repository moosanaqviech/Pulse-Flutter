import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;

class CustomMarkerGenerator {
  // Create a custom marker with category icon and price (no discount badges)
  static Future<BitmapDescriptor> createDealMarker({
    required String category,
    required double price,
    required double originalPrice,
    required int discountPercentage,
    required bool isActive,
    required bool isPopular,
    double neonAnimationPhase = 0.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(180, 200);

    // Main marker container
    _drawMarkerContainer(canvas, size, isActive, isPopular);
    
    // Category icon with neon effect - now fills the whole square
    _drawCategoryIcon(canvas, category, size, neonAnimationPhase);
    
    // Only price, no discount badge
    _drawPrice(canvas, price, size);

    // Marker pointer (bottom triangle)
    _drawMarkerPointer(canvas, size, isActive);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // Enhanced marker with animation capability
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
    final size = Size(200, 220);

    // Animated pulse rings for popular deals
    if (isPopular && isPulsing) {
      _drawPulseRings(canvas, size);
    }

    // Main marker
    _drawMarkerContainer(canvas, size, isActive, isPopular);
    _drawCategoryIcon(canvas, category, size, neonAnimationPhase);
    
    // Only price, no discount badge
    _drawPrice(canvas, price, size);
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
          ? [Color(0xFFFF6B6B), Color(0xFFFF5252)]
          : isActive 
            ? [Color(0xFF4CAF50), Color(0xFF45A049)]
            : [Color(0xFF9E9E9E), Color(0xFF757575)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height - 20));

    // Main rounded rectangle
    final roundedRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 10, size.width - 20, size.height - 30),
      Radius.circular(16),
    );
    
    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawRRect(
      roundedRect.shift(Offset(2, 2)), 
      shadowPaint
    );
    
    // Main container
    canvas.drawRRect(roundedRect, paint);
    
    // White inner container for content
    final innerPaint = Paint()..color = Colors.white;
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(15, 15, size.width - 30, size.height - 40),
      Radius.circular(12),
    );
    canvas.drawRRect(innerRect, innerPaint);

    // Popularity pulse effect for hot deals
    if (isPopular) {
      final pulsePaint = Paint()
        ..color = Color(0xFFFF6B6B).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(5, 5, size.width - 10, size.height - 25),
          Radius.circular(20),
        ),
        pulsePaint
      );
    }
  }

  static void _drawCategoryIcon(Canvas canvas, String category, Size size, double animationPhase) {
    final center = Offset(size.width / 2, size.height / 2 - 20);
    final squareSize = size.width - 40;
    
    // Draw neon glow effect around the square boundary
    if (animationPhase > 0) {
      _drawSquareNeonGlow(canvas, size, animationPhase);
    }

    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw category-specific icons that fill the square
    switch (category.toLowerCase()) {
      case 'restaurant':
        _drawRestaurantIconLarge(canvas, center, squareSize, iconPaint);
        break;
      case 'cafe':
        _drawCafeIconLarge(canvas, center, squareSize, iconPaint);
        break;
      case 'shop':
        _drawShopIconLarge(canvas, center, squareSize, iconPaint);
        break;
      case 'activity':
        _drawActivityIconLarge(canvas, center, squareSize, iconPaint);
        break;
      case 'salon':
        _drawSalonIconLarge(canvas, center, squareSize, iconPaint);
        break;
      case 'fitness':
        _drawFitnessIconLarge(canvas, center, squareSize, iconPaint);
        break;
      default:
        _drawDefaultIconLarge(canvas, center, squareSize, iconPaint);
    }
  }

  static void _drawSquareNeonGlow(Canvas canvas, Size size, double animationPhase) {
    final neonColors = [
      Color(0xFF00FFFF), // Cyan
      Color(0xFF00FF00), // Green  
      Color(0xFFFF00FF), // Magenta
      Color(0xFFFFFF00), // Yellow
      Color(0xFF00FFFF), // Back to cyan for smooth loop
    ];

    // Get the square boundary (main marker area without pointer)
    final squareRect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 40);

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
    final segmentLength = perimeter / segmentCount;
    
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

  static void _drawPrice(Canvas canvas, double price, Size size) {
    // Fix the price text display issue
    String priceText;
    if (price == price.toInt()) {
      priceText = '\$${price.toInt()}';
    } else {
      priceText = '\$${price.toStringAsFixed(2)}';
    }
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: priceText,
        style: TextStyle(
          color: Color(0xFF2E7D32),
          fontSize: 22,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.white,
              offset: Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Draw white background behind price for better visibility
    final priceBackground = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    
    final backgroundRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - 85),
        width: textPainter.width + 12,
        height: textPainter.height + 8,
      ),
      Radius.circular(12),
    );
    
    canvas.drawRRect(backgroundRect, priceBackground);
    
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height - 85 - textPainter.height / 2,
      ),
    );
  }

  static void _drawMarkerPointer(Canvas canvas, Size size, bool isActive) {
    final pointerPaint = Paint()
      ..color = isActive ? Color(0xFF4CAF50) : Color(0xFF9E9E9E)
      ..style = PaintingStyle.fill;

    final pointerPath = Path();
    pointerPath.moveTo(size.width / 2, size.height - 5);
    pointerPath.lineTo(size.width / 2 - 10, size.height - 20);
    pointerPath.lineTo(size.width / 2 + 10, size.height - 20);
    pointerPath.close();

    // Shadow for pointer
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
    
    canvas.drawPath(pointerPath.shift(Offset(1, 1)), shadowPaint);
    canvas.drawPath(pointerPath, pointerPaint);
  }

  static void _drawPulseRings(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 10);
    final pulsePaint = Paint()
      ..color = Color(0xFFFF6B6B).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, 30.0 + (i * 15), pulsePaint);
    }
  }

  // Large icon versions that fill the square
  static void _drawRestaurantIconLarge(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    
    // Fork (left side)
    final forkWidth = size * 0.15;
    final forkHeight = size * 0.8;
    
    // Fork handle
    path.addRect(Rect.fromCenter(
      center: Offset(center.dx - size * 0.2, center.dy),
      width: forkWidth * 0.6,
      height: forkHeight,
    ));
    
    // Fork prongs
    for (int i = 0; i < 3; i++) {
      final prongX = center.dx - size * 0.2 - forkWidth * 0.3 + (i * forkWidth * 0.3);
      path.addRect(Rect.fromCenter(
        center: Offset(prongX, center.dy - forkHeight * 0.3),
        width: forkWidth * 0.15,
        height: forkHeight * 0.4,
      ));
    }
    
    // Knife (right side)
    final knifeWidth = size * 0.12;
    final knifeHeight = size * 0.8;
    
    // Knife handle
    path.addRect(Rect.fromCenter(
      center: Offset(center.dx + size * 0.2, center.dy + knifeHeight * 0.25),
      width: knifeWidth,
      height: knifeHeight * 0.5,
    ));
    
    // Knife blade
    final bladePath = Path();
    bladePath.moveTo(center.dx + size * 0.2 - knifeWidth * 0.5, center.dy - knifeHeight * 0.4);
    bladePath.lineTo(center.dx + size * 0.2 + knifeWidth * 0.5, center.dy - knifeHeight * 0.4);
    bladePath.lineTo(center.dx + size * 0.2, center.dy - knifeHeight * 0.2);
    bladePath.close();
    path.addPath(bladePath, Offset.zero);

    paint.style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  static void _drawCafeIconLarge(Canvas canvas, Offset center, double size, Paint paint) {
    final cupWidth = size * 0.6;
    final cupHeight = size * 0.7;
    
    // Cup body
    final cupRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: cupWidth, height: cupHeight),
      Radius.circular(size * 0.1),
    );
    
    paint.style = PaintingStyle.fill;
    canvas.drawRRect(cupRect, paint);
    
    // Handle
    final handlePaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.08;
    
    final handlePath = Path();
    handlePath.addArc(
      Rect.fromCenter(
        center: Offset(center.dx + cupWidth * 0.45, center.dy),
        width: cupWidth * 0.4,
        height: cupHeight * 0.4,
      ),
      -math.pi / 2,
      math.pi,
    );
    canvas.drawPath(handlePath, handlePaint);
    
    // Steam
    final steamPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.04
      ..strokeCap = StrokeCap.round;
    
    for (int i = 0; i < 3; i++) {
      final steamPath = Path();
      final startX = center.dx - cupWidth * 0.2 + i * cupWidth * 0.2;
      final startY = center.dy - cupHeight * 0.4;
      
      steamPath.moveTo(startX, startY);
      steamPath.quadraticBezierTo(
        startX + size * 0.05, startY - size * 0.1,
        startX, startY - size * 0.2,
      );
      steamPath.quadraticBezierTo(
        startX - size * 0.05, startY - size * 0.3,
        startX, startY - size * 0.4,
      );
      
      canvas.drawPath(steamPath, steamPaint);
    }
  }

  static void _drawShopIconLarge(Canvas canvas, Offset center, double size, Paint paint) {
    final bagWidth = size * 0.7;
    final bagHeight = size * 0.8;
    
    // Bag body
    final bagRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: bagWidth, height: bagHeight),
      Radius.circular(size * 0.08),
    );
    
    paint.style = PaintingStyle.fill;
    canvas.drawRRect(bagRect, paint);
    
    // Handles
    final handlePaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.06;
    
    final handlePath = Path();
    handlePath.addArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - bagHeight * 0.25),
        width: bagWidth * 0.5,
        height: bagHeight * 0.3,
      ),
      0,
      math.pi,
    );
    canvas.drawPath(handlePath, handlePaint);
    
    // Shopping bag details
    final detailPaint = Paint()
      ..color = paint.color.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.03;
    
    canvas.drawLine(
      Offset(center.dx - bagWidth * 0.3, center.dy - bagHeight * 0.1),
      Offset(center.dx + bagWidth * 0.3, center.dy - bagHeight * 0.1),
      detailPaint,
    );
  }

  static void _drawActivityIconLarge(Canvas canvas, Offset center, double size, Paint paint) {
    final starPath = Path();
    final points = 5;
    final outerRadius = size * 0.4;
    final innerRadius = size * 0.2;
    
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
    
    paint.style = PaintingStyle.fill;
    canvas.drawPath(starPath, paint);
    
    // Add inner star detail
    final innerStarPath = Path();
    final innerOuterRadius = size * 0.25;
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
      ..color = paint.color.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(innerStarPath, innerPaint);
  }

  static void _drawSalonIconLarge(Canvas canvas, Offset center, double size, Paint paint) {
    paint.style = PaintingStyle.fill;
    
    // Scissor blades
    final bladeSize = size * 0.25;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - size * 0.15, center.dy - size * 0.15),
        width: bladeSize,
        height: bladeSize * 1.5,
      ),
      paint,
    );
    
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + size * 0.15, center.dy + size * 0.15),
        width: bladeSize,
        height: bladeSize * 1.5,
      ),
      paint,
    );
    
    // Scissor pivot and connection
    final pivotPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.08
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      Offset(center.dx - size * 0.1, center.dy - size * 0.1),
      Offset(center.dx + size * 0.1, center.dy + size * 0.1),
      pivotPaint,
    );
    
    // Pivot point
    canvas.drawCircle(center, size * 0.05, paint);
  }

  static void _drawFitnessIconLarge(Canvas canvas, Offset center, double size, Paint paint) {
    paint.style = PaintingStyle.fill;
    
    // Weights
    final weightRadius = size * 0.15;
    canvas.drawCircle(
      Offset(center.dx - size * 0.25, center.dy),
      weightRadius,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size * 0.25, center.dy),
      weightRadius,
      paint,
    );
    
    // Connecting bar
    final barPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.08
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      Offset(center.dx - size * 0.1, center.dy),
      Offset(center.dx + size * 0.1, center.dy),
      barPaint,
    );
    
    // Handle grips
    final gripPaint = Paint()
      ..color = paint.color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.04;
    
    for (int i = -1; i <= 1; i += 2) {
      canvas.drawLine(
        Offset(center.dx + i * size * 0.03, center.dy - size * 0.06),
        Offset(center.dx + i * size * 0.03, center.dy + size * 0.06),
        gripPaint,
      );
    }
  }

  static void _drawDefaultIconLarge(Canvas canvas, Offset center, double size, Paint paint) {
    final tagWidth = size * 0.6;
    final tagHeight = size * 0.5;
    
    final tagPath = Path();
    tagPath.moveTo(center.dx - tagWidth * 0.5, center.dy - tagHeight * 0.5);
    tagPath.lineTo(center.dx + tagWidth * 0.3, center.dy - tagHeight * 0.5);
    tagPath.lineTo(center.dx + tagWidth * 0.5, center.dy);
    tagPath.lineTo(center.dx + tagWidth * 0.3, center.dy + tagHeight * 0.5);
    tagPath.lineTo(center.dx - tagWidth * 0.5, center.dy + tagHeight * 0.5);
    tagPath.close();
    
    paint.style = PaintingStyle.fill;
    canvas.drawPath(tagPath, paint);
    
    // Tag hole
    final holePaint = Paint()
      ..color = paint.color.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(center.dx - tagWidth * 0.2, center.dy),
      size * 0.08,
      holePaint,
    );
  }
}