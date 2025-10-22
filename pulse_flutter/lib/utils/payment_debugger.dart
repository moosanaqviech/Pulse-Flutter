import 'package:flutter/foundation.dart';

class PaymentDebugger {
  static final Map<String, DateTime> _timestamps = {};
  static final Map<String, Duration> _durations = {};
  
  static void startTimer(String step) {
    _timestamps[step] = DateTime.now();
    debugPrint('⏱️ PAYMENT DEBUG: Starting $step at ${_timestamps[step]!.millisecondsSinceEpoch}ms');
  }
  
  static void endTimer(String step) {
    final start = _timestamps[step];
    if (start != null) {
      final duration = DateTime.now().difference(start);
      _durations[step] = duration;
      debugPrint('✅ PAYMENT DEBUG: $step completed in ${duration.inMilliseconds}ms');
    }
  }
  
  static void logStep(String step, {String? details}) {
    final now = DateTime.now();
    debugPrint('📝 PAYMENT DEBUG: $step ${details != null ? '- $details' : ''} at ${now.millisecondsSinceEpoch}ms');
  }
  
  static void printSummary() {
    debugPrint('\n📊 PAYMENT TIMING SUMMARY:');
    debugPrint('═' * 50);
    
    var totalTime = 0;
    _durations.forEach((step, duration) {
      debugPrint('$step: ${duration.inMilliseconds}ms');
      totalTime += duration.inMilliseconds;
    });
    
    debugPrint('═' * 50);
    debugPrint('🎯 TOTAL PAYMENT TIME: ${totalTime}ms');
    
    if (totalTime > 8000) {
      debugPrint('🚨 WARNING: Payment took longer than 8 seconds!');
    } else if (totalTime > 5000) {
      debugPrint('⚠️ SLOW: Payment took longer than 5 seconds');
    } else {
      debugPrint('✅ GOOD: Payment completed in acceptable time');
    }
    debugPrint('═' * 50);
  }
  
  static void reset() {
    _timestamps.clear();
    _durations.clear();
  }
}