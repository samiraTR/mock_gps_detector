import 'package:flutter/services.dart';

class DeveloperOptionsService {
  static const MethodChannel _channel =
      MethodChannel('smart_tcpl_mob/developer_options');

  DeveloperOptionsService._();

  static Future<Map<String, dynamic>> getDeveloperOptionsStatus() async {
    try {
      // This must match the "getDeveloperOptionsStatus" case in MainActivity.kt
      final Map<Object?, Object?> raw =
          await _channel.invokeMethod<Map<Object?, Object?>>(
                  'getDeveloperOptionsStatus') ??
              {};

      print('>>> RAW FROM KOTLIN: $raw'); 

      final bool devEnabled =
          (raw['developerOptionsEnabled'] as bool?) ?? false;
      final String? mockApp = raw['selectedMockLocationApp'] as String?;

      return {
        'developerOptionsEnabled': devEnabled,
        'selectedMockLocationApp': mockApp,
        'hasSelectedMockLocationApp': mockApp != null,
      };
    } on MissingPluginException catch (e) {
      print(
          '>>> MissingPluginException: $e'); 
      return _emptyStatus();
    } on PlatformException catch (e) {
      print('>>> PlatformException: $e');
      return _emptyStatus();
    } catch (e) {
      print('>>> Unknown error: $e');
      return _emptyStatus();
    }
  }

  static Future<void> checkDeveloperOptionIssue() async {
    final raw = await _channel.invokeMethod<Map>('diagnoseMockApps');
    print('>>> Total scanned: ${raw?['total_packages_scanned']}');
    final apps = raw?['mock_apps_found'] as List?;
    apps?.forEach((app) => print('>>> MOCK APP: $app'));
  }

  static Future<void> openDeveloperOptions() async {
    try {
      await _channel.invokeMethod('openDeveloperOptions');
    } catch (_) {}
  }

  static Map<String, dynamic> _emptyStatus() => {
        'developerOptionsEnabled': false,
        'selectedMockLocationApp': null,
        'hasSelectedMockLocationApp': false,
      };
}
