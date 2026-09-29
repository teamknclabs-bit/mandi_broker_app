import 'package:flutter/material.dart';

class MarketViewScreen extends StatefulWidget {
  const MarketViewScreen({super.key});

  @override
  State<MarketViewScreen> createState() => _MarketViewScreenState();
}

class _MarketViewScreenState extends State<MarketViewScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'ALL';

  final List<Map<String, String>> _allMandiRates = [
    {
      'jins': 'JEERA (जीरा)',
      'bhav': '₹24,000 - ₹28,500',
      'arrival': '1,450 Bags',
      'category': 'SPICES',
      'trend': '+₹250',
    },
    {
      'jins': 'SAUNF (सौंफ)',
      'bhav': '₹8,500 - ₹14,200',
      'arrival': '920 Bags',
      'category': 'SPICES',
      'trend': '+₹100',
    },
    {
      'jins': 'ISABGOL (ईसबगोल)',
      'bhav': '₹12,000 - ₹15,800',
      'arrival': '680 Bags',
      'category': 'SPICES',
      'trend': '-₹150',
    },
    {
      'jins': 'CHANA (चना)',
      'bhav': '₹5,400 - ₹5,850',
      'arrival': '2,100 Bags',
      'category': 'GRAINS',
      'trend': '+₹50',
    },
    {
      'jins': 'DHANIYA (धनिया)',
      'bhav': '₹6,800 - ₹7,900',
      'arrival': '540 Bags',
      'category': 'SPICES',
      'trend': '₹0',
    },
    {
      'jins': 'RAYDA (रायड़ा / सरसों)',
      'bhav': '₹5,100 - ₹5,650',
      'arrival': '1,120 Bags',
      'category': 'OILSEEDS',
      'trend': '+₹80',
    },
    {
      'jins': 'WHEAT (गेहूं)',
      'bhav': '₹2,350 - ₹2,700',
      'arrival': '3,400 Bags',
      'category': 'GRAINS',
      'trend': '+₹20',
    },
    {
      'jins': 'GUAR SEED (ग्वार गम / बीज)',
      'bhav': '₹5,150 - ₹5,450',
      'arrival': '1,890 Bags',
      'category': 'GRAINS',
      'trend': '-₹40',
    },
    {
      'jins': 'CASTOR (अरंडी)',
      'bhav': '₹5,800 - ₹6,150',
      'arrival': '760 Bags',
      'category': 'OILSEEDS',
      'trend': '+₹35',
    },
  ];

  List<Map<String, String>> get _filteredRates {
    final query = _searchCtrl.text.trim().toUpperCase();
    return _allMandiRates.where((item) {
      final matchesCategory =
          _selectedCategory == 'ALL' || item['category'] == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          item['jins']!.toUpperCase().contains(query) ||
          item['bhav']!.contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRates;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Daily Mandi Bhav (दैनिक मंडी भाव)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Announcement Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.public,
                        color: Color(0xFF10B981),
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'APMC Live Auction Rates (मंडी भाव एवं आवक)',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Direct market updates • Commodity spot prices per quintal',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search commodity (e.g. Jeera, Chana, सरसों)...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF10B981),
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All (सभी)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('SPICES', 'Spices (मसाले)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('GRAINS', 'Grains & Pulses (दलहन/अनाज)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('OILSEEDS', 'Oilseeds (तिलहन)'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // List of Commodities
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Text(
                      'No commodities match "${_searchCtrl.text}"',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isPositive = item['trend']!.startsWith('+');
                      final isNegative = item['trend']!.startsWith('-');

                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF10B981)
                                    .withValues(alpha: 0.12),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['jins']!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Arrival: ${item['arrival']}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item['bhav']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPositive
                                          ? Colors.green.shade50
                                          : (isNegative
                                              ? Colors.red.shade50
                                              : Colors.grey.shade100),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item['trend']!,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: isPositive
                                            ? Colors.green.shade700
                                            : (isNegative
                                                ? Colors.red.shade700
                                                : Colors.grey.shade700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String categoryKey, String label) {
    final isSelected = _selectedCategory == categoryKey;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : Colors.black87,
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF10B981),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedCategory = categoryKey);
      },
    );
  }
}
