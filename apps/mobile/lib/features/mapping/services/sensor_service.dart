import 'dart:async';

/// Smartphone sensor reading models
class SensorReading {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  const SensorReading(this.x, this.y, this.z, this.timestamp);
}

/// Smartphone Sensor Service Interface & Stub
/// Owner: Nishant (Sensors & Creator Mapping Workflow)
///
/// Sensors are used strictly for creator-assisted map construction
/// (step counting, heading/bearing tracking, local coordinate estimation).
abstract class ISensorService {
  Stream<int> get stepCountStream;
  Stream<double> get compassHeadingStream;
  Stream<SensorReading> get accelerometerStream;
  Stream<SensorReading> get gyroscopeStream;

  void startRecording();
  void stopRecording();
  bool get isRecording;
}

class SensorService implements ISensorService {
  bool _isRecording = false;

  final _stepController = StreamController<int>.broadcast();
  final _headingController = StreamController<double>.broadcast();
  final _accelController = StreamController<SensorReading>.broadcast();
  final _gyroController = StreamController<SensorReading>.broadcast();

  @override
  Stream<int> get stepCountStream => _stepController.stream;

  @override
  Stream<double> get compassHeadingStream => _headingController.stream;

  @override
  Stream<SensorReading> get accelerometerStream => _accelController.stream;

  @override
  Stream<SensorReading> get gyroscopeStream => _gyroController.stream;

  @override
  bool get isRecording => _isRecording;

  @override
  void startRecording() {
    _isRecording = true;
  }

  @override
  void stopRecording() {
    _isRecording = false;
  }

  void dispose() {
    _stepController.close();
    _headingController.close();
    _accelController.close();
    _gyroController.close();
  }
}
