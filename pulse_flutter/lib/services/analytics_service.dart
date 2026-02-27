import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config/database_config.dart';

class AnalyticsService {
  static final FirebaseFirestore _firestore = DatabaseConfig.instance;
  static final Set<String> _viewedDeals = <String>{};  // Prevent duplicate views in same session

  /// Track when user views a deal (Direct Firestore)
  static Future<void> trackDealView(String dealId) async {
    try {
      // Prevent duplicate tracking in same session
      if (_viewedDeals.contains(dealId)) {
        print('🔍 Deal $dealId already viewed in this session, skipping');
        return;
      }

      print('📊 Tracking deal view: $dealId');
      
      // Direct Firestore increment (same as you'd do for likes, etc.)
      await _firestore.collection('deals').doc(dealId).update({
        'viewCount': FieldValue.increment(1),
      });

      // Mark as viewed in this session
      _viewedDeals.add(dealId);
      
      print('✅ Deal view tracked successfully');
    } catch (e) {
      print('❌ Error tracking deal view: $e');
      // Fail silently - don't disrupt user experience
    }
  }

  /// Clear session viewed deals (call on app restart)
  static void clearSessionViews() {
    _viewedDeals.clear();
  }
}