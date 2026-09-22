import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sensor_data_source.dart';
import 'sensor_models.dart';
import 'sensor_service.dart';

/// Provider exposing the injectable ISensorService instance
/// Owner: Nishant (Phase 4 — Sensor State Management)
final sensorServiceProvider = Provider<ISensorService>((ref) {
  final service = SensorService(dataSource: RealSensorDataSource());
  service.initialize();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Riverpod StateNotifier managing the UI-facing SensorState
class SensorNotifier extends StateNotifier<SensorState> {
  final ISensorService _service;
  StreamSubscription<SensorState>? _serviceSub;

  SensorNotifier(this._service) : super(_service.state) {
    _serviceSub = _service.stateStream.listen((newState) {
      if (mounted) {
        state = newState;
      }
    });
  }

  @override
  void dispose() {
    _serviceSub?.cancel();
    _serviceSub = null;
    super.dispose();
  }

  void start() {
    _service.start();
    state = _service.state;
  }

  Future<SensorPermissionStatus> requestPermissions() async {
    final status = await _service.requestPermissions();
    state = _service.state;
    return status;
  }

  void pause() {
    _service.pause();
    state = _service.state;
  }

  void resume() {
    _service.resume();
    state = _service.state;
  }

  void stop() {
    _service.stop();
    state = _service.state;
  }

  void reset() {
    _service.reset();
    state = _service.state;
  }

  void calibrate() {
    _service.calibrate();
    state = _service.state;
  }

  void setStepLength(double length) {
    _service.setStepLength(length);
    state = _service.state;
  }
}

/// Global StateNotifierProvider exposing clean immutable SensorState
final sensorStateProvider = StateNotifierProvider<SensorNotifier, SensorState>((ref) {
  final service = ref.watch(sensorServiceProvider);
  return SensorNotifier(service);
});
