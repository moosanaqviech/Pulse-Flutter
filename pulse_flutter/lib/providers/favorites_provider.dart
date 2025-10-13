// pulse_flutter/lib/providers/favorites_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/deal.dart';

class FavoritesProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Deal> _favoriteDeals = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Deal> get favoriteDeals => _favoriteDeals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load favorites from local storage and fetch deal details from Firestore
  Future<void> loadFavorites() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteIds = prefs.getStringList('favorite_deals') ?? [];
      
      if (favoriteIds.isEmpty) {
        _favoriteDeals = [];
        return;
      }

      // Fetch deals from Firestore based on saved IDs
      final List<Deal> loadedDeals = [];
      
      for (String dealId in favoriteIds) {
        try {
          final doc = await _firestore.collection('deals').doc(dealId).get();
          if (doc.exists) {
            final deal = Deal.fromFirestore(doc);
            // Only add if deal is still active and not expired
            if (deal.isActive && !deal.isExpired) {
              loadedDeals.add(deal);
            }
          }
        } catch (e) {
          debugPrint('Error loading favorite deal $dealId: $e');
          // Continue loading other deals even if one fails
        }
      }
      
      _favoriteDeals = loadedDeals;
      
      // Clean up any invalid deal IDs from local storage
      if (loadedDeals.length != favoriteIds.length) {
        await _cleanupInvalidFavorites();
      }
      
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      _errorMessage = 'Failed to load favorites: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a deal to favorites
  Future<void> addFavorite(Deal deal) async {
    try {
      if (!_favoriteDeals.any((d) => d.id == deal.id)) {
        _favoriteDeals.add(deal);
        await _saveFavoritesToStorage();
        notifyListeners();
        
        debugPrint('Added ${deal.title} to favorites');
      }
    } catch (e) {
      debugPrint('Error adding favorite: $e');
      _errorMessage = 'Failed to add to favorites: $e';
      notifyListeners();
    }
  }

  /// Remove a deal from favorites
  Future<void> removeFavorite(String dealId) async {
    try {
      final removedDeal = _favoriteDeals.firstWhere(
        (deal) => deal.id == dealId,
        orElse: () => throw Exception('Deal not found in favorites'),
      );
      
      _favoriteDeals.removeWhere((deal) => deal.id == dealId);
      await _saveFavoritesToStorage();
      notifyListeners();
      
      debugPrint('Removed ${removedDeal.title} from favorites');
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      _errorMessage = 'Failed to remove from favorites: $e';
      notifyListeners();
    }
  }

  /// Clear all favorites
  Future<void> clearAllFavorites() async {
    try {
      _favoriteDeals.clear();
      await _saveFavoritesToStorage();
      notifyListeners();
      
      debugPrint('Cleared all favorites');
    } catch (e) {
      debugPrint('Error clearing favorites: $e');
      _errorMessage = 'Failed to clear favorites: $e';
      notifyListeners();
    }
  }

  /// Check if a deal is in favorites
  bool isFavorite(String dealId) {
    return _favoriteDeals.any((deal) => deal.id == dealId);
  }

  /// Toggle favorite status of a deal
  Future<void> toggleFavorite(Deal deal) async {
    if (isFavorite(deal.id!)) {
      await removeFavorite(deal.id!);
    } else {
      await addFavorite(deal);
    }
  }

  /// Get favorite count
  int get favoriteCount => _favoriteDeals.length;

  /// Check if favorites list is empty
  bool get isEmpty => _favoriteDeals.isEmpty;

  /// Save favorite deal IDs to local storage
  Future<void> _saveFavoritesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteIds = _favoriteDeals
          .map((deal) => deal.id!)
          .where((id) => id.isNotEmpty)
          .toList();
      await prefs.setStringList('favorite_deals', favoriteIds);
    } catch (e) {
      debugPrint('Error saving favorites to storage: $e');
      throw Exception('Failed to save favorites');
    }
  }

  /// Clean up invalid deal IDs from local storage
  Future<void> _cleanupInvalidFavorites() async {
    try {
      await _saveFavoritesToStorage();
      debugPrint('Cleaned up invalid favorite deal IDs');
    } catch (e) {
      debugPrint('Error cleaning up favorites: $e');
    }
  }

  /// Refresh favorites by reloading from Firestore
  Future<void> refreshFavorites() async {
    await loadFavorites();
  }

  /// Get favorites by category
  List<Deal> getFavoritesByCategory(String category) {
    return _favoriteDeals
        .where((deal) => deal.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  /// Get recently added favorites (last 10)
  List<Deal> get recentFavorites {
    final sortedFavorites = List<Deal>.from(_favoriteDeals);
    // Note: You might want to add a 'favoritedAt' timestamp to track when deals were favorited
    // For now, we'll just return the last 10 deals
    return sortedFavorites.take(10).toList();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}