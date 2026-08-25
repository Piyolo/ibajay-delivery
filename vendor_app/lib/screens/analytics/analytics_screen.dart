import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/menu_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _rangeIndex = 1; // 0=Daily 1=Weekly 2=Monthly

  // Mock sales series per range — replace with GET /vendor/analytics
  final Map<int, List<double>> _series = {
    0: [1200, 0, 0, 0, 0, 0, 0], // today only, illustrative
    1: [2400, 3100, 1800, 4200, 3900, 5100, 4700],
    2: [18000, 21000, 19500, 26000],
  };

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    final bestSellers = [...menu.items]..sort((a, b) => b.totalSold.compareTo(a.totalSold));
    final data = _series[_rangeIndex]!;
    final total = data.fold<double>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Daily')),
                ButtonSegment(value: 1, label: Text('Weekly')),
                ButtonSegment(value: 2, label: Text('Monthly')),
              ],
              selected: {_rangeIndex},
              onSelectionChanged: (s) => setState(() => _rangeIndex = s.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _metricCard('Total Sales', '₱${total.toStringAsFixed(0)}', AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(child: _metricCard('Total Orders', '${(total / 180).round()}', AppColors.secondary)),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: [
                        for (int i = 0; i < data.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: data[i],
                              color: AppColors.primary,
                              width: 18,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const SectionHeader(title: 'Best Selling Items'),
            ...bestSellers.take(5).map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.surfaceMuted,
                      child: Icon(Icons.fastfood_outlined, color: AppColors.textSecondary),
                    ),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('₱${item.price.toStringAsFixed(0)}'),
                    trailing: Text('${item.totalSold} sold', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
