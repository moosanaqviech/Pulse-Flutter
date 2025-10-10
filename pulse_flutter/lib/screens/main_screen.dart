import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pulse_flutter/screens/purchase_history_screen.dart';

import '../services/deal_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../models/deal.dart';
import '../services/purchase_service.dart';
import '../widgets/deal_bottom_sheet.dart';
import 'checkout_screen.dart';

import '../utils/custom_marker_generator.dart';

import '../screens/voucher_list_screen.dart';
import "../widgets/voucher_quick access.dart";

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}



class _MainScreenState extends State<MainScreen> {
  // Add GlobalKey for Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Deal? _selectedDeal;
  
  // Default location (Toronto)
  static const LatLng _defaultLocation = LatLng(43.6532, -79.3832);
  LatLng _currentLocation = _defaultLocation;

  Timer? _neonAnimationTimer;
  double _neonAnimationPhase = 0.0;
  final Set<String> _animatedMarkerIds = {};

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _startNeonAnimation();
  }


  @override
  void dispose() {
    _neonAnimationTimer?.cancel();
    super.dispose();
  }
void _startNeonAnimation() {
    _neonAnimationTimer = Timer.periodic(Duration(milliseconds: 50), (timer) {
      setState(() {
        _neonAnimationPhase = (_neonAnimationPhase + 0.02) % 1.0;
      });
      
      // Only update animated markers to save performance
      if (_animatedMarkerIds.isNotEmpty) {
        _updateAnimatedMarkers();
      }
    });
  }

  Future<void> _updateAnimatedMarkers() async {
    final dealService = Provider.of<DealService>(context, listen: false);
    
    for (final deal in dealService.deals) {
      if (_animatedMarkerIds.contains(deal.id)) {
        final customMarker = await CustomMarkerGenerator.createDealMarker(
          category: deal.category,
          price: deal.dealPrice,
          originalPrice: deal.originalPrice,
          discountPercentage: deal.discountPercentage,
          isActive: deal.isActive && !deal.isExpired && !deal.isSoldOut,
          isPopular: false,
          neonAnimationPhase: _neonAnimationPhase,
        );
        
        // Update the marker
        _markers.removeWhere((marker) => marker.markerId.value == deal.id);
        _markers.add(
          Marker(
            markerId: MarkerId(deal.id),
            position: LatLng(deal.latitude, deal.longitude),
            icon: customMarker,
            onTap: () => _onMarkerTap(deal),
            infoWindow: InfoWindow.noText,
          ),
        );
      }
    }
    
    if (mounted) setState(() {});
  }


  Future<void> _initializeScreen() async {
    final dealService = Provider.of<DealService>(context, listen: false);
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    // Load deals
    await dealService.loadDeals();
    
    // Get current location
    try {
      final position = await locationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation, 15.0),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    
    _updateMarkers();
  }


  Future<void> _updateMarkers() async {
  final dealService = Provider.of<DealService>(context, listen: false);
  
  setState(() {
    _markers.clear();
  });
  
  for (final deal in dealService.deals) {
    // Determine if this deal should have neon effects
    final shouldAnimate = deal.discountPercentage >= 50;
    
    // Create custom marker with neon animation for special deals
    final customMarker = await CustomMarkerGenerator.createDealMarker(
      category: deal.category,
      price: deal.dealPrice,
      originalPrice: deal.originalPrice,
      discountPercentage: deal.discountPercentage,
      isActive: deal.isActive && !deal.isExpired && !deal.isSoldOut,
      isPopular: true,
      neonAnimationPhase: shouldAnimate ? _neonAnimationPhase : 0.0,
    );
    
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(deal.id),
          position: LatLng(deal.latitude, deal.longitude),
          icon: customMarker,
          onTap: () => _onMarkerTap(deal),
          infoWindow: InfoWindow.noText,
        ),
      );
    });
  }
}
  BitmapDescriptor _getMarkerIcon(String category) {
    switch (category.toLowerCase()) {
      case 'restaurant':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'cafe':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'shop':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 'activity':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }

  void _onMarkerTap(Deal deal) {
    setState(() {
      _selectedDeal = deal;
    });
    
    _showDealBottomSheet(deal);
  }

  void _showDealBottomSheet(Deal deal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DealBottomSheet(
        deal: deal,
        onPurchase: () => _navigateToCheckout(deal),
      ),
    );
  }

  void _navigateToCheckout(Deal deal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(deal: deal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Assign the key to Scaffold
      appBar: AppBar(
        title: const Text(
          'Pulse',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            // Open the drawer using the GlobalKey
            _scaffoldKey.currentState?.openDrawer();
          },
          tooltip: 'Menu',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearch,
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<DealService>(
        builder: (context, dealService, _) {
          if (dealService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (dealService.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    dealService.errorMessage!,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => dealService.loadDeals(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 12.0,
            ),
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onTap: (_) {
              if (_selectedDeal != null) {
                setState(() {
                  _selectedDeal = null;
                });
              }
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnCurrentLocation,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.my_location),
      ),
      drawer: _buildDrawer(),
    );
  }

  Future<void> _centerOnCurrentLocation() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    try {
      final position = await locationService.getCurrentLocation();
      if (position != null && _mapController != null) {
        final newLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = newLocation;
        });
        
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(newLocation, 15.0),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to get current location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSearch() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search functionality coming soon!')),
    );
  }

 Widget _buildDrawer() {
  return Drawer(
    child: Consumer<AuthService>(
      builder: (context, authService, _) {
        final user = authService.currentUser;
        
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? 'Guest User'),
              accountEmail: Text(user?.email ?? 'Not signed in'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (user?.displayName?.isNotEmpty == true)
                      ? user!.displayName![0].toUpperCase()
                      : 'G',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            
            // NEW: Add My Vouchers menu item
            ListTile(
              leading: const Icon(Icons.local_offer),
              title: const Text('My Vouchers'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VoucherListScreen(),
                  ),
                );
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Navigate to favorites
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Favorites feature coming soon!')),
                );
              },
            ),
            
            // UPDATE: Change this from "Purchase History" to "Transaction History"
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Transaction History'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VoucherListScreen(),
                  ),
                );
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Navigate to settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings feature coming soon!')),
                );
              },
            ),
            const Divider(),
            if (user != null)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await authService.signOut();
                },
              ),
            if (user == null)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign In'),
                onTap: () {
                  Navigator.of(context).pop();
                  // Will automatically navigate to login screen via AppWrapper
                },
              ),
          ],
        );
      },
    ),
  );

  }

Widget _buildVoucherOverlay() {
  return Positioned(
    top: 100, // Adjust based on your app bar height
    left: 16,
    right: 16,
    child: Consumer<PurchaseService>(
      builder: (context, purchaseService, _) {
        if (purchaseService.activePurchases.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${purchaseService.activePurchases.length} active voucher${purchaseService.activePurchases.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const VoucherListScreen(),
                      ),
                    );
                  },
                  child: const Text('View'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

}