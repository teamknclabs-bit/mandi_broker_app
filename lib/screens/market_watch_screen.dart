import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// --- Model for an Exchange Contract Row ---
class MarketContract {
  final String symbol;
  final String expiry;
  final String exchange; // NCDEX, MCX, OTHERS
  double ltp;
  double change;
  double high;
  double low;
  double open;
  double prevClose;
  double bid;
  double ask;
  Color tickColor; // Highlights green/red on tick update

  MarketContract({
    required this.symbol,
    required this.expiry,
    required this.exchange,
    required this.ltp,
    required this.change,
    required this.high,
    required this.low,
    required this.open,
    required this.prevClose,
    required this.bid,
    required this.ask,
    this.tickColor = Colors.white,
  });
}

class MarketWatchScreen extends StatefulWidget {
  const MarketWatchScreen({super.key});

  @override
  State<MarketWatchScreen> createState() => _MarketWatchScreenState();
}

class _MarketWatchScreenState extends State<MarketWatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _mockTickTimer;
  final Random _random = Random();

  // Initial Sample contracts mirroring real market instruments
  final List<MarketContract> _contracts = [
    // --- NCDEX Instruments ---
    MarketContract(
      symbol: 'GUARSEED10',
      expiry: '16OCT2026',
      exchange: 'NCDEX',
      ltp: 6728,
      change: -92,
      high: 6795,
      low: 6548,
      open: 6775,
      prevClose: 6820,
      bid: 6728,
      ask: 6734,
    ),
    MarketContract(
      symbol: 'GUARSEED10',
      expiry: '20NOV2026',
      exchange: 'NCDEX',
      ltp: 6795,
      change: -98,
      high: 6870,
      low: 6782,
      open: 6855,
      prevClose: 6893,
      bid: 6795,
      ask: 6797,
    ),
    MarketContract(
      symbol: 'ISABGOL',
      expiry: '19OCT2026',
      exchange: 'NCDEX',
      ltp: 0.00,
      change: 0.00,
      high: 0.00,
      low: 0.00,
      open: 0.00,
      prevClose: 0.00,
      bid: 0.00,
      ask: 0.00,
    ),
    MarketContract(
      symbol: 'ISABGOL',
      expiry: '20NOV2026',
      exchange: 'NCDEX',
      ltp: 0.00,
      change: 0.00,
      high: 0.00,
      low: 0.00,
      open: 0.00,
      prevClose: 0.00,
      bid: 0.00,
      ask: 0.00,
    ),
    MarketContract(
      symbol: 'JEERAMINI',
      expiry: '19OCT2026',
      exchange: 'NCDEX',
      ltp: 0.00,
      change: 0.00,
      high: 0.00,
      low: 0.00,
      open: 0.00,
      prevClose: 0.00,
      bid: 0.00,
      ask: 0.00,
    ),
    MarketContract(
      symbol: 'JEERAUNJHA',
      expiry: '19OCT2026',
      exchange: 'NCDEX',
      ltp: 22015,
      change: -295,
      high: 22375,
      low: 21925,
      open: 22325,
      prevClose: 22310,
      bid: 22005,
      ask: 22050,
    ),
    MarketContract(
      symbol: 'JEERAUNJHA',
      expiry: '20NOV2026',
      exchange: 'NCDEX',
      ltp: 22430,
      change: -315,
      high: 22795,
      low: 22350,
      open: 22795,
      prevClose: 22745,
      bid: 22400,
      ask: 22525,
    ),
    MarketContract(
      symbol: 'KAPAS',
      expiry: '30NOV2026',
      exchange: 'NCDEX',
      ltp: 0,
      change: 0,
      high: 0,
      low: 0,
      open: 0,
      prevClose: 0,
      bid: 0,
      ask: 0,
    ),

    // --- MCX Instruments ---
    MarketContract(
      symbol: 'CRUDEOIL',
      expiry: '19OCT2026',
      exchange: 'MCX',
      ltp: 5940,
      change: 45,
      high: 5980,
      low: 5890,
      open: 5900,
      prevClose: 5895,
      bid: 5938,
      ask: 5941,
    ),
    MarketContract(
      symbol: 'GOLD',
      expiry: '05DEC2026',
      exchange: 'MCX',
      ltp: 75240,
      change: 180,
      high: 75450,
      low: 74980,
      open: 75050,
      prevClose: 75060,
      bid: 75235,
      ask: 75245,
    ),

    // --- OTHERS / LOCAL MANDI SPOT ---
    MarketContract(
      symbol: 'MUSTARD SPOT',
      expiry: 'JAIPUR',
      exchange: 'OTHERS',
      ltp: 5750,
      change: 30,
      high: 5800,
      low: 5710,
      open: 5720,
      prevClose: 5720,
      bid: 5745,
      ask: 5755,
    ),
    MarketContract(
      symbol: 'CHANA SPOT',
      expiry: 'DELHI',
      exchange: 'OTHERS',
      ltp: 6150,
      change: -25,
      high: 6200,
      low: 6120,
      open: 6180,
      prevClose: 6175,
      bid: 6140,
      ask: 6160,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 3 Tabs: MCX, NCDEX, OTHERS (Defaults to NCDEX like the screenshot)
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);

    // Mock Live Tick Simulator: Generates realistic live market price variations every 1.5 seconds
    _mockTickTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      _simulateLiveTick();
    });
  }

  @override
  void dispose() {
    _mockTickTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _simulateLiveTick() {
    // Pick an active contract at random to simulate a live tick
    final activeList = _contracts.where((c) => c.ltp > 0).toList();
    if (activeList.isEmpty) return;

    final target = activeList[_random.nextInt(activeList.length)];
    final tickDirection = _random.nextBool() ? 1 : -1;
    final tickAmount = (_random.nextInt(4) + 1) * 2.0;

    setState(() {
      final oldLtp = target.ltp;
      target.ltp += (tickDirection * tickAmount);
      target.change += (tickDirection * tickAmount);
      target.bid = target.ltp - (_random.nextInt(5) + 1);
      target.ask = target.ltp + (_random.nextInt(5) + 1);

      if (target.ltp > target.high) target.high = target.ltp;
      if (target.ltp < target.low && target.low > 0) target.low = target.ltp;

      // Flash green on up-tick, red on down-tick
      target.tickColor = target.ltp >= oldLtp
          ? const Color(0xFF00E676)
          : const Color(0xFFFF5252);
    });

    // Reset color to clean white after 400ms
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          target.tickColor = Colors.white;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark Terminal Canvas
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Row(
          children: [
            Text(
              'MarketWatch',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
            Spacer(),
            Icon(Icons.show_chart, color: Colors.white, size: 22),
            SizedBox(width: 14),
            Icon(Icons.notifications_none, color: Colors.white, size: 22),
            SizedBox(width: 14),
            Icon(Icons.share, color: Colors.white, size: 20),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF9800), // Vibrant amber line
          indicatorWeight: 3.0,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'MCX'),
            Tab(text: 'NCDEX'),
            Tab(text: 'OTHERS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMarketList('MCX'),
          _buildMarketList('NCDEX'),
          _buildMarketList('OTHERS'),
        ],
      ),
    );
  }

  Widget _buildMarketList(String exchange) {
    final list = _contracts.where((c) => c.exchange == exchange).toList();

    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No active contracts',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(
        color: Color(0xFF1E1E1E),
        height: 1,
        thickness: 0.8,
      ),
      itemBuilder: (context, index) {
        final item = list[index];
        return _buildContractRow(item);
      },
    );
  }

  Widget _buildContractRow(MarketContract item) {
    final bool isPositive = item.change > 0;
    final bool isZero = item.change == 0;

    // Formatting numbers without trailing decimals if integer
    String formatNum(double val) => val == 0
        ? '0'
        : (val == val.roundToDouble()
            ? val.toStringAsFixed(0)
            : val.toStringAsFixed(2));

    String changeText = isZero
        ? '(+0.00)'
        : (isPositive
            ? '(+${formatNum(item.change)})'
            : '(${formatNum(item.change)})');

    Color changeColor = isZero
        ? const Color(0xFF4CAF50)
        : (isPositive ? const Color(0xFF00E676) : const Color(0xFFFF5252));

    return InkWell(
      onTap: () {
        // Quick hook: Trigger Trade or show Market Depth Popover
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF212121),
            content: Text(
              'Selected ${item.symbol} (${item.expiry}) @ ₹${formatNum(item.ltp)}',
              style: const TextStyle(color: Colors.white),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- LEFT COLUMN: Symbol, Expiry, OHLC ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.symbol,
                        style: const TextStyle(
                          color: Color(0xFF29B6F6), // Vibrant Cyan/Light Blue
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.expiry,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // High & Low row
                  Text(
                    'H: ${formatNum(item.high)}   L: ${formatNum(item.low)}',
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Open & Close row
                  Text(
                    'O: ${formatNum(item.open)}   C: ${formatNum(item.prevClose)}',
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            // --- RIGHT COLUMN: LTP, Change, Bid/Ask ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // LTP with live tick color-flash
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: item.tickColor,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                  child: Text(
                    formatNum(item.ltp),
                  ),
                ),
                const SizedBox(height: 3),
                // Change indicator
                Text(
                  changeText,
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                // Bid and Sell depth indicators
                Text(
                  'B:${formatNum(item.bid)} S:${formatNum(item.ask)}',
                  style: const TextStyle(
                    color: Color(0xFF42A5F5), // Light blue depth line
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
