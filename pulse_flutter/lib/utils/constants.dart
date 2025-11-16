class Constants {
  // Firebase Configuration
  static const String firebaseProjectId = 'pulse-52aa3';
  static const String firebaseFunctionsUrl = 'https://us-central1-pulse-52aa3.cloudfunctions.net';
  
  // Stripe Configuration (use test keys for development)
  static const String stripePublishableKey = 'pk_test_51SO6Xk5x25xDLFYz4qAoW8OeFxuEvl1wjKWchh99myuZOCpiLRBEgAIlhGckK4MbTgujdGobE6t6v7Vf2KWTD50D00mbKmOTxK';
  static const String stripeLivePublishableKey = 'pk_live_51SO6Xk5x25xDLFYzXJ97mVeLgWVhKGVrCFzrB4CxvHP8JDQz1ms3e68G1QePYsHfZc5xd5mwDsNGV6TATdpYw2LE004d9rr037';
  
  // Currency Configuration
  static const String currency = 'cad'; // Changed from 'usd' to 'cad'
  static const String currencySymbol = '\$'; // CAD uses $ symbol
  static const String merchantCountryCode = 'CA'; // Changed from 'US' to 'CA'
  
  // Google Sign-In Client ID
  static const String googleSignInClientId = 'AIzaSyB140RkQcA2eKLs58sFD-rCvZJt4LAAZI8';
  
  // App Configuration
  static const String appName = 'Pulse';
  static const String appVersion = '1.0.0';
  
  // Default Location (Toronto)
  static const double defaultLatitude = 43.6532;
  static const double defaultLongitude = -79.3832;
  static const double defaultZoom = 12.0;
  
  // Business Logic Constants
  static const double maxSearchRadius = 50.0; // kilometers
  static const int maxDealsPerPage = 20;
  static const Duration dealCacheDuration = Duration(minutes: 5);
  
  // UI Constants
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 28.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
}