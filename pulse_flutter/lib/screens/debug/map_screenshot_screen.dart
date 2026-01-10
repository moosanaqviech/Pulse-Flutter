// File: lib/screens/debug/map_screenshot_screen.dart
// CLEAN Screenshot Tool - Just map + markers, no UI

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pulse_flutter/utils/custom_marker_generator.dart';

class MapScreenshotScreen extends StatefulWidget {
  const MapScreenshotScreen({super.key});

  @override
  State<MapScreenshotScreen> createState() => _MapScreenshotScreenState();
}

class _MapScreenshotScreenState extends State<MapScreenshotScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  
  // Toronto downtown center
  static const LatLng _torontoCenter = LatLng(43.6532, -79.3832);
  
  // Evenly distributed Toronto locations for balanced screenshot
  final List<Map<String, dynamic>> _torontoLocations = [
    // Downtown Core (5 locations)
    {'name': 'Financial District', 'lat': 43.6484, 'lng': -79.3814},
    {'name': 'Union Station', 'lat': 43.6451, 'lng': -79.3806},
    {'name': 'St. Lawrence', 'lat': 43.6488, 'lng': -79.3717},
    {'name': 'Harbourfront', 'lat': 43.6396, 'lng': -79.3756},
    {'name': 'Distillery', 'lat': 43.6503, 'lng': -79.3596},
    
    // West (5 locations)
    {'name': 'King West', 'lat': 43.6441, 'lng': -79.3975},
    {'name': 'Queen West', 'lat': 43.6472, 'lng': -79.4010},
    {'name': 'Liberty Village', 'lat': 43.6381, 'lng': -79.4191},
    {'name': 'Ossington', 'lat': 43.6518, 'lng': -79.4234},
    {'name': 'Parkdale', 'lat': 43.6407, 'lng': -79.4342},
    
    // North (5 locations)
    {'name': 'Yorkville', 'lat': 43.6710, 'lng': -79.3912},
    {'name': 'Bloor-Yonge', 'lat': 43.6708, 'lng': -79.3860},
    {'name': 'Annex', 'lat': 43.6675, 'lng': -79.4030},
    {'name': 'Yonge & Eg', 'lat': 43.7075, 'lng': -79.3978},
    {'name': 'St. Clair', 'lat': 43.6784, 'lng': -79.4203},
    
    // East (5 locations)
    {'name': 'Leslieville', 'lat': 43.6632, 'lng': -79.3330},
    {'name': 'Riverdale', 'lat': 43.6653, 'lng': -79.3565},
    {'name': 'Beaches', 'lat': 43.6680, 'lng': -79.2946},
    {'name': 'Danforth', 'lat': 43.6775, 'lng': -79.3506},
    {'name': 'Corktown', 'lat': 43.6540, 'lng': -79.3581},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateBalancedDeals();
    });
  }

  Future<void> _generateBalancedDeals() async {
    setState(() {
      _markers.clear();
    });
    
    final random = math.Random();
    
    // Use ALL 20 locations for even distribution
    for (int i = 0; i < _torontoLocations.length; i++) {
      final location = _torontoLocations[i];
      
      // Small random offset for natural look (within ~50m)
      final latOffset = (random.nextDouble() - 0.5) * 0.001;
      final lngOffset = (random.nextDouble() - 0.5) * 0.001;
      
      final lat = location['lat'] + latOffset;
      final lng = location['lng'] + lngOffset;
      
      // Balanced category distribution
      // 8 restaurants, 6 cafes, 3 shops, 3 activities
      String category;
      int discount;
      String name;
      
      if (i < 8) {
        // Restaurants
        category = 'restaurant';
        discount = 30 + (i % 3) * 10; // 30%, 40%, 50%
        name = 'Restaurant Deal';
      } else if (i < 14) {
        // Cafes
        category = 'cafe';
        discount = 25 + (i % 3) * 10; // 25%, 35%, 45%
        name = 'Cafe Special';
      } else if (i < 17) {
        // Shops
        category = 'shop';
        discount = 30 + (i % 2) * 15; // 30%, 45%
        name = 'Shop Sale';
      } else {
        // Activities
        category = 'activity';
        discount = 35;
        name = 'Activity Deal';
      }
      
      // Create custom marker
      final customMarker = await CustomMarkerGenerator.createDealMarker(
        category: category,
        price: 10.0,
        originalPrice: 20.0,
        discountPercentage: discount,
        isActive: true,
        isPopular: i % 4 == 0, // Every 4th marker is popular
        neonAnimationPhase: 0.0,
      );
      
      _markers.add(
        Marker(
          markerId: MarkerId('deal_$i'),
          position: LatLng(lat, lng),
          icon: customMarker,
          infoWindow: InfoWindow.noText, // No info windows
        ),
      );
    }
    
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: (controller) {
          _mapController = controller;
        },
        initialCameraPosition: const CameraPosition(
          target: _torontoCenter,
          zoom: 12.5, // Good balance showing most markers
        ),
        markers: _markers,
        myLocationButtonEnabled: false,
        myLocationEnabled: false,
        zoomControlsEnabled: false,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        buildingsEnabled: true,
        indoorViewEnabled: false,
        trafficEnabled: false,
      ),
    );
  }
}