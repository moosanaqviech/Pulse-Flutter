// Alternative approach: Create a mixin for reusable distance calculation
// File: lib/mixins/distance_calculator_mixin.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../models/deal.dart';

mixin DistanceCalculatorMixin<T extends StatefulWidget> on State<T> {
  double? _calculatedDistance;
  bool _isCalculatingDistance = false;
  String _distanceDisplayText = 'Calculating...';
  Timer? _distanceUpdateTimer;

  double? get calculatedDistance => _calculatedDistance;
  bool get isCalculatingDistance => _isCalculatingDistance;
  String get distanceDisplayText => _distanceDisplayText;

  /// Initialize distance calculation with optional auto-refresh
  void initDistanceCalculation(Deal deal, {bool autoRefresh = false}) {
    _calculateDistanceForDeal(deal);
    
    if (autoRefresh) {
      // Update distance every 30 seconds
      _distanceUpdateTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _calculateDistanceForDeal(deal),
      );
    }
  }

  /// Calculate distance to deal location
  Future<void> _calculateDistanceForDeal(Deal deal) async {
    if (!mounted) return;
    
    setState(() {
      _isCalculatingDistance = true;
      if (_calculatedDistance == null) {
        _distanceDisplayText = 'Calculating...';
      }
    });

    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      
      // Check if we have location permission first
      if (!await locationService.hasLocationPermission()) {
        setState(() {
          _distanceDisplayText = 'Location permission needed';
          _isCalculatingDistance = false;
        });
        return;
      }

      // Get user's current location
      final userPosition = await locationService.getCurrentLocation();
      
      if (userPosition != null && mounted) {
        final distanceKm = locationService.calculateDistance(
          userPosition.latitude,
          userPosition.longitude,
          deal.latitude,
          deal.longitude,
        );
        
        setState(() {
          _calculatedDistance = distanceKm;
          _distanceDisplayText = _formatDistanceText(distanceKm);
          _isCalculatingDistance = false;
        });
      } else {
        setState(() {
          _distanceDisplayText = 'Location unavailable';
          _isCalculatingDistance = false;
        });
      }
    } catch (e) {
      debugPrint('Error calculating distance: $e');
      if (mounted) {
        setState(() {
          _distanceDisplayText = _handleDistanceError(e);
          _isCalculatingDistance = false;
        });
      }
    }
  }

  /// Format distance for display with smart units
  String _formatDistanceText(double distanceKm) {
    if (distanceKm < 0.1) {
      return 'Very close';
    } else if (distanceKm < 1.0) {
      final distanceMeters = (distanceKm * 1000).round();
      return '${distanceMeters}m away';
    } else if (distanceKm < 10.0) {
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else if (distanceKm < 100.0) {
      return '${distanceKm.round()}km away';
    } else {
      return 'Far away';
    }
  }

  /// Handle different types of distance calculation errors
  String _handleDistanceError(dynamic error) {
    if (error is LocationServiceDisabledException) {
      return 'Enable location services';
    } else if (error is PermissionDeniedException) {
      return 'Location permission denied';
    } else if (error is TimeoutException) {
      return 'Location timeout';
    } else {
      return 'Distance unavailable';
    }
  }

  /// Get estimated travel time based on distance
  String getEstimatedTravelTime() {
    if (_calculatedDistance == null) return '';
    
    final distance = _calculatedDistance!;
    
    if (distance < 0.5) {
      final walkingTimeMinutes = (distance / 5.0 * 60).round();
      return '${walkingTimeMinutes}min walk';
    } else if (distance < 2.0) {
      final walkingTimeMinutes = (distance / 5.0 * 60).round();
      final bikingTimeMinutes = (distance / 15.0 * 60).round();
      return '${walkingTimeMinutes}min walk • ${bikingTimeMinutes}min bike';
    } else {
      final drivingTimeMinutes = (distance / 30.0 * 60).round();
      return '${drivingTimeMinutes}min drive';
    }
  }

  /// Manually refresh distance
  Future<void> refreshDistance(Deal deal) async {
    await _calculateDistanceForDeal(deal);
  }

  /// Request location permission if needed
  Future<void> requestLocationPermission() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    await locationService.getCurrentLocation();
  }

  /// Build distance display widget
  Widget buildDistanceWidget(Deal deal, {VoidCallback? onRefresh}) {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: 16,
          color: _getDistanceColor(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _distanceDisplayText,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_calculatedDistance != null && _calculatedDistance! < 50) ...[
                const SizedBox(height: 2),
                Text(
                  getEstimatedTravelTime(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_distanceDisplayText.contains('permission') || 
            _distanceDisplayText.contains('services'))
          InkWell(
            onTap: requestLocationPermission,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.settings,
                size: 16,
                color: Colors.orange.shade600,
              ),
            ),
          )
        else if (!_isCalculatingDistance)
          InkWell(
            onTap: onRefresh ?? () => refreshDistance(deal),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.refresh,
                size: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        if (_isCalculatingDistance)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  /// Get color based on distance status
  Color _getDistanceColor() {
    if (_distanceDisplayText.contains('permission') || 
        _distanceDisplayText.contains('services') ||
        _distanceDisplayText.contains('unavailable')) {
      return Colors.orange.shade600;
    } else if (_calculatedDistance != null && _calculatedDistance! < 1.0) {
      return Colors.green.shade600;
    } else {
      return Colors.red.shade600;
    }
  }

  /// Clean up timers
  void disposeDistanceCalculation() {
    _distanceUpdateTimer?.cancel();
  }

  @override
  void dispose() {
    disposeDistanceCalculation();
    super.dispose();
  }
}