import '../services/mandi_services.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/email_service.dart';
import '../models/mandi_models.dart';
import '../services/cloud_sync_service.dart';
import 'buyer_portal_screen.dart';
import 'seller_portal_screen.dart';
import 'broker_portal_screen.dart';
import 'market_watch_screen.dart';

// =============================================================
// MAIN 5-SECTION DASHBOARD
// =============================================================
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Guarantee auth token existence as soon as dashboard displays
    _initializeAuth();

    // Check for app updates via Firestore version control
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdates(context);
    });
  }

  Future<void> _initializeAuth() async {
    try {
      await CloudSyncService.ensureAuthSession();
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('🔑 Mandi Dashboard Active Auth UID: ${user?.uid}');
    } catch (e) {
      debugPrint('⚠️ Auth session init error: $e');
    }
  }

  void _showLockedNotice(BuildContext context, String sectionTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Under Maintenance',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          '$sectionTitle is temporarily locked for maintenance. Please use the Broker Portal.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _routeToSection(BuildContext context, String sectionName) {
    final existingUser = AccountService.getSessionUser(sectionName);
    if (existingUser != null) {
      Widget portal;
      if (sectionName == 'BROKER') {
        portal = const BrokerSectionPortal();
      } else if (sectionName == 'BUYER') {
        portal = BuyerSectionPortal(user: existingUser);
      } else if (sectionName == 'SELLER') {
        portal = SellerSectionPortal(user: existingUser);
      } else {
        portal = BillGeneratorSectionPortal(username: existingUser.name);
      }
      Navigator.push(context, MaterialPageRoute(builder: (context) => portal));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SectionLoginGate(sectionName: sectionName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1320),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.2,
            colors: [Color(0xFF16253B), Color(0xFF0B1320)],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<Map<String, dynamic>>(
            stream: CloudSyncService.streamServiceSwitches(),
            builder: (context, snapshot) {
              final config = snapshot.data ?? {};

              // Real-time remote toggles from Firebase (defaults to true if not configured)
              final bool enableMarketView = config['market_view'] ?? true;
              final bool enableBuyerPortal = config['buyer_portal'] ?? true;
              final bool enableSellerPortal = config['seller_portal'] ?? true;
              final bool enableBillGenerator = config['bill_generator'] ?? true;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'APMC • E-MANDI TRADE NETWORK',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          kAppName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          kAppNameHindi,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 1. MARKET VIEW
                        _buildSectionCard(
                          context: context,
                          title: 'MARKET VIEW',
                          hindiTitle: 'दैनिक मंडी भाव एवं आवक',
                          description: enableMarketView
                              ? 'Live rates, arrival volumes & commodity lists'
                              : 'Temporarily under maintenance',
                          icon: Icons.show_chart_rounded,
                          accentColor: enableMarketView
                              ? const Color(0xFF10B981)
                              : Colors.grey,
                          badgeText:
                              enableMarketView ? 'PUBLIC ACCESS' : 'LOCKED 🔒',
                          isPublic: enableMarketView,
                          onTap: () {
                            if (enableMarketView) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MarketWatchScreen(),
                                ),
                              );
                            } else {
                              _showLockedNotice(context, 'Market View');
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // 2. BUYER
                        _buildSectionCard(
                          context: context,
                          title: 'BUYER',
                          hindiTitle: 'खरीदार खाता एवं ब्रोकर सूची',
                          description: enableBuyerPortal
                              ? 'Browse brokers, confirm purchases & view khata'
                              : 'Buyer portal temporarily closed for maintenance',
                          icon: Icons.storefront_rounded,
                          accentColor: enableBuyerPortal
                              ? const Color(0xFF38BDF8)
                              : Colors.grey,
                          badgeText:
                              enableBuyerPortal ? 'SECURE LOGIN' : 'LOCKED 🔒',
                          isPublic: false,
                          onTap: () {
                            if (enableBuyerPortal) {
                              _routeToSection(context, 'BUYER');
                            } else {
                              _showLockedNotice(context, 'Buyer Portal');
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // 3. SELLER
                        _buildSectionCard(
                          context: context,
                          title: 'SELLER',
                          hindiTitle: 'विक्रेता / किसान खाता',
                          description: enableSellerPortal
                              ? 'Browse brokers, confirm sales & view khata'
                              : 'Seller portal temporarily closed for maintenance',
                          icon: Icons.agriculture_rounded,
                          accentColor: enableSellerPortal
                              ? const Color(0xFFF59E0B)
                              : Colors.grey,
                          badgeText:
                              enableSellerPortal ? 'SECURE LOGIN' : 'LOCKED 🔒',
                          isPublic: false,
                          onTap: () {
                            if (enableSellerPortal) {
                              _routeToSection(context, 'SELLER');
                            } else {
                              _showLockedNotice(context, 'Seller Portal');
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // 4. BROKER (ALWAYS ACTIVE)
                        _buildSectionCard(
                          context: context,
                          title: 'BROKER',
                          hindiTitle: 'ब्रोकर बही व टेम्पलेट',
                          description:
                              'Deal entry, custom templates & settlement (ACTIVE)',
                          icon: Icons.handshake_rounded,
                          accentColor: const Color(0xFF14B8A6),
                          badgeText: 'BROKER SYSTEM',
                          isPublic: false,
                          isHighlighted: true,
                          onTap: () => _routeToSection(context, 'BROKER'),
                        ),
                        const SizedBox(height: 12),

                        // 5. BILL GENERATOR
                        _buildSectionCard(
                          context: context,
                          title: 'BILL GENERATOR',
                          hindiTitle: 'बिल एवं पर्चा जनरेटर',
                          description: enableBillGenerator
                              ? 'A4 print generation, statements & cess bills'
                              : 'Bills accessible directly inside Broker Ledger',
                          icon: Icons.receipt_long_rounded,
                          accentColor: enableBillGenerator
                              ? const Color(0xFFA855F7)
                              : Colors.grey,
                          badgeText: enableBillGenerator
                              ? 'SECURE LOGIN'
                              : 'LOCKED 🔒',
                          isPublic: false,
                          onTap: () {
                            if (enableBillGenerator) {
                              _routeToSection(context, 'BILL GENERATOR');
                            } else {
                              _showLockedNotice(context, 'Bill Generator');
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Broker Directory Table • Visible Broker Info • Custom WhatsApp Templates',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String hindiTitle,
    required String description,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required bool isPublic,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: accentColor.withValues(alpha: 0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isHighlighted
                ? accentColor.withValues(alpha: 0.08)
                : const Color(0xFF131D2D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighlighted
                  ? accentColor.withValues(alpha: 0.5)
                  : const Color(0xFF223249),
              width: isHighlighted ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isPublic
                                ? const Color(0xFF10B981)
                                    .withValues(alpha: 0.15)
                                : const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isPublic
                                  ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.4)
                                  : const Color(0xFF475569),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: isPublic
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade300,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hindiTitle,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// LOGIN GATE WITH APP NAME ON GMAIL OTP
// =============================================================
class SectionLoginGate extends StatefulWidget {
  final String sectionName;

  const SectionLoginGate({super.key, required this.sectionName});

  @override
  State<SectionLoginGate> createState() => _SectionLoginGateState();
}

class _SectionLoginGateState extends State<SectionLoginGate> {
  final _mobileController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final savedMobile =
        StorageService.get('session_${widget.sectionName}_mobile') ??
            StorageService.get('session_${widget.sectionName}');
    if (savedMobile != null && savedMobile.toString().isNotEmpty) {
      _mobileController.text = savedMobile.toString();
    }
  }

  void _initiateLogin() async {
    final identifier = _mobileController.text.trim();
    final pin = _pinController.text.trim();

    if (identifier.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Mobile/Email and Password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Fetch live cloud account first from Firebase
      final cloudData =
          await CloudSyncService.getAccountByIdentifier(identifier)
              .timeout(const Duration(seconds: 6), onTimeout: () => null);

      // =========================================================
      // 🚫 PREVENT LOGIN WITH OLD / DELETED CREDENTIALS
      // =========================================================
      if (cloudData == null) {
        // If it does not exist in Firebase, purge any old cached record from local phone storage
        final accounts = AccountService.getAllAccounts();
        accounts.removeWhere(
          (a) =>
              a.mobile.trim() == identifier ||
              a.email.trim().toLowerCase() == identifier.toLowerCase(),
        );
        AccountService.saveAccounts(accounts);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account not found! If you changed your mobile or Gmail, please log in with your updated details.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return; // Halts login execution immediately
      }

      // =========================================================
      // 🔒 SUBSCRIPTION DUE / ACCOUNT LOCKED CHECK
      // =========================================================
      final bool isLocked = cloudData['is_locked'] == true ||
          cloudData['is_blocked'] == true ||
          cloudData['account_status'] == 'locked' ||
          cloudData['account_status'] == 'suspended';

      if (isLocked) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.payment_rounded, color: Colors.amber, size: 28),
                SizedBox(width: 10),
                Text(
                  'Subscription Due',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your portal subscription has expired or is currently overdue.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 10),
                Text(
                  'Please renew your plan or contact the mandi admin office to reactivate your access.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // 2. Parse live cloud account and sync with local storage
      final UserAccount liveUser = UserAccount.fromJson(cloudData);
      final accounts = AccountService.getAllAccounts();
      accounts.removeWhere(
        (a) => a.mobile == liveUser.mobile && a.section == liveUser.section,
      );
      accounts.add(liveUser);
      AccountService.saveAccounts(accounts);

      if (!mounted) return;

      // 3. Section Access Check
      if (liveUser.section.toUpperCase() != widget.sectionName.toUpperCase()) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(
              'Access Denied',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'This account is registered under "${liveUser.section}". Please log in through the ${liveUser.section} portal.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // 4. Password / PIN Verification
      if (liveUser.password != pin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect Password / PIN!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 5. Email check for OTP
      final emailToUse = liveUser.email.trim();
      if (emailToUse.isEmpty || !emailToUse.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Invalid or missing email ($emailToUse) for this account.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final loginOtp = (100000 + Random().nextInt(900000)).toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sending security OTP to $emailToUse...'),
          backgroundColor: const Color(0xFF0F766E),
          duration: const Duration(seconds: 3),
        ),
      );

      // Increased timeout to 15s for mobile networks
      bool sent = false;
      try {
        sent = await EmailService.sendOtpEmail(
          recipientEmail: emailToUse,
          recipientName: liveUser.name,
          otp: loginOtp,
          purpose: 'Login',
        ).timeout(const Duration(seconds: 15), onTimeout: () {
          debugPrint('❌ Email delivery timed out after 15 seconds.');
          return false;
        });
      } catch (e) {
        debugPrint('❌ EmailService threw an unhandled exception: $e');
        sent = false;
      }

      if (!mounted) return;

      if (!sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to deliver OTP to $emailToUse.\nPlease check phone internet, Private DNS, or EmailJS monthly quota.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      setState(() => _isLoading = false);
      _showLoginOtpDialog(liveUser, loginOtp);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLoginOtpDialog(UserAccount account, String expectedOtp) {
    final otpCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mark_email_read, color: Color(0xFF0F766E)),
            SizedBox(width: 8),
            Text('Enter Email OTP'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the 6-digit code sent to ${account.email}:'),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '6-Digit OTP',
                prefixIcon: Icon(Icons.pin),
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final enteredOtp = otpCtrl.text.trim();
              if (enteredOtp != expectedOtp) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Invalid OTP! Please check your email inbox.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);

              StorageService.save('last_active_section', widget.sectionName);
              StorageService.save(
                'session_${widget.sectionName}',
                account.mobile,
              );
              StorageService.save(
                'session_${widget.sectionName}_name',
                account.name,
              );
              StorageService.save(
                'session_${widget.sectionName}_mobile',
                account.mobile,
              );
              StorageService.save(
                'session_${widget.sectionName}_email',
                account.email,
              );
              StorageService.save(
                'session_${widget.sectionName}_address',
                account.address,
              );

              final allAccounts = AccountService.getAllAccounts();
              final index = allAccounts.indexWhere(
                (a) =>
                    a.mobile == account.mobile &&
                    a.section == widget.sectionName,
              );
              if (index >= 0) {
                allAccounts[index] = account;
              } else {
                allAccounts.add(account);
              }
              AccountService.saveAccounts(allAccounts);

              Widget targetPortal;
              if (widget.sectionName == 'BROKER') {
                targetPortal = const BrokerSectionPortal();
              } else if (widget.sectionName == 'BUYER') {
                targetPortal = BuyerSectionPortal(user: account);
              } else if (widget.sectionName == 'SELLER') {
                targetPortal = SellerSectionPortal(user: account);
              } else {
                targetPortal = BillGeneratorSectionPortal(
                  username: account.name,
                );
              }

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => targetPortal),
              );
            },
            child: const Text('VERIFY & ENTER'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1320),
      appBar: AppBar(
        title: Text('${widget.sectionName} PORTAL LOGIN'),
        backgroundColor: const Color(0xFF16253B),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor:
                      const Color(0xFF0F766E).withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 36,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${widget.sectionName} SIGN IN',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: '10-Digit Mobile Number',
                    prefixIcon: Icon(Icons.phone_android),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pinController,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Security PIN / Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _initiateLogin,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(_isLoading ? 'LOGGING IN...' : 'LOGIN TO PORTAL'),
                ),
                const SizedBox(height: 16),
                const Divider(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateAccountScreen(
                          sectionName: widget.sectionName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.person_add_outlined,
                    color: Color(0xFF0F766E),
                  ),
                  label: const Text(
                    'CREATE NEW ACCOUNT',
                    style: TextStyle(
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// MODERN PROGRESSIVE ONBOARDING: EMAIL -> OTP -> CREATE PASSWORD
// =============================================================
class CreateAccountScreen extends StatefulWidget {
  final String sectionName;

  const CreateAccountScreen({super.key, required this.sectionName});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  int _currentStep = 1;

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String _generatedOtp = '';

  // STEP 1: SEND OTP
  Future<void> _handleSendOtp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Gmail address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Ensure auth session is alive before checking accounts in Firestore
      await CloudSyncService.ensureAuthSession();

      final existing = await CloudSyncService.getAccountByIdentifier(email)
          .timeout(const Duration(seconds: 6), onTimeout: () => null);

      if (!mounted) return;

      if (existing != null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email already registered under "${existing['section']}"!',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _generatedOtp = (100000 + Random().nextInt(900000)).toString();

      final sent = await EmailService.sendOtpEmail(
        recipientEmail: email,
        recipientName: 'New Member',
        otp: _generatedOtp,
        purpose: 'Account Registration',
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (sent) {
        setState(() => _currentStep = 2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to $email'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to deliver email. Check internet connection or EmailJS keys.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // STEP 2: VERIFY OTP
  void _handleVerifyOtp() {
    if (_otpCtrl.text.trim() == _generatedOtp) {
      setState(() => _currentStep = 3);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid OTP! Please check your email inbox.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // STEP 3: FINALIZE PROFILE & SAVE TO FIRESTORE
  void _handleCompleteRegistration() async {
    final name = _nameCtrl.text.trim().toUpperCase();
    final mobile = _mobileCtrl.text.trim();
    final address = _addressCtrl.text.trim().toUpperCase();
    final password = _passwordCtrl.text.trim();
    final confirmPassword = _confirmPasswordCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();

    if (name.isEmpty ||
        mobile.length != 10 ||
        address.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all fields correctly (Mobile must be 10 digits)',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Ensure valid Firebase Auth session before attempting write
      await CloudSyncService.ensureAuthSession();
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('🔑 Registration attempting write under UID: ${user?.uid}');

      final newAccount = UserAccount(
        name: name,
        mobile: mobile,
        email: email,
        address: address,
        password: password,
        section: widget.sectionName,
      );

      // Save locally
      final accounts = AccountService.getAllAccounts();
      accounts.removeWhere(
        (a) => a.mobile == mobile && a.section == widget.sectionName,
      );
      accounts.add(newAccount);
      AccountService.saveAccounts(accounts);

      // 2. Save directly to Cloud Firestore (with informative logging)
      try {
        await CloudSyncService.saveAccount(newAccount.toJson())
            .timeout(const Duration(seconds: 8));
        debugPrint('✅ CloudSync: registered_accounts document saved!');

        if (widget.sectionName == 'BROKER') {
          final brokerProfile = BrokerFirmProfileModel(
            firmName: name,
            mobile: mobile,
            email: email,
            address: address,
          );
          await CloudSyncService.saveBrokerProfile(
            mobile,
            brokerProfile.toJson(),
          ).timeout(const Duration(seconds: 8));
          debugPrint('✅ CloudSync: broker_profiles document saved!');
        }
      } catch (cloudErr) {
        debugPrint('❌ CloudSync Write Error: $cloudErr');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cloud sync warning: $cloudErr'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      StorageService.save('last_active_section', widget.sectionName);
      StorageService.save('session_${widget.sectionName}', mobile);
      StorageService.save('session_${widget.sectionName}_name', name);
      StorageService.save('session_${widget.sectionName}_mobile', mobile);
      StorageService.save('session_${widget.sectionName}_email', email);
      StorageService.save('session_${widget.sectionName}_address', address);

      if (!mounted) return;

      Widget targetPortal;
      if (widget.sectionName == 'BROKER') {
        targetPortal = const BrokerSectionPortal();
      } else if (widget.sectionName == 'BUYER') {
        targetPortal = BuyerSectionPortal(user: newAccount);
      } else if (widget.sectionName == 'SELLER') {
        targetPortal = SellerSectionPortal(user: newAccount);
      } else {
        targetPortal = BillGeneratorSectionPortal(username: newAccount.name);
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => targetPortal),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1320),
      appBar: AppBar(
        title: Text('REGISTER ${widget.sectionName}'),
        backgroundColor: const Color(0xFF16253B),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepIndicator(1, 'Email'),
                    _buildStepDivider(_currentStep >= 2),
                    _buildStepIndicator(2, 'Verify'),
                    _buildStepDivider(_currentStep >= 3),
                    _buildStepIndicator(3, 'Password'),
                  ],
                ),
                const Divider(height: 28),
                if (_currentStep == 1) ...[
                  const Text(
                    'Step 1: Verify Email Address',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'We will send a 6-digit confirmation OTP to your Gmail.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Gmail Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleSendOtp,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isLoading ? 'SENDING OTP...' : 'SEND VERIFICATION OTP',
                    ),
                  ),
                ],
                if (_currentStep == 2) ...[
                  const Text(
                    'Step 2: Enter Verification Code',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter the 6-digit OTP sent to ${_emailCtrl.text.trim()}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '6-Digit OTP',
                      prefixIcon: Icon(Icons.pin),
                      border: OutlineInputBorder(),
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _handleSendOtp,
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _handleVerifyOtp,
                    child: const Text('VERIFY OTP'),
                  ),
                ],
                if (_currentStep == 3) ...[
                  const Text(
                    'Step 3: Setup Profile & Password',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Email verified! Provide details and choose your password.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Full Name / Firm Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mobileCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      labelText: '10-Digit Mobile Number (Login ID)',
                      prefixIcon: Icon(Icons.phone_android),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Mandi / Office Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Create Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscurePassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_reset),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleCompleteRegistration,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isLoading
                          ? 'CREATING ACCOUNT...'
                          : 'REGISTER & COMPLETE',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isDone = _currentStep > step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: isDone || isCurrent
              ? const Color(0xFF0F766E)
              : Colors.grey.shade300,
          child: isDone
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : Text(
                  '$step',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? Colors.white : Colors.grey.shade700,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? const Color(0xFF0F766E) : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool active) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      color: active ? const Color(0xFF0F766E) : Colors.grey.shade300,
    );
  }
}

// =============================================================
// 5. BILL GENERATOR SECTION (ISOLATED)
// =============================================================
class BillGeneratorSectionPortal extends StatelessWidget {
  final String username;

  const BillGeneratorSectionPortal({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'BILL GENERATOR ($username)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFA855F7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              StorageService.remove('session_BILL GENERATOR');
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainDashboardScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                size: 64,
                color: Color(0xFFA855F7),
              ),
              const SizedBox(height: 16),
              const Text(
                'BILL & INVOICE GENERATOR',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Active Session: $username',
                style: const TextStyle(color: Colors.black54),
              ),
              const Divider(height: 32),
              const Text(
                'Dedicated mandi bill printing, tax invoicing, and gate pass generator is isolated here.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
