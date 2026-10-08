import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // Uses marketViewDb bound to mandi-market-view

class MarketWatchScreen extends StatefulWidget {
  const MarketWatchScreen({super.key});

  @override
  State<MarketWatchScreen> createState() => _MarketWatchScreenState();
}

class _MarketWatchScreenState extends State<MarketWatchScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPromoPoster(context);
    });
  }

  // Reads promo poster directly from the secondary Firestore project
  Future<void> _checkAndShowPromoPoster(BuildContext context) async {
    try {
      final doc = await marketViewDb
          .collection('market_watch')
          .doc('promo_config')
          .get();

      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;
      final bool isActive = data['isActive'] ?? false;
      final String? imageUrl = data['imageUrl'];

      if (isActive && imageUrl != null && imageUrl.isNotEmpty && mounted) {
        showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 14,
                    child: Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {}
  }

  void _promptAdminPin(BuildContext context) {
    final pinController = TextEditingController();
    const String masterPin = "2000";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Admin Access (2nd Firestore)',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter 4-digit PIN',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Color(0xFF2B2B2B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722)),
            onPressed: () {
              if (pinController.text.trim() == masterPin) {
                Navigator.pop(ctx);
                _showAdminSheet(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect PIN! Access denied.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Enter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAdminSheet(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading:
                  const Icon(Icons.currency_rupee, color: Color(0xFF00E676)),
              title: const Text(
                'स्थानीय मंडी भाव अपडेट करें',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'mandi-market-view में भाव सेव होंगे',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                showDialog(
                  context: context,
                  builder: (context) => const EditLocalMandiRatesDialog(),
                );
              },
            ),
            const Divider(color: Color(0xFF2B2B2B), height: 1),
            ListTile(
              leading: const Icon(Icons.show_chart, color: Color(0xFF29B6F6)),
              title: const Text(
                'NCDEX लाइव कोट्स अपडेट करें',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'जीरा, चना, इसबगोल, ग्वार वायदा रेट',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                showDialog(
                  context: context,
                  builder: (context) => const EditNcdexRatesDialog(),
                );
              },
            ),
            const Divider(color: Color(0xFF2B2B2B), height: 1),
            ListTile(
              leading: const Icon(Icons.campaign, color: Colors.deepOrange),
              title: const Text(
                'प्रमोशन / पोस्टर बदलें',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'पोस्टर इमेज URL सेट करें',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                showDialog(
                  context: context,
                  builder: (context) => const EditPromoPosterDialog(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 1, // Opens directly to NCDEX tab
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          title: GestureDetector(
            onLongPress: () => _promptAdminPin(context),
            child: const Row(
              children: [
                Text(
                  'MarketWatch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.show_chart, color: Colors.white70, size: 22),
              ],
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF5722),
            indicatorWeight: 3.5,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFF00E676),
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
            tabs: [
              Tab(text: 'MCX'),
              Tab(text: 'NCDEX'),
              Tab(text: 'OTHERS'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            McxWatchList(),
            NcdexWatchList(),
            LocalMandiWatchList(),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// TAB 1: MCX WATCHLIST
// =============================================================
class McxWatchList extends StatelessWidget {
  const McxWatchList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: marketViewDb
          .collection('market_watch')
          .doc('mcx_summary')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF5722)),
          );
        }

        final docData = snapshot.data?.data();
        final List<dynamic> rates =
            (docData != null && docData['rates'] is List)
                ? docData['rates'] as List<dynamic>
                : <dynamic>[];

        if (rates.isEmpty) {
          return const Center(
            child: Text(
              'No MCX quotes available',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          );
        }

        return ListView.separated(
          itemCount: rates.length,
          separatorBuilder: (_, __) =>
              const Divider(color: Color(0xFF141414), height: 1, thickness: 1),
          itemBuilder: (context, index) {
            final item = rates[index] as Map<String, dynamic>;
            final String symbol = item['symbol']?.toString() ?? '';
            final String expiry = item['expiry']?.toString() ?? '';
            final double ltp =
                (item['ltp'] is num) ? (item['ltp'] as num).toDouble() : 0.0;
            final double change = (item['change'] is num)
                ? (item['change'] as num).toDouble()
                : 0.0;

            final bool isPositive = change > 0;
            final Color changeColor = change == 0
                ? const Color(0xFF00E676)
                : (isPositive
                    ? const Color(0xFF00E676)
                    : const Color(0xFFFF3B30));

            return Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        symbol,
                        style: const TextStyle(
                          color: Color(0xFF29B6F6),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        expiry,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        ltp.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        change == 0
                            ? "(+0)"
                            : (isPositive
                                ? "(+${change.toStringAsFixed(0)})"
                                : "(${change.toStringAsFixed(0)})"),
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================
// TAB 2: NCDEX WATCHLIST (MATCHES REFERENCE IMAGE PIXEL-FOR-PIXEL)
// =============================================================
class NcdexWatchList extends StatelessWidget {
  const NcdexWatchList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: marketViewDb
          .collection('market_watch')
          .doc('live_summary')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF5722)),
          );
        }

        final docData = snapshot.data?.data();
        final List<dynamic> rates =
            (docData != null && docData['rates'] is List)
                ? docData['rates'] as List<dynamic>
                : <dynamic>[];

        if (rates.isEmpty) {
          return const Center(
            child: Text(
              'No NCDEX contracts available',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          );
        }

        return ListView.separated(
          itemCount: rates.length,
          separatorBuilder: (_, __) =>
              const Divider(color: Color(0xFF141414), height: 1, thickness: 1),
          itemBuilder: (context, index) {
            final item = rates[index] as Map<String, dynamic>;
            final String symbol = item['symbol']?.toString() ?? '';
            final String expiry = item['expiry']?.toString() ?? '';
            final double ltp =
                (item['ltp'] is num) ? (item['ltp'] as num).toDouble() : 0.0;
            final double change = (item['change'] is num)
                ? (item['change'] as num).toDouble()
                : 0.0;

            final bool isPositive = change > 0;
            final bool isZero = change == 0;
            final Color changeColor = isZero
                ? const Color(0xFF00E676)
                : (isPositive
                    ? const Color(0xFF00E676)
                    : const Color(0xFFFF3B30));

            return Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Contract Symbol and Expiry Date
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          symbol,
                          style: const TextStyle(
                            color: Color(0xFF29B6F6), // Sky Blue
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            expiry,
                            style: const TextStyle(
                              color: Color(0xFF8E8E93), // Subdued Date Grey
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right: Price & (+/- Change)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ltp.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isZero
                            ? "(+0)"
                            : (isPositive
                                ? "(+${change.toStringAsFixed(0)})"
                                : "(${change.toStringAsFixed(0)})"),
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================
// TAB 3: OTHERS / LOCAL MANDI RATES
// =============================================================
class LocalMandiWatchList extends StatelessWidget {
  const LocalMandiWatchList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: marketViewDb
          .collection('market_watch')
          .doc('local_mandi_summary')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF5722)),
          );
        }

        final docData = snapshot.data?.data();
        final List<dynamic> rates =
            (docData != null && docData['rates'] is List)
                ? docData['rates'] as List<dynamic>
                : <dynamic>[];

        if (rates.isEmpty) {
          return const Center(
            child: Text(
              'कोई मंडी भाव उपलब्ध नहीं है',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          );
        }

        return ListView.separated(
          itemCount: rates.length,
          separatorBuilder: (_, __) =>
              const Divider(color: Color(0xFF141414), height: 1),
          itemBuilder: (context, index) {
            final item = rates[index] as Map<String, dynamic>;
            final String name = item['name']?.toString() ?? '';
            final String unit = item['unit']?.toString() ?? 'क्विंटल';
            final num minRate = (item['min'] is num) ? item['min'] as num : 0;
            final num maxRate = (item['max'] is num) ? item['max'] as num : 0;

            return Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF29B6F6),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($unit)',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "₹$minRate - ₹$maxRate",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "मंडी भाव",
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================
// ADMIN DIALOG: LOCAL MANDI RATES
// =============================================================
class EditLocalMandiRatesDialog extends StatefulWidget {
  const EditLocalMandiRatesDialog({super.key});

  @override
  State<EditLocalMandiRatesDialog> createState() =>
      _EditLocalMandiRatesDialogState();
}

class _EditLocalMandiRatesDialogState extends State<EditLocalMandiRatesDialog> {
  final List<String> commodities = [
    'मूंग',
    'तिल',
    'मोठ',
    'चना',
    'जीरा मंडी जोधपुर',
    'रायड़ा',
    'ईसबगोल',
    'बाजरा',
    'तारामीरा',
    'सौंफ',
    'कपास',
  ];

  late Map<String, TextEditingController> minControllers;
  late Map<String, TextEditingController> maxControllers;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    minControllers = {for (var c in commodities) c: TextEditingController()};
    maxControllers = {for (var c in commodities) c: TextEditingController()};
    _loadExistingRates();
  }

  @override
  void dispose() {
    for (var c in minControllers.values) {
      c.dispose();
    }
    for (var c in maxControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingRates() async {
    try {
      final doc = await marketViewDb
          .collection('market_watch')
          .doc('local_mandi_summary')
          .get();
      if (doc.exists && doc.data() != null) {
        final List rates = doc.data()!['rates'] ?? [];
        for (var r in rates) {
          final name = r['name'];
          if (minControllers.containsKey(name)) {
            minControllers[name]!.text = r['min']?.toString() ?? '';
            maxControllers[name]!.text = r['max']?.toString() ?? '';
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveRates() async {
    setState(() => isSaving = true);
    final List<Map<String, dynamic>> rateList = [];

    for (var name in commodities) {
      rateList.add({
        'name': name,
        'unit': 'क्विंटल',
        'min': double.tryParse(minControllers[name]!.text.trim()) ?? 0,
        'max': double.tryParse(maxControllers[name]!.text.trim()) ?? 0,
      });
    }

    try {
      await marketViewDb
          .collection('market_watch')
          .doc('local_mandi_summary')
          .set({
        'rates': rateList,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => isSaving = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('स्थानीय मंडी भाव अपडेट करें',
          style: TextStyle(color: Colors.white, fontSize: 18)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: commodities.map((c) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      c,
                      style: const TextStyle(
                        color: Color(0xFF29B6F6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: minControllers[c],
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Min',
                        hintStyle: TextStyle(color: Colors.white38),
                        isDense: true,
                        filled: true,
                        fillColor: Color(0xFF2B2B2B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: maxControllers[c],
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Max',
                        hintStyle: TextStyle(color: Colors.white38),
                        isDense: true,
                        filled: true,
                        fillColor: Color(0xFF2B2B2B),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : _saveRates,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722)),
          child: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('सेव करें', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// =============================================================
// ADMIN DIALOG: NCDEX LIVE RATES
// =============================================================
class EditNcdexRatesDialog extends StatefulWidget {
  const EditNcdexRatesDialog({super.key});

  @override
  State<EditNcdexRatesDialog> createState() => _EditNcdexRatesDialogState();
}

class _EditNcdexRatesDialogState extends State<EditNcdexRatesDialog> {
  final List<String> symbols = [
    'GUARGUM5',
    'GUARSEED10',
    'JEERAUNJHA',
    'TMCFGRNZM',
    'DHANIYA',
    'CHANA'
  ];
  late Map<String, TextEditingController> ltpControllers;
  late Map<String, TextEditingController> changeControllers;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    ltpControllers = {for (var s in symbols) s: TextEditingController()};
    changeControllers = {for (var s in symbols) s: TextEditingController()};
    _loadExistingRates();
  }

  @override
  void dispose() {
    for (var c in ltpControllers.values) {
      c.dispose();
    }
    for (var c in changeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingRates() async {
    try {
      final doc = await marketViewDb
          .collection('market_watch')
          .doc('live_summary')
          .get();
      if (doc.exists && doc.data() != null) {
        final List rates = doc.data()!['rates'] ?? [];
        for (var r in rates) {
          final sym = r['symbol'];
          if (ltpControllers.containsKey(sym)) {
            ltpControllers[sym]!.text = r['ltp']?.toString() ?? '';
            changeControllers[sym]!.text = r['change']?.toString() ?? '';
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveRates() async {
    setState(() => isSaving = true);
    final List<Map<String, dynamic>> rateList = [];

    for (var sym in symbols) {
      rateList.add({
        'symbol': sym,
        'expiry': 'NEAR',
        'ltp': double.tryParse(ltpControllers[sym]!.text.trim()) ?? 0,
        'change': double.tryParse(changeControllers[sym]!.text.trim()) ?? 0,
      });
    }

    try {
      await marketViewDb.collection('market_watch').doc('live_summary').set({
        'rates': rateList,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => isSaving = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('NCDEX लाइव कोट्स अपडेट करें',
          style: TextStyle(color: Colors.white, fontSize: 18)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: symbols.map((sym) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      sym,
                      style: const TextStyle(
                        color: Color(0xFF29B6F6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: ltpControllers[sym],
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'LTP (₹)',
                        hintStyle: TextStyle(color: Colors.white38),
                        isDense: true,
                        filled: true,
                        fillColor: Color(0xFF2B2B2B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: changeControllers[sym],
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Change (+/-)',
                        hintStyle: TextStyle(color: Colors.white38),
                        isDense: true,
                        filled: true,
                        fillColor: Color(0xFF2B2B2B),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : _saveRates,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722)),
          child: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('सेव करें', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// =============================================================
// ADMIN DIALOG: PROMO POSTER
// =============================================================
class EditPromoPosterDialog extends StatefulWidget {
  const EditPromoPosterDialog({super.key});

  @override
  State<EditPromoPosterDialog> createState() => _EditPromoPosterDialogState();
}

class _EditPromoPosterDialogState extends State<EditPromoPosterDialog> {
  final _urlCtrl = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPromoData();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPromoData() async {
    try {
      final doc = await marketViewDb
          .collection('market_watch')
          .doc('promo_config')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _urlCtrl.text = data['imageUrl']?.toString() ?? '';
        setState(() {
          _isActive = data['isActive'] ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _savePromo() async {
    setState(() => _isSaving = true);
    try {
      await marketViewDb.collection('market_watch').doc('promo_config').set({
        'imageUrl': _urlCtrl.text.trim(),
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() => _isSaving = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving promo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('प्रमोशन / पोस्टर सेटिंग्स',
          style: TextStyle(color: Colors.white, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Image Web URL',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
              hintText: 'https://...',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text(
              'Show Poster on App Start',
              style: TextStyle(color: Colors.white),
            ),
            value: _isActive,
            onChanged: (val) => setState(() => _isActive = val),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _savePromo,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722)),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('सेव करें', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
