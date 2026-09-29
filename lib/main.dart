import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'models/mandi_models.dart';
import 'services/mandi_services.dart';
import 'screens/main_dashboard_screen.dart';
import 'screens/buyer_portal_screen.dart';
import 'screens/seller_portal_screen.dart';
import 'screens/broker_portal_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize persistent local key-value storage
  try {
    await StorageService.init();
  } catch (e) {
    debugPrint('StorageService initialization failed: $e');
  }

  // 2. Initialize Firebase across Web, Android, iOS & Windows
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization bypassed: $e');
  }

  runApp(const MandiApp());
}

class MandiApp extends StatelessWidget {
  const MandiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mandi Trade Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          primary: const Color(0xFF0F766E),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const AppStartupGate(),
    );
  }
}

// =============================================================
// AUTO-LOGIN GATEKEEPER WITH FAIL-SAFE
// =============================================================
class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  bool _isLoading = true;
  Widget? _destinationScreen;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final lastSectionRaw = StorageService.get('last_active_section');

      if (lastSectionRaw != null &&
          lastSectionRaw.toString().trim().isNotEmpty) {
        final section = lastSectionRaw.toString().trim().toUpperCase();

        final savedMobile =
            StorageService.get('session_${section}_mobile') ??
            StorageService.get('session_$section');

        if (savedMobile != null && savedMobile.toString().trim().isNotEmpty) {
          final cleanMobile = savedMobile.toString().trim();
          final savedName =
              (StorageService.get('session_${section}_name') ?? section)
                  .toString()
                  .trim();
          final savedEmail =
              (StorageService.get('session_${section}_email') ?? '')
                  .toString()
                  .trim();
          final savedAddress =
              (StorageService.get('session_${section}_address') ??
                      'MANDI OFFICE')
                  .toString()
                  .trim();

          final userAccount = UserAccount(
            name: savedName,
            mobile: cleanMobile,
            email: savedEmail,
            address: savedAddress,
            password: '',
            section: section,
          );

          if (section == 'BROKER') {
            _destinationScreen = const BrokerSectionPortal();
          } else if (section == 'BUYER') {
            _destinationScreen = BuyerSectionPortal(user: userAccount);
          } else if (section == 'SELLER') {
            _destinationScreen = SellerSectionPortal(user: userAccount);
          } else if (section == 'BILL GENERATOR') {
            _destinationScreen = BillGeneratorSectionPortal(
              username: savedName,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error restoring previous user session: $e');
      _destinationScreen = const MainDashboardScreen();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B1320),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF10B981),
                strokeWidth: 2.5,
              ),
              SizedBox(height: 16),
              Text(
                'Opening Mandi Portal...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _destinationScreen ?? const MainDashboardScreen();
  }
}
