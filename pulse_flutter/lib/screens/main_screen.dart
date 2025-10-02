import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../services/deal_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../models/deal.dart';
import '../widgets/deal_info_window.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/deal_bottom_sheet.dart';
import 'checkout_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Deal? _selectedDeal;
  
  // Default location (Toronto)
  static const LatLng _defaultLocation = LatLng(43.6532, -79.3832);
  LatLng _currentLocation = _defaultLocation;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
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

  void _updateMarkers() {
    final dealService = Provider.of<DealService>(context, listen: false);
    
    setState(() {
      _markers.clear();
      
      for (final deal in dealService.deals) {
        _markers.add(
          Marker(
            markerId: MarkerId(deal.id),
            position: LatLng(deal.latitude, deal.longitude),
            icon: _getMarkerIcon(deal.category),
            onTap: () => _onMarkerTap(deal),
            infoWindow: InfoWindow(
              title: deal.title,
              snippet: deal.businessName,
            ),
          ),
        );
      }
    });
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
      appBar: CustomAppBar(
        onMenuTap: _showDrawer,
        onSearchTap: _showSearch,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to get current location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDrawer() {
    Scaffold.of(context).openDrawer();
  }

  void _showSearch() {
    // TODO: Implement search functionality
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
              ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('Favorites'),
                onTap: () {
                  Navigator.of(context).pop();
                  // TODO: Navigate to favorites
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Purchase History'),
                onTap: () {
                  Navigator.of(context).pop();
                  // TODO: Navigate to purchase history
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  // TODO: Navigate to settings
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
            ],
          );
        },
      ),
    );
  }
}