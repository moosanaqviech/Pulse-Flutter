import 'package:geocoding/geocoding.dart';

import '../models/deal.dart';

class TaxService {
  // Canadian tax rates by province
  static const Map<String, double> TAX_RATES = {
    'AB': 0.05,   // Alberta - 5% GST
    'BC': 0.12,   // British Columbia - 5% GST + 7% PST
    'MB': 0.12,   // Manitoba - 5% GST + 7% PST
    'NB': 0.15,   // New Brunswick - 15% HST
    'NL': 0.15,   // Newfoundland - 15% HST
    'NT': 0.05,   // Northwest Territories - 5% GST
    'NS': 0.15,   // Nova Scotia - 15% HST
    'NU': 0.05,   // Nunavut - 5% GST
    'ON': 0.13,   // Ontario - 13% HST
    'PE': 0.15,   // Prince Edward Island - 15% HST
    'QC': 0.14975, // Quebec - 5% GST + 9.975% QST
    'SK': 0.11,   // Saskatchewan - 5% GST + 6% PST
    'YT': 0.05,   // Yukon - 5% GST
  };
  
  static Future<String?> getProvinceFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        // Try administrative area first (usually province)
        if (placemark.administrativeArea != null) {
          final province = _normalizeProvinceName(placemark.administrativeArea!);
          if (province != null) return province;
        }
        
        // Try sub administrative area as fallback
        if (placemark.subAdministrativeArea != null) {
          final province = _normalizeProvinceName(placemark.subAdministrativeArea!);
          if (province != null) return province;
        }
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
    }
    
    return null;
  }

  // Extract province from coordinates using reverse geocoding or business address
  static Future<String> getProvinceFromDeal(Deal deal) async {
    try {
      // Option 1: Parse from business address if it contains province
      final address = deal.businessAddress.toUpperCase();
      for (String province in TAX_RATES.keys) {
        if (address.contains(province) || 
            address.contains(_getProvinceName(province).toUpperCase())) {
          return province;
        }
      }
      
      // Option 2: Use coordinates for reverse geocoding (if needed)
      // You could use geocoding package here if address parsing fails
      
      // Default to Ontario for Toronto launch
      return 'ON';
    } catch (e) {
      print('Error detecting province: $e');
      return 'ON'; // Safe default
    }
  }
  
  static String _getProvinceName(String code) {
    const provinceNames = {
      'AB': 'Alberta', 'BC': 'British Columbia', 'MB': 'Manitoba',
      'NB': 'New Brunswick', 'NL': 'Newfoundland', 'NT': 'Northwest Territories',
      'NS': 'Nova Scotia', 'NU': 'Nunavut', 'ON': 'Ontario',
      'PE': 'Prince Edward Island', 'QC': 'Quebec', 'SK': 'Saskatchewan',
      'YT': 'Yukon',
    };
    return provinceNames[code] ?? code;
  }
  
  // Calculate tax amount
  static double calculateTax(double amount, String province) {
    final taxRate = TAX_RATES[province.toUpperCase()] ?? TAX_RATES['ON']!;
    return amount * taxRate;
  }
  
  // Get tax rate for display
  static double getTaxRate(String province) {
    return TAX_RATES[province.toUpperCase()] ?? TAX_RATES['ON']!;
  }
  
  // Get tax name for display
  static String getTaxName(String province) {
    const taxNames = {
      'AB': 'GST', 'BC': 'GST + PST', 'MB': 'GST + PST',
      'NB': 'HST', 'NL': 'HST', 'NT': 'GST',
      'NS': 'HST', 'NU': 'GST', 'ON': 'HST',
      'PE': 'HST', 'QC': 'GST + QST', 'SK': 'GST + PST',
      'YT': 'GST',
    };
    return taxNames[province.toUpperCase()] ?? 'HST';
  }
  

    // Helper: Normalize province names from geocoding to province codes
  static String? _normalizeProvinceName(String provinceName) {
    final nameUpper = provinceName.toUpperCase();
    
    const provinceNameToCode = {
      'ALBERTA': 'AB',
      'BRITISH COLUMBIA': 'BC', 
      'MANITOBA': 'MB',
      'NEW BRUNSWICK': 'NB',
      'NEWFOUNDLAND AND LABRADOR': 'NL',
      'NORTHWEST TERRITORIES': 'NT',
      'NOVA SCOTIA': 'NS',
      'NUNAVUT': 'NU',
      'ONTARIO': 'ON',
      'PRINCE EDWARD ISLAND': 'PE',
      'QUEBEC': 'QC',
      'SASKATCHEWAN': 'SK',
      'YUKON': 'YT',
      // Also handle some variations
      'NEWFOUNDLAND': 'NL',
      'YUKON TERRITORY': 'YT',
      'PEI': 'PE',
    };
    
    return provinceNameToCode[nameUpper];
  }
}
