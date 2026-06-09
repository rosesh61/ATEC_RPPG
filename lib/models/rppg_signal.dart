class RppgSignal {
  final List<double> signal;
  final double timestamp;
  final double? heartRate;
  final bool isNewHrCalculation;

  RppgSignal({
    required this.signal,
    required this.timestamp,
    this.heartRate,
    this.isNewHrCalculation = false,
  });
}
