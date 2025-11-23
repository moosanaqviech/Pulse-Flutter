import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../services/deal_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import '../models/deal.dart';
import '../widgets/deal_bottom_sheet.dart';
import '../utils/custom_marker_generator.dart';
import '../widgets/deal_preview_carousel.dart';
import 'checkout_screen.dart';
import 'favorite_screen.dart';
import 'voucher_list_screen.dart';
import 'purchase_history_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Deal? _selectedDeal;
  
  // Default location (Toronto)
  static const LatLng _defaultLocation = LatLng(43.6532, -79.3832);
  LatLng _currentLocation = _defaultLocation;
  
  int _currentBottomIndex = 0; // 0 = Map, 1 = My Vouchers, 2 = Settings

  // Neon animation
  //Timer? _neonAnimationTimer;
  //double _neonAnimationPhase = 0.0;
  //final Set<String> _animatedMarkerIds = {};

  @override
  void initState() {
    super.initState();
    //_initializeScreen();
    //_startNeonAnimation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dealService = Provider.of<DealService>(context, listen: false);
      dealService.startListening(); // ✅ Start real-time updates
      //_initializeLocation();
    });
  }

  @override
 /* void dispose() {
    _neonAnimationTimer?.cancel();
    super.dispose();
  }

  void _startNeonAnimation() {
    _neonAnimationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _neonAnimationPhase = (_neonAnimationPhase + 0.02) % 1.0;
      });
      
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
          isPopular: true,
          neonAnimationPhase: _neonAnimationPhase,
        );
        
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
  }*/

  Future<void> _initializeScreen() async {
    
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    
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
    
  }

 Future<void> _updateMarkers() async {
  final dealService = Provider.of<DealService>(context, listen: false);
  
  setState(() {
    _markers.clear();
  });
  
  // Group deals by location (businesses with same lat/lng)
  final Map<String, List<Deal>> dealsByLocation = {};
  
  for (final deal in dealService.deals) {
    final locationKey = '${deal.latitude}_${deal.longitude}';
    dealsByLocation.putIfAbsent(locationKey, () => []).add(deal);
  }
  
  // Create markers for each location
  for (final entry in dealsByLocation.entries) {
    final deals = entry.value;
    final firstDeal = deals.first;
    final dealCount = deals.length;
    
    // Use the highest discount for marker styling
    final maxDiscount = deals.map((d) => d.discountPercentage).reduce((a, b) => a > b ? a : b);
    final shouldAnimate = maxDiscount >= 50;
    
    // Create marker with deal count badge
    final customMarker = await CustomMarkerGenerator.createDealMarkerWithCount(
      category: firstDeal.category,
      price: firstDeal.dealPrice,
      originalPrice: firstDeal.originalPrice,
      discountPercentage: maxDiscount,
      isActive: deals.any((d) => d.isActive && !d.isExpired && !d.isSoldOut),
      isPopular: shouldAnimate,
      dealCount: dealCount, // Pass the count
      neonAnimationPhase: 0.0,
    );
    
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(entry.key),
          position: LatLng(firstDeal.latitude, firstDeal.longitude),
          icon: customMarker,
          onTap: () => _onMarkerTap(deals), // Pass list of deals
          infoWindow: InfoWindow.noText,
        ),
      );
    });
  }
}

void _onMarkerTap(dynamic dealsOrDeal) {
  // Handle both single deal and multiple deals
  final List<Deal> deals = dealsOrDeal is List<Deal> ? dealsOrDeal : [dealsOrDeal as Deal];
  
  if (deals.length == 1) {
    // Single deal - go directly to full bottom sheet
    setState(() {
      _selectedDeal = deals.first;
    });
    _showDealBottomSheet(deals.first);
  } else {
    // Multiple deals - show preview carousel first
    _showDealPreviewCarousel(deals);
  }
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
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      body: _buildBodyBasedOnBottomNavigation(),
      bottomNavigationBar: _buildBottomNavigationBar(),
      //drawer: _buildDrawer(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Text(
            'Pulse',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'BETA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      // ⭐ REMOVE the drawer button - DELETE these 5 lines:
      // leading: IconButton(
      //   icon: const Icon(Icons.menu, color: Colors.white),
      //   onPressed: () {
      //     _scaffoldKey.currentState?.openDrawer();
      //   },
      //   tooltip: 'Menu',
      // ),
      automaticallyImplyLeading: false, // ⭐ ADD THIS LINE instead
      actions: [
        // Only show these actions when on the map screen
        if (_currentBottomIndex == 0) ...[  // ⭐ ADD THIS CONDITION
          // Deal counter
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_markers.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'DEALS',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearch,
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: _showNotifications,
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
        ], // ⭐ CLOSE the conditional
      ],
    );
  }

  Widget _buildBodyWithDidChangeDependencies() {
    // This completely avoids the Consumer rebuild issue
    
    final dealService = Provider.of<DealService>(context);
    
    // Show loading state
    if (dealService.isLoading && dealService.deals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading deals...'),
          ],
        ),
      );
    }

    // Show error state  
    if (dealService.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade400),
            SizedBox(height: 16),
            Text(dealService.errorMessage!),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => dealService.startListening(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Return the map
    return _buildMap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // ✅ This method is called when DealService changes
    final dealService = Provider.of<DealService>(context);
    
    debugPrint('🔄 didChangeDependencies: ${dealService.deals.length} deals');
    
    // Update markers when deals change AND map is ready
    if (_mapController != null && dealService.deals.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateMarkers();
      });
    }
  }
 

  // ✅ UPDATED: Your existing map build logic
  Widget _buildMap() {
    
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        debugPrint('🗺️ GoogleMap: Map created');
        _mapController = controller;
        
        _initializeScreen();
        
        // Initial marker update
        _updateMarkers();
      },
      initialCameraPosition: CameraPosition(
        target: _currentLocation,
        zoom: 15.0,
      ),
      markers: Set<Marker>.from(_markers),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      // Your other existing map properties...
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Consumer<DealService>(
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
              myLocationButtonEnabled: false, // We have custom location button
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

        // Bottom Action Buttons
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: _buildBottomActionButtons(),
        ),

        // Custom location button
        Positioned(
          bottom: 140,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _centerOnCurrentLocation,
            child: const Icon(
              Icons.my_location,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionButtons() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.near_me,
              label: 'NEARBY',
              color: Colors.blue,
              onPressed: _showNearbyDeals,
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildActionButton(
              icon: Icons.star,
              label: 'PREMIUM',
              color: Colors.orange,
              onPressed: _showPremiumDeals,
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildActionButton(
              icon: Icons.add_business,
              label: 'REQUEST',
              color: Colors.green,
              onPressed: _requestNewBusiness,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey.shade300,
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
                leading: const Icon(Icons.local_offer),
                title: const Text('My Vouchers'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VoucherListScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Purchase History'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PurchaseHistoryScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('Favorites'),
                onTap: () {
                  Navigator.of(context).pop(); // Close drawer
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FavoritesScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings feature coming soon!'),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Help & Support'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Help feature coming soon!'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  _showAboutDialog();
                },
              ),
              if (user != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign Out'),
                  onTap: () => _signOut(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // Action button implementations
  void _showNearbyDeals() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎯 Showing deals within 2km of your location'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showPremiumDeals() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⭐ Showing premium deals from founding partners'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _requestNewBusiness() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildRequestBusinessSheet(),
    );
  }

  Widget _buildRequestBusinessSheet() {
    final TextEditingController businessNameController = TextEditingController();
    final TextEditingController dealTypeController = TextEditingController();
    final TextEditingController locationController = TextEditingController();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(
              children: [
                Icon(Icons.add_business, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Request New Business',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Know a great local business? Help us bring them to Pulse!',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Form fields
            TextField(
              controller: businessNameController,
              decoration: InputDecoration(
                labelText: 'Business Name *',
                hintText: 'e.g., Tony\'s Pizza Palace',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: locationController,
              decoration: InputDecoration(
                labelText: 'Location',
                hintText: 'e.g., Queen St W, Toronto',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: dealTypeController,
              decoration: InputDecoration(
                labelText: 'What kind of deal would be great?',
                hintText: 'e.g., 20% off pizza, happy hour drinks',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.local_offer),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _submitBusinessRequest(
                      businessNameController.text,
                      locationController.text,
                      dealTypeController.text,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit Request',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _submitBusinessRequest(String businessName, String location, String dealType) {
    Navigator.pop(context);
    
    if (businessName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a business name')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Thanks! We\'ll reach out to $businessName soon.'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
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

void _showDealPreviewCarousel(List<Deal> deals) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DealPreviewCarousel(
      deals: deals,
      onDealSelected: (deal) {
        // Close carousel and open full bottom sheet
        Navigator.pop(context);
        setState(() {
          _selectedDeal = deal;
        });
        _showDealBottomSheet(deal);
      },
      onClose: () => Navigator.pop(context),
    ),
  );
}

  void _showSearch() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search functionality coming soon!')),
    );
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔔 No new notifications'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Pulse'),
        content: const Text(
          'Pulse helps you discover amazing local deals in your area. '
          'We\'re currently in beta, working with handpicked local businesses '
          'to bring you the best offers.\n\n'
          'Version: 1.0.0 (Beta)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _signOut() async {
    try {
      await Provider.of<AuthService>(context, listen: false).signOut();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out successfully')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

   // ⭐ NEW METHOD: Switch body based on bottom navigation
  Widget _buildBodyBasedOnBottomNavigation() {
    switch (_currentBottomIndex) {
      case 0:
        return _buildBodyWithDidChangeDependencies(); // Your existing map view
      case 1:
        return const VoucherListScreen(); // My Vouchers
      case 2:
        return _buildSettingsScreen(); // Settings
      default:
        return _buildBodyWithDidChangeDependencies();
    }
  }

  // ⭐ NEW METHOD: Bottom Navigation Bar
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentBottomIndex,
      onTap: (index) {
        setState(() {
          _currentBottomIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      backgroundColor: Colors.white,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_offer),
          label: 'My Vouchers',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  // ⭐ NEW METHOD: Settings screen widget
  Widget _buildSettingsScreen() {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final user = authService.currentUser;
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Profile Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        (user?.displayName?.isNotEmpty == true)
                            ? user!.displayName![0].toUpperCase()
                            : 'G',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Guest User',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user?.email ?? 'Not signed in',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Settings Options
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Purchase History'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PurchaseHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.favorite),
                    title: const Text('Favorites'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FavoritesScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('Notifications'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification settings coming soon!'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help),
                    title: const Text('Help & Support'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Help feature coming soon!'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showLogoutDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ⭐ NEW METHOD: Logout dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}