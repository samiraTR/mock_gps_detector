import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class MockGpsDetector {
  const MockGpsDetector();

  static const MethodChannel _channel =
      MethodChannel('com.example.mock_gps_detector/gps_detector');

  Future<Map<String, dynamic>> getDeveloperOptionsStatus() async {
    _assertAndroid();
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
          'getDeveloperOptionsStatus',
        ) ??
        {};
    return <String, dynamic>{
      'developerOptionsEnabled':
          (raw['developerOptionsEnabled'] as bool?) ?? false,
      'selectedMockLocationApp': raw['selectedMockLocationApp'] as String?,
      'hasSelectedMockLocationApp':
          (raw['selectedMockLocationApp'] as String?) != null,
    };
  }

  Future<bool> isDeveloperOptionsEnabled() async {
    _assertAndroid();
    return await _channel.invokeMethod<bool>('isDeveloperOptionsEnabled') ??
        false;
  }

  Future<String?> getSelectedMockLocationApp() async {
    _assertAndroid();
    return await _channel.invokeMethod<String>('getSelectedMockLocationApp');
  }

  Future<bool> isMockLocationAppSelected() async {
    _assertAndroid();
    return await _channel.invokeMethod<bool>('isMockLocationAppSelected') ??
        false;
  }

  Future<void> openDeveloperOptions() async {
    _assertAndroid();
    await _channel.invokeMethod<void>('openDeveloperOptions');
  }

  Future<Map<dynamic, dynamic>?> diagnoseMockApps() async {
    _assertAndroid();
    return _channel.invokeMethod<Map<dynamic, dynamic>>('diagnoseMockApps');
  }

  Future<Map<dynamic, dynamic>?> diagnoseMockLocation() async {
    _assertAndroid();
    return _channel.invokeMethod<Map<dynamic, dynamic>>('diagnoseMockLocation');
  }

  void _assertAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
          'mock_gps_detector currently supports Android only.');
    }
  }
}
