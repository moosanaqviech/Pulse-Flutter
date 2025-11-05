import 'package:facebook_app_events/facebook_app_events.dart';

class FacebookService {
  static final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();
  static bool _isInitialized = false;

  // Initialize Facebook SDK
  static Future<void> initialize() async {
    try {
      // The SDK should auto-initialize with the AndroidManifest.xml values
      // We just need to configure the app events logger
      await _facebookAppEvents.setAutoLogAppEventsEnabled(true);
      await _facebookAppEvents.setAdvertiserTracking(enabled: true);
      _isInitialized = true;
      print('✅ Facebook SDK initialized successfully');
    } catch (e) {
      print('❌ Facebook SDK initialization failed: $e');
      // Don't throw error - app should work without Facebook
    }
  }

  // Helper method to check if initialized
  static bool get isInitialized => _isInitialized;

  // Track app launches
  static Future<void> trackAppLaunch() async {
    if (!_isInitialized) {
      print('⚠️ Facebook SDK not initialized, skipping trackAppLaunch');
      return;
    }
    
    try {
      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_activate_app',
      );
      print('✅ Facebook: App launch tracked');
    } catch (e) {
      print('❌ Facebook trackAppLaunch error: $e');
    }
  }

  // Track app install (call once after first app launch)
  static Future<void> trackInstall() async {
    if (!_isInitialized) {
      print('⚠️ Facebook SDK not initialized, skipping trackInstall');
      return;
    }
    
    try {
      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_first_time_open',
      );
      print('✅ Facebook: App install tracked');
    } catch (e) {
      print('❌ Facebook trackInstall error: $e');
    }
  }

  // Track custom events for ad optimization
  static Future<void> trackEvent(String eventName, {Map<String, dynamic>? parameters}) async {
    if (!_isInitialized) {
      print('⚠️ Facebook SDK not initialized, skipping trackEvent: $eventName');
      return;
    }
    
    try {
      await _facebookAppEvents.logEvent(
        name: eventName,
        parameters: parameters,
      );
      print('✅ Facebook: Event tracked - $eventName');
    } catch (e) {
      print('❌ Facebook trackEvent error: $e');
    }
  }

  // Track purchases (important for ad optimization)
  static Future<void> trackPurchase({
    required double amount,
    required String currency,
    Map<String, dynamic>? additionalParameters,
  }) async {
    if (!_isInitialized) {
      print('⚠️ Facebook SDK not initialized, skipping trackPurchase');
      return;
    }
    
    try {
      await _facebookAppEvents.logPurchase(
        amount: amount,
        currency: currency,
        parameters: additionalParameters,
      );
      print('✅ Facebook: Purchase tracked - \$${amount} $currency');
    } catch (e) {
      print('❌ Facebook trackPurchase error: $e');
    }
  }

  // Track user registration
  static Future<void> trackRegistration({
    required String method,
    Map<String, dynamic>? additionalParameters,
  }) async {
    if (!_isInitialized) return;
    
    try {
      Map<String, dynamic> parameters = {
        'fb_registration_method': method,
        ...?additionalParameters,
      };
      
      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_complete_registration',
        parameters: parameters,
      );
      print('✅ Facebook: Registration tracked - $method');
    } catch (e) {
      print('❌ Facebook trackRegistration error: $e');
    }
  }

  // For your consumer app - track deal redeemed
  static Future<void> trackDealRedeemed({
    required String dealId,
    required String businessId,
    required double value,
    Map<String, dynamic>? additionalParameters,
  }) async {
    if (!_isInitialized) return;
    
    try {
      Map<String, dynamic> parameters = {
        'deal_id': dealId,
        'business_id': businessId,
        'deal_value': value,
        ...?additionalParameters,
      };
      
      await _facebookAppEvents.logEvent(
        name: 'deal_redeemed',
        parameters: parameters,
      );
      print('✅ Facebook: Deal redeemed tracked - $dealId');
    } catch (e) {
      print('❌ Facebook trackDealRedeemed error: $e');
    }
  }
}