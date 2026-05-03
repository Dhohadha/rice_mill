import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class GaugeWidget extends StatelessWidget {
  final String title;
  final double value;
  final double max;
  final String unit;
  final VoidCallback onTap;

  const GaugeWidget({
    super.key,
    required this.title,
    required this.value,
    required this.max,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(
            height: 150,
            width: 150,
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: 0,
                  maximum: max,
                  showLabels: true,
                  showTicks: true,
                  axisLineStyle: const AxisLineStyle(
                    thickness: 0.15,
                    thicknessUnit: GaugeSizeUnit.factor,
                  ),
                  pointers: <GaugePointer>[
                    NeedlePointer(
                      value: value,
                      needleStartWidth: 1,
                      needleEndWidth: 5,
                      knobStyle: const KnobStyle(knobRadius: 0.08),
                    )
                  ],
                  ranges: <GaugeRange>[
                    GaugeRange(startValue: 0, endValue: max * 0.5, color: Colors.green),
                    GaugeRange(startValue: max * 0.5, endValue: max * 0.8, color: Colors.yellow),
                    GaugeRange(startValue: max * 0.8, endValue: max, color: Colors.red),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      angle: 90,
                      positionFactor: 0.8,
                      widget: Text(
                        '${value.toStringAsFixed(2)} $unit',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
