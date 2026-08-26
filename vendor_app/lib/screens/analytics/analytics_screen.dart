import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<OrderProvider>().fetchAnalytics();
  }

  void _reload() {
    setState(() => _future = context.read<OrderProvider>().fetchAnalytics());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return EmptyState(
                icon: Icons.bar_chart,
                title: 'Could not load analytics',
                subtitle: snap.error?.toString() ?? 'Please try again.',
                action: OutlinedButton(onPressed: _reload, child: const Text('Retry')),
              );
            }
            final data = snap.data!;
            return _AnalyticsBody(data: data);
          },
        ),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnalyticsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final todayRevenue = (data['today_revenue'] as num?)?.toDouble() ?? 0;
    final todayOrders = (data['today_orders'] as num?)?.toInt() ?? 0;
    final completedToday = (data['completed_today'] as num?)?.toInt() ?? 0;
    final cancelledToday = (data['cancelled_today'] as num?)?.toInt() ?? 0;

    final week = ((data['week'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
                child: _metricCard(
                    'Sales Today', '₱${todayRevenue.toStringAsFixed(0)}', AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(
                child:
                    _metricCard('Orders Today', '$todayOrders', AppColors.secondary)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _metricCard('Completed', '$completedToday', AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: _metricCard('Cancelled', '$cancelledToday', AppColors.danger)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: Text('Revenue · last 7 days',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                  height: 180,
                  child: week.isEmpty
                      ? const Center(
                          child: Text('No data yet',
                              style: TextStyle(color: AppColors.textSecondary)))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) => SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      _dayLabel(week, value.toInt()),
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            barGroups: [
                              for (int i = 0; i < week.length; i++)
                                BarChartGroupData(x: i, barRods: [
                                  BarChartRodData(
                                    toY: (week[i]['revenue'] as num?)?.toDouble() ?? 0,
                                    color: AppColors.primary,
                                    width: 18,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ]),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (week.isNotEmpty)
          ...week.reversed.take(7).map((d) {
            final revenue = (d['revenue'] as num?)?.toDouble() ?? 0;
            final orders = (d['orders'] as num?)?.toInt() ?? 0;
            final date = DateTime.tryParse(d['date'] as String? ?? '');
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(date != null
                    ? DateFormat('EEE, MMM d').format(date)
                    : (d['date'] as String? ?? '')),
                subtitle: Text('$orders order(s)'),
                trailing: Text('₱${revenue.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            );
          }),
      ],
    );
  }

  static String _dayLabel(List<Map<String, dynamic>> week, int index) {
    if (index < 0 || index >= week.length) return '';
    final date = DateTime.tryParse(week[index]['date'] as String? ?? '');
    return date != null ? DateFormat.E().format(date) : '';
  }

  Widget _metricCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
