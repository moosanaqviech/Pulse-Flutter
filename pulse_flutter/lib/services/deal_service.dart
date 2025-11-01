import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../models/deal.dart';

class DealService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Deal> _deals = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Deal> get deals => _deals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load active deals from Firestore
  Future<void> loadDeals() async {
    try {
      _setLoading(true);
      _clearError();

      final QuerySnapshot querySnapshot = await _firestore
          .collection('deals')
          .where('isActive', isEqualTo: true)
          .where('expirationTime', isGreaterThan: Timestamp.now())
          .get();

      _deals = querySnapshot.docs
          .map((doc) => Deal.fromFirestore(doc))
          .toList();

      // If no deals found, load sample data
      if (_deals.isEmpty) {
        await _loadSampleDeals();
      }
    } catch (e) {
      _setError('Failed to load deals');
      await _loadSampleDeals(); // Fallback to sample data
      debugPrint('Error loading deals: $e');
    } finally {
      _setLoading(false);
    }
  }

 
 
  // Load sample deals for demo
  Future<void> _loadSampleDeals() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
   /* _deals = [
      Deal(
        id: '1',
        title: 'Coffee Special',
        description: '50% off all lattes until 3PM',
        category: 'cafe',
        latitude: 43.6532,
        longitude: -79.3832,
        originalPrice: 5.99,
        dealPrice: 2.99,
        totalQuantity: 10,
        remainingQuantity: 5,
        businessName: 'The Grind Coffee',
        expirationTime: now + 3600000,
        imageUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=300&h=200&fit=crop',
        isActive: true,
      ),
      Deal(
        id: '2',
        title: 'Happy Hour',
        description: 'Buy 1 get 1 free appetizers',
        category: 'restaurant',
        latitude: 43.6500,
        longitude: -79.3800,
        originalPrice: 12.99,
        dealPrice: 6.50,
        totalQuantity: 20,
        remainingQuantity: 8,
        businessName: 'Pulse Bistro',
        expirationTime: now + 7200000,
        imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=300&h=200&fit=crop',
        isActive: true,
      ),
      Deal(
        id: '3',
        title: 'Flash Sale',
        description: '30% off all items',
        category: 'shop',
        latitude: 43.6560,
        longitude: -79.3900,
        originalPrice: 25.00,
        dealPrice: 17.50,
        totalQuantity: 15,
        remainingQuantity: 12,
        businessName: 'Local Boutique',
        expirationTime: now + 1800000,
        imageUrl: 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=300&h=200&fit=crop',
        isActive: true,
      ),
      Deal(
        id: '4',
        title: 'Yoga Class',
        description: 'Drop-in class available',
        category: 'activity',
        latitude: 43.6480,
        longitude: -79.3750,
        originalPrice: 20.00,
        dealPrice: 15.00,
        totalQuantity: 8,
        remainingQuantity: 3,
        businessName: 'Zen Studio',
        expirationTime: now + 5400000,
        imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=300&h=200&fit=crop',
        isActive: true,
      ),
      Deal(
        id: '5',
        title: 'Pizza Deal',
        description: 'Large pizza for \$15',
        category: 'restaurant',
        latitude: 43.6550,
        longitude: -79.3850,
        originalPrice: 25.00,
        dealPrice: 15.00,
        totalQuantity: 25,
        remainingQuantity: 18,
        businessName: 'Tony\'s Pizza',
        expirationTime: now + 4500000,
        isActive: true,
      ),
      Deal(
        id: '6',
        title: 'Spa Treatment',
        description: 'Relaxing massage 40% off',
        category: 'activity',
        latitude: 43.6520,
        longitude: -79.3780,
        originalPrice: 80.00,
        dealPrice: 48.00,
        totalQuantity: 6,
        remainingQuantity: 2,
        businessName: 'Serenity Spa',
        expirationTime: now + 6300000,
        imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=300&h=200&fit=crop',
        isActive: true,
      ),
    ];
    notifyListeners();*/
  }

  // Get deals by category
  List<Deal> getDealsByCategory(String category) {
    return _deals.where((deal) => deal.category == category).toList();
  }

  // Get deals within radius
  List<Deal> getDealsNearLocation(double lat, double lng, double radiusKm) {
    return _deals.where((deal) {
      final distance = _calculateDistance(lat, lng, deal.latitude, deal.longitude);
      return distance <= radiusKm;
    }).toList();
  }

  // Calculate distance between two points (Haversine formula)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * 
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  // Update deal quantity after purchase
  Future<void> updateDealQuantity(String dealId) async {
    try {
      final dealIndex = _deals.indexWhere((deal) => deal.id == dealId);
      if (dealIndex != -1) {
        _deals[dealIndex] = _deals[dealIndex].copyWith(
          remainingQuantity: _deals[dealIndex].remainingQuantity - 1,
        );
        notifyListeners();

        // Update in Firestore
        await _firestore.collection('deals').doc(dealId).update({
          'remainingQuantity': _deals[dealIndex].remainingQuantity,
        });
      }
    } catch (e) {
      debugPrint('Error updating deal quantity: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}