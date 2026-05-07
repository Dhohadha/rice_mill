class MeterData {
  final double kVATotal;
  final double kWTotal;
  final double pfAvg;
  final double kWh;

  MeterData({
    required this.kVATotal,
    required this.kWTotal,
    required this.pfAvg,
    required this.kWh,
  });

  factory MeterData.fromJson(Map<String, dynamic> json) {
    return MeterData(
      kVATotal: (json['KVA'] ?? 0).toDouble(),
      kWTotal: (json['KW'] ?? 0).toDouble(),
      pfAvg: (json['PF'] ?? 0).toDouble(),
      kWh: (json['KWH'] ?? 0).toDouble(),
    );
  }
}
