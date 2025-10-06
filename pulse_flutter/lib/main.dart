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

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isLoading) {
          return const SplashScreen();
        }
        
        if (authService.currentUser != null) {
          return const MainScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}