import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:rice_mill/models/app_settings.dart';
import 'package:rice_mill/services/alert_manager.dart';

import '../services/providers.dart';
import '../widgets/gauge_widget.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _selectDate(BuildContext context, WidgetRef ref) async {
    final selectedDate = ref.read(selectedDateProvider);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      ref.read(selectedDateProvider.notifier).setDate(picked);
    }
  }

  Future<void> _navToSettings(
    BuildContext context,
    WidgetRef ref,
    String title,
    String type,
    double limit, [
    double? maxGauge,
  ]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          title: title,
          type: type,
          currentLimit: limit,
          currentMaxGauge: maxGauge,
        ),
      ),
    );

    if (result != null) {
      Map<String, dynamic> updates = {};
      if (type == 'CMD') {
        updates['cmdLimit'] = result['limit'];
        updates['cmdMaxGauge'] = result['maxGauge'];
      } else if (type == 'POWER') {
        updates['powerLimit'] = result['limit'];
        updates['powerMaxGauge'] = result['maxGauge'];
      } else if (type == 'PF') {
        updates['pfLimit'] = result['limit'];
      }
      ref.read(settingsProvider.notifier).updateSettings(updates);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mqttData = ref.watch(mqttDataProvider);
    final settings = ref.watch(settingsProvider);
    final consumedKwh = ref.watch(consumedKwhProvider);
    final isDayGraph = ref.watch(isDayGraphProvider);
    final graphData = ref.watch(graphDataProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final alertState = ref.watch(alertManagerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Radha Krishna Rice Mill',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: Colors.blue,
              size: 28,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: mqttData.isLoading && !mqttData.hasValue
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Connecting to Rice Mill...',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                // Refresh all data
                await Future.wait([
                  ref.read(settingsProvider.notifier).loadSettings(),
                  ref.refresh(graphDataProvider.future),
                  ref.refresh(consumedKwhProvider.future),
                ]);
              },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              if (alertState.activeAlerts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      ...alertState.activeAlerts.map(
                        (alert) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  alert,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: alertState.isAlarmStopped
                                    ? null
                                    : () => ref
                                          .read(alertManagerProvider.notifier)
                                          .stopAlarm(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: alertState.isAlarmStopped
                                        ? Colors.grey
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    alertState.isAlarmStopped
                                        ? 'STOPPED'
                                        : 'STOP',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              // Gauges Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildGaugeWithLimit(
                    context,
                    ref,
                    'CMD',
                    mqttData.value?.kVATotal ?? 0,
                    settings?.cmdMaxGauge ?? 250,
                    settings?.cmdLimit ?? 104,
                    'kVA',
                  ),
                  _buildGaugeWithLimit(
                    context,
                    ref,
                    'POWER',
                    mqttData.value?.kWTotal ?? 0,
                    settings?.powerMaxGauge ?? 250,
                    settings?.powerLimit ?? 104,
                    'kW',
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // Middle 4-item section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFA5E6C9), // Matching the image green
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'LIVE KVA',
                            mqttData.value?.kVATotal.toStringAsFixed(2) ?? '0.00',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'CONSUMED kWh',
                            consumedKwh.when(
                              data: (d) => d.toStringAsFixed(2),
                              error: (err, stack) => 'Error',
                              loading: () => '...',
                            ),
                            footer: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 14,
                                      color: Colors.black54,
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                                Text(
                                  DateFormat('MM/dd').format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _selectDate(context, ref),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'POWER FACTOR',
                            mqttData.value?.pfAvg.toStringAsFixed(3) ?? '0.000',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'PF LIMIT',
                            settings?.pfLimit.toStringAsFixed(2) ?? '0.90',
                            footer: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.segment,
                                  size: 12,
                                  color: Colors.black54,
                                ),
                                Text(
                                  ' Edit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _navToSettings(
                              context,
                              ref,
                              'PF limit',
                              'PF',
                              settings?.pfLimit ?? 0.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // Toggle Hour / Day
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleButton(ref, 'Hour', !isDayGraph),
                    _buildToggleButton(ref, 'Day', isDayGraph),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Graph
              Container(
                height: 200,
                padding: const EdgeInsets.only(right: 16, top: 16),
                child: graphData.when(
                  data: (data) => data.isEmpty
                      ? const Center(child: Text('No history data available'))
                      : LineChart(_buildChartData(data, settings)),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: 10),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegend(Colors.blue, 'KVA (CMD)'),
                  const SizedBox(width: 20),
                  _buildLegend(Colors.green, 'KW (Power)'),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildGaugeWithLimit(
    BuildContext context,
    WidgetRef ref,
    String title,
    double value,
    double max,
    double limit,
    String unit,
  ) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ' Limit: ${limit.toStringAsFixed(1)} $unit',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GaugeWidget(
          title: '', // title is handled above
          value: value,
          max: max,
          unit: unit,
          onTap: () => _navToSettings(
            context,
            ref,
            '$title Settings',
            title,
            limit,
            max,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value, {
    Widget? footer,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: label == 'CONSUMED kWh'
                          ? Colors.blue[800]
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            if (footer != null) ...[
              const SizedBox(height: 6),
              footer,
            ] else
              const SizedBox(
                height: 18,
              ), // Spacer to maintain alignment if no footer
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(WidgetRef ref, String text, bool isActive) {
    return GestureDetector(
      onTap: () => ref.read(isDayGraphProvider.notifier).toggle(text == 'Day'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  LineChartData _buildChartData(List<dynamic> data, AppSettings? settings) {
    double maxY = settings?.cmdMaxGauge ?? 250;
    if (maxY < 10) maxY = 250; // Fallback for invalid settings

    return LineChartData(
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey[200]!, strokeWidth: 1),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: settings?.cmdLimit ?? 104,
            color: Colors.red.withValues(alpha: 0.4),
            strokeWidth: 2,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              labelResolver: (line) => 'Limit',
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, 
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: data
              .asMap()
              .entries
              .map(
                (e) => FlSpot(
                  e.key.toDouble(),
                  ((e.value['KVA'] ?? 0) as num).toDouble(),
                ),
              )
              .toList(),
          isCurved: true,
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          color: Colors.blue.withValues(alpha: 0.7),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withValues(alpha: 0.1),
          ),
        ),
        LineChartBarData(
          spots: data
              .asMap()
              .entries
              .map(
                (e) => FlSpot(
                  e.key.toDouble(),
                  ((e.value['KW'] ?? 0) as num).toDouble(),
                ),
              )
              .toList(),
          isCurved: true,
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          color: Colors.green.withValues(alpha: 0.7),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.green.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Icon(Icons.change_history, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
