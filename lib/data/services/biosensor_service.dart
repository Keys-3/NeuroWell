import 'dart:async';
import 'dart:math';
import '../models/biosensor_data_model.dart';
import 'blynk_service.dart';

/// Service that generates biosensor data based on Blynk connection status
class BiosensorService {
  final BlynkService _blynkService = BlynkService();
  final _controller = StreamController<BiosensorData?>.broadcast();
  final _statusController = StreamController<BlynkStatus>.broadcast();
  StreamSubscription? _blynkSubscription;
  Timer? _dataTimer;
  final Random _random = Random();

  // Base values for realistic oscillation
  double _hrBase = 75.0;
  double _spo2Base = 97.0;
  double _gsrBase = 2.5;
  
  // ECG simulation
  double _ecgPhase = 0.0;

  // Current status
  BlynkStatus _currentStatus = BlynkStatus.offline;

  Stream<BiosensorData?> get dataStream => _controller.stream;
  Stream<BlynkStatus> get statusStream => _statusController.stream;
  Stream<String> get logStream => _blynkService.logStream; // Expose logs
  String get lastError => _blynkService.lastError;
  BlynkStatus get currentStatus => _currentStatus;

  void startSimulation() {
    // Start Blynk polling
    _blynkService.startPolling();

    // Listen to Blynk status changes
    _blynkSubscription = _blynkService.statusStream.listen((status) {
      print('[BiosensorService] Blynk status: $status');
      _currentStatus = status;
      _statusController.add(status);
      
      switch (status) {
        case BlynkStatus.offline:
          // Device offline - emit null (will show offline banner)
          _stopDataGeneration();
          _controller.add(null);
          break;
          
        case BlynkStatus.loading:
          // Just wait, maybe emit null or handle in UI
          _stopDataGeneration();
          _controller.add(null);
          break;

        case BlynkStatus.onlineNoData:
          // Device online but dummy OFF - emit zeros continuously
          _startZeroDataGeneration();
          break;
          
        case BlynkStatus.simulationNormal:
        case BlynkStatus.simulationStress:
          // Device online and dummy ON - generate continuous data
          _startDataGeneration();
          break;
      }
    });
  }

  void _startDataGeneration() {
    _dataTimer?.cancel();
    // Generate data every 1 second
    _dataTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentStatus == BlynkStatus.simulationNormal || 
          _currentStatus == BlynkStatus.simulationStress) {
        _generateAndEmitData();
      }
    });
    // Emit immediately
    _generateAndEmitData();
  }

  void _startZeroDataGeneration() {
    _dataTimer?.cancel();
    // Generate 0 data every 1 second
    _dataTimer = Timer.periodic(const Duration(seconds: 1), (_) {
       _controller.add(BiosensorData(
          timestamp: DateTime.now(),
          heartRate: 0,
          spo2: 0,
          gsr: 0.0,
          ecgData: List.filled(100, 0.0),
       ));
    });
    // Emit immediately
    _controller.add(BiosensorData(
        timestamp: DateTime.now(),
        heartRate: 0,
        spo2: 0,
        gsr: 0.0,
        ecgData: List.filled(100, 0.0),
    )); 
  }

  void _stopDataGeneration() {
    _dataTimer?.cancel();
    _dataTimer = null;
  }

  void _generateAndEmitData() {
    double minHr = 60.0;
    double maxHr = 100.0;
    double minSpo2 = 95.0;
    double maxSpo2 = 100.0;

    // Adjust ranges for Stress Mode
    if (_currentStatus == BlynkStatus.simulationStress) {
      minHr = 110.0; // Increased base
      maxHr = 150.0; // Increased peak
      minSpo2 = 88.0; // Lowered for higher stress score
      maxSpo2 = 94.0;
    }

    // Normal ranges: HR 60-100, SpO2 95-100
    // Stress ranges: HR 100-140, SpO2 93-97
    
    _hrBase += (_random.nextDouble() - 0.5) * 5;
    
    // If current base is outside target range, pull it back faster
    if (_hrBase < minHr) _hrBase += 2;
    if (_hrBase > maxHr) _hrBase -= 2;
    
    _hrBase = _hrBase.clamp(minHr, maxHr);
    
    _spo2Base += (_random.nextDouble() - 0.5) * 0.5;
    _spo2Base = _spo2Base.clamp(minSpo2, maxSpo2);
    
    _gsrBase += (_random.nextDouble() - 0.5) * 0.4;
    _gsrBase = _gsrBase.clamp(0.5, 4.0);

    // Generate ECG waveform
    List<double> ecgData = _generateEcgWaveform();

    final data = BiosensorData(
      timestamp: DateTime.now(),
      heartRate: _hrBase.round(),
      spo2: _spo2Base.round(),
      gsr: double.parse(_gsrBase.toStringAsFixed(2)),
      ecgData: ecgData,
    );

    _controller.add(data);
  }

  /// Generate realistic ECG PQRST waveform
  List<double> _generateEcgWaveform() {
    List<double> points = [];
    
    for (int i = 0; i < 100; i++) {
      double t = _ecgPhase + (i / 100.0) * 2 * pi;
      double value = 0;
      
      // P wave
      value += 0.15 * exp(-pow((t % (2 * pi)) - 0.8, 2) / 0.02);
      // QRS complex
      value -= 0.1 * exp(-pow((t % (2 * pi)) - 1.2, 2) / 0.002);
      value += 1.0 * exp(-pow((t % (2 * pi)) - 1.3, 2) / 0.003);
      value -= 0.2 * exp(-pow((t % (2 * pi)) - 1.4, 2) / 0.002);
      // T wave
      value += 0.25 * exp(-pow((t % (2 * pi)) - 1.9, 2) / 0.03);
      // Noise
      value += (_random.nextDouble() - 0.5) * 0.05;
      
      points.add(value);
    }
    
    _ecgPhase += 0.5;
    return points;
  }

  /// Force an immediate status check (bypass timer)
  Future<void> forceFetchStatus() async {
    await _blynkService.forceFetchStatus();
  }

  void stopSimulation() {
    _blynkService.stopPolling();
    _stopDataGeneration();
    _blynkSubscription?.cancel();
  }

  void dispose() {
    stopSimulation();
    _controller.close();
    _statusController.close();
  }
}
