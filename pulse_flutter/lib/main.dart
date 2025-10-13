// pulse_flutter/lib/main.dart - Updated with safer voucher services
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/additional_screens.dart';
import 'services/auth_service.dart';
import 'services/deal_service.dart';
import 'services/location_service.dart';
import 'services/payment_service.dart';
import 'services/purchase_service.dart';
import 'services/voucher_notification_service.dart'; // NEW
import 'providers/favorites_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Configure Stripe with new API
  Stripe.publishableKey = Constants.stripePublishableKey;
  Stripe.merchantIdentifier = 'merchant.com.pulse.consumer';
  await Stripe.instance.applySettings();
  
  runApp(const PulseApp());
}

class PulseApp extends StatelessWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DealService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => PaymentService()),
        ChangeNotifierProvider(create: (_) => PurchaseService()),
        ChangeNotifierProvider(create: (_) => VoucherNotificationService()), // NEW
        ChangeNotifierProvider(create: (_) => FavoritesProvider()), // Add this line
      ],
      child: MaterialApp(
        title: 'Pulse',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AppWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  @override
  void initState() {
    super.initState();
    // Set up voucher notifications after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupVoucherNotifications();
    });
  }

  void _setupVoucherNotifications() {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notificationService = Provider.of<VoucherNotificationService>(context, listen: false);
      
      final user = authService.currentUser;
      if (user?.uid != null) {
        notificationService.startListening(
          user!.uid,
          (update) {
            if (mounted) {
              update.showNotification(context);
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Error setting up voucher notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isLoading) {
          return const SplashScreen();
        }
        
        if (authService.currentUser != null) {
          // Set up notifications when user is authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _setupVoucherNotifications();
          });
          return const MainScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}