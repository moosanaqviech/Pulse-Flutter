// lib/utils/logo_marker_generator.dart

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class LogoMarkerGenerator {
  // Cache for generated markers to avoid regenerating
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Creates a circular logo marker with optional border and shadow
  static Future<BitmapDescriptor> createLogoMarker({
    required String logoUrl,
    required String cacheKey,
    double size = 150,
    double borderWidth = 3,
    Color borderColor = Colors.white,
    bool showShadow = true,
    bool showPointer = true,
  }) async {
    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Download the image
      final response = await http.get(Uri.parse(logoUrl));
      if (response.statusCode != 200) {
        return _createFallbackMarker(size);
      }

      final Uint8List imageData = response.bodyBytes;
      
      // Decode the image
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageData,
        targetWidth: size.toInt(),
        targetHeight: size.toInt(),
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image logoImage = frameInfo.image;

      // Create the marker with styling
      final marker = await _drawLogoMarker(
        logoImage: logoImage,
        size: size,
        borderWidth: borderWidth,
        borderColor: borderColor,
        showShadow: showShadow,
        showPointer: showPointer,
      );

      // Cache it
      _cache[cacheKey] = marker;
      return marker;
    } catch (e) {
      debugPrint('Error creating logo marker: $e');
      return _createFallbackMarker(size);
    }
  }

  static Future<BitmapDescriptor> _drawLogoMarker({
    required ui.Image logoImage,
    required double size,
    required double borderWidth,
    required Color borderColor,
    required bool showShadow,
    required bool showPointer,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final pointerHeight = showPointer ? 15.0 : 0.0;
    final totalHeight = size + borderWidth * 2 + pointerHeight;
    final totalWidth = size + borderWidth * 2;
    final cornerRadius = 12.0; // Rounded square corner radius
    
    // Main container rect
    final containerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(borderWidth, borderWidth, size, size),
      Radius.circular(cornerRadius),
    );
    
    // Outer rect (with border)
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, totalWidth, size + borderWidth * 2),
      Radius.circular(cornerRadius + borderWidth),
    );

    // Draw shadow
    if (showShadow) {
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(
        outerRect.shift(const Offset(2, 2)),
        shadowPaint,
      );
    }

    // Draw white border/background
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(outerRect, borderPaint);

    // Draw pointer triangle
    if (showPointer) {
      final pointerPath = Path()
        ..moveTo(totalWidth / 2 - 10, size + borderWidth * 2 - 2)
        ..lineTo(totalWidth / 2 + 10, size + borderWidth * 2 - 2)
        ..lineTo(totalWidth / 2, size + borderWidth * 2 + pointerHeight)
        ..close();
      canvas.drawPath(pointerPath, borderPaint);
      
      // Pointer shadow
      if (showShadow) {
        final pointerShadow = Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawPath(pointerPath.shift(const Offset(1, 1)), pointerShadow);
      }
    }

    // Clip to rounded rectangle and draw the logo
    canvas.save();
    final clipPath = Path()..addRRect(containerRect);
    canvas.clipPath(clipPath);
    
    // Draw the logo image
    final srcRect = Rect.fromLTWH(
      0, 0,
      logoImage.width.toDouble(),
      logoImage.height.toDouble(),
    );
    final dstRect = Rect.fromLTWH(borderWidth, borderWidth, size, size);
    canvas.drawImageRect(logoImage, srcRect, dstRect, Paint());
    
    canvas.restore();

    // Convert to BitmapDescriptor
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      totalWidth.toInt(),
      totalHeight.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Fallback marker when logo fails to load
  static Future<BitmapDescriptor> _createFallbackMarker(double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    const pointerHeight = 15.0;
    const borderWidth = 3.0;
    const cornerRadius = 12.0;
    final totalHeight = size + borderWidth * 2 + pointerHeight;
    final totalWidth = size + borderWidth * 2;

    // Outer rounded rect (white background)
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, totalWidth, size + borderWidth * 2),
      const Radius.circular(cornerRadius + borderWidth),
    );
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRRect(outerRect, bgPaint);

    // Pointer
    final pointerPath = Path()
      ..moveTo(totalWidth / 2 - 10, size + borderWidth * 2 - 2)
      ..lineTo(totalWidth / 2 + 10, size + borderWidth * 2 - 2)
      ..lineTo(totalWidth / 2, size + borderWidth * 2 + pointerHeight)
      ..close();
    canvas.drawPath(pointerPath, bgPaint);

    // Inner rounded rect with brand color
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(borderWidth, borderWidth, size, size),
      const Radius.circular(cornerRadius),
    );
    final innerPaint = Paint()..color = const Color(0xFFFF6B35); // Pulse orange
    canvas.drawRRect(innerRect, innerPaint);

    // Store icon
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final center = Offset(totalWidth / 2, (size + borderWidth * 2) / 2);
    final iconSize = size * 0.35;
    final iconRect = Rect.fromCenter(center: center, width: iconSize, height: iconSize);
    canvas.drawRect(iconRect, iconPaint);
    canvas.drawLine(
      Offset(center.dx - iconSize / 2, center.dy - iconSize / 4),
      Offset(center.dx + iconSize / 2, center.dy - iconSize / 4),
      iconPaint,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Create marker with deal count badge
  static Future<BitmapDescriptor> createLogoMarkerWithBadge({
    required String logoUrl,
    required String cacheKey,
    required int dealCount,
    double size = 80,
  }) async {
    if (dealCount <= 1) {
      return createLogoMarker(logoUrl: logoUrl, cacheKey: cacheKey, size: size);
    }

    final cacheKeyWithBadge = '${cacheKey}_count_$dealCount';
    if (_cache.containsKey(cacheKeyWithBadge)) {
      return _cache[cacheKeyWithBadge]!;
    }

    try {
      final response = await http.get(Uri.parse(logoUrl));
      if (response.statusCode != 200) {
        return _createFallbackMarker(size);
      }

      final codec = await ui.instantiateImageCodec(
        response.bodyBytes,
        targetWidth: size.toInt(),
        targetHeight: size.toInt(),
      );
      final frameInfo = await codec.getNextFrame();
      final logoImage = frameInfo.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      const borderWidth = 3.0;
      const pointerHeight = 15.0;
      const badgeSize = 24.0;
      const cornerRadius = 12.0;
      
      final totalHeight = size + borderWidth * 2 + pointerHeight;
      final totalWidth = size + borderWidth * 2 + badgeSize / 2;

      // Outer rounded rect with shadow
      final outerRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size + borderWidth * 2, size + borderWidth * 2),
        const Radius.circular(cornerRadius + borderWidth),
      );
      
      // Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(outerRect.shift(const Offset(2, 2)), shadowPaint);

      // White border
      canvas.drawRRect(outerRect, Paint()..color = Colors.white);

      // Pointer
      final pointerPath = Path()
        ..moveTo((size + borderWidth * 2) / 2 - 10, size + borderWidth * 2 - 2)
        ..lineTo((size + borderWidth * 2) / 2 + 10, size + borderWidth * 2 - 2)
        ..lineTo((size + borderWidth * 2) / 2, size + borderWidth * 2 + pointerHeight)
        ..close();
      canvas.drawPath(pointerPath, Paint()..color = Colors.white);

      // Logo clipped to rounded rect
      canvas.save();
      final clipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(borderWidth, borderWidth, size, size),
        const Radius.circular(cornerRadius),
      );
      canvas.clipPath(Path()..addRRect(clipRect));
      canvas.drawImageRect(
        logoImage,
        Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
        Rect.fromLTWH(borderWidth, borderWidth, size, size),
        Paint(),
      );
      canvas.restore();

      // Badge
      final badgeCenter = Offset(size + borderWidth * 2 - 8, 8);
      canvas.drawCircle(badgeCenter, badgeSize / 2 + 2, Paint()..color = Colors.white);
      canvas.drawCircle(badgeCenter, badgeSize / 2, Paint()..color = const Color(0xFFFF6B35));
      
      // Badge text
      final textPainter = TextPainter(
        text: TextSpan(
          text: dealCount > 9 ? '9+' : dealCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(badgeCenter.dx - textPainter.width / 2, badgeCenter.dy - textPainter.height / 2),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      
      final marker = BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
      _cache[cacheKeyWithBadge] = marker;
      return marker;
    } catch (e) {
      debugPrint('Error creating logo marker with badge: $e');
      return _createFallbackMarker(size);
    }
  }

  /// Clear the cache (call when user logs out or on memory pressure)
  static void clearCache() {
    _cache.clear();
  }
}