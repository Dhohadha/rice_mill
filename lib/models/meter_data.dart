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
      kVATotal: (json['kVA_Total'] ?? 0).toDouble(),
      kWTotal: (json['kW_Total'] ?? 0).toDouble(),
      pfAvg: (json['PF_Avg'] ?? 0).toDouble(),
      kWh: (json['kWh'] ?? 0).toDouble(),
    );
  }
}
