import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating.dart';

class RatingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  String? _errorMessage;
  List<Rating> _userRatings = [];
  Map<String, Rating> _userBusinessRatings = {}; // businessId -> Rating

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Rating> get userRatings => _userRatings;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Submit or update a rating for a business
  /// Submit or update a rating for a business
Future<bool> submitRating({
  required String userId,
  required String businessId,
  required String businessName,
  required int stars,
  String? dealId,
  String? dealTitle,
  String? comment,
}) async {
  try {
    _setLoading(true);
    _setError(null);

    final existingRating = await getUserRatingForBusiness(userId, businessId);

    if (existingRating != null) {
      // Update existing rating - use FieldValue.serverTimestamp()
      await _firestore.collection('ratings').doc(existingRating.id).update({
        'stars': stars,
        'comment': comment,
        'dealId': dealId,
        'dealTitle': dealTitle,
        'updatedAt': FieldValue.serverTimestamp(), // ✅ Server timestamp
      });
      
      debugPrint('✅ Rating updated for business: $businessName');
    } else {
      // Create new rating
      final rating = Rating(
        id: '',
        userId: userId,
        businessId: businessId,
        businessName: businessName,
        dealId: dealId,
        dealTitle: dealTitle,
        stars: stars,
        comment: comment,
        createdAt: DateTime.now(), // Will be converted to Timestamp
      );

      // When adding to Firestore, can also use server timestamp
      final docData = rating.toMap();
      docData['createdAt'] = FieldValue.serverTimestamp(); // ✅ Override with server time
      
      await _firestore.collection('ratings').add(docData);
      debugPrint('✅ New rating created for business: $businessName');
    }
    
    await _updateBusinessRating(businessId);
    await loadUserRatings(userId);
    
    _setLoading(false);
    return true;
  } catch (e) {
    debugPrint('❌ Failed to submit rating: $e');
    _setError('Failed to submit rating: $e');
    _setLoading(false);
    return false;
  }
}
  /// Update the business's average rating based on all ratings
  Future<void> _updateBusinessRating(String businessId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('ratings')
          .where('businessId', isEqualTo: businessId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        // No ratings yet, set to null
        await _firestore.collection('businesses').doc(businessId).update({
          'averageRating': null,
          'totalRatings': 0,
        });
        return;
      }

      final ratings = ratingsSnapshot.docs
          .map((doc) => Rating.fromMap(doc.data(), doc.id))
          .toList();

      final totalStars = ratings.fold<int>(0, (sum, r) => sum + r.stars);
      final avgRating = totalStars / ratings.length;
      
      // Update business document
      await _firestore.collection('businesses').doc(businessId).update({
        'averageRating': avgRating,
        'totalRatings': ratings.length,
      });

      debugPrint('✅ Business rating updated: $avgRating (${ratings.length} ratings)');
    } catch (e) {
      debugPrint('❌ Failed to update business rating: $e');
    }
  }

  /// Load all ratings by a specific user
  Future<void> loadUserRatings(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      final snapshot = await _firestore
          .collection('ratings')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _userRatings = snapshot.docs
          .map((doc) => Rating.fromMap(doc.data(), doc.id))
          .toList();

      // Build quick lookup map
      _userBusinessRatings.clear();
      for (var rating in _userRatings) {
        _userBusinessRatings[rating.businessId] = rating;
      }

      debugPrint('✅ Loaded ${_userRatings.length} user ratings');
      _setLoading(false);
    } catch (e) {
      debugPrint('❌ Failed to load user ratings: $e');
      _setError('Failed to load ratings: $e');
      _setLoading(false);
    }
  }

  /// Get user's rating for a specific business (if exists)
  Future<Rating?> getUserRatingForBusiness(String userId, String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('ratings')
          .where('userId', isEqualTo: userId)
          .where('businessId', isEqualTo: businessId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      
      return Rating.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      debugPrint('❌ Failed to get user rating for business: $e');
      return null;
    }
  }

  /// Check if user has rated a business (from cached data)
  bool hasUserRatedBusiness(String businessId) {
    return _userBusinessRatings.containsKey(businessId);
  }

  /// Get cached rating for a business
  Rating? getCachedRatingForBusiness(String businessId) {
    return _userBusinessRatings[businessId];
  }

  /// Get all ratings for a specific business (for display)
  Future<List<Rating>> getBusinessRatings(String businessId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('ratings')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Rating.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to load business ratings: $e');
      return [];
    }
  }

  /// Delete a rating
  Future<bool> deleteRating(String ratingId, String businessId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _firestore.collection('ratings').doc(ratingId).delete();
      
      // Update business rating after deletion
      await _updateBusinessRating(businessId);
      
      // Remove from local cache
      _userRatings.removeWhere((r) => r.id == ratingId);
      _userBusinessRatings.remove(businessId);
      
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete rating: $e');
      _setError('Failed to delete rating: $e');
      _setLoading(false);
      return false;
    }
  }
}