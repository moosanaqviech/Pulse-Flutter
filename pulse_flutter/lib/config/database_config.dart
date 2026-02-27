import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class DatabaseConfig {
  static FirebaseFirestore get instance {
    if (kDebugMode) {
      // Development: use default database (has existing test data)
      return FirebaseFirestore.instance;
    } else {
      // Production: use pulse-prod database (clean slate for launch)
      return FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'pulse-prod',
      );
    }
  }
}