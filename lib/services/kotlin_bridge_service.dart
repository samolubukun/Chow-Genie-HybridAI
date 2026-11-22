import 'dart:developer' as developer;
import 'package:flutter/services.dart';

/// Service for communicating with native Android Kotlin code via MethodChannel.
class KotlinBridgeService {
  KotlinBridgeService._();

  /// Singleton instance of [KotlinBridgeService].
  static final KotlinBridgeService instance = KotlinBridgeService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.chow_genie/kotlin_bridge');

  /// Fetches the Android OS and SDK version directly from Kotlin.
  Future<String?> getPlatformVersion() async {
    try {
      final String? version =
          await _channel.invokeMethod<String>('getPlatformVersion');
      return version;
    } on PlatformException catch (e) {
      developer.log('Failed to get platform version: ${e.message}',
          name: 'KotlinBridge');
      return null;
    } on MissingPluginException {
      developer.log(
          'Kotlin bridge is inactive on this platform (e.g. Web/Desktop)',
          name: 'KotlinBridge');
      return null;
    }
  }

  /// Checks the Kotlin bridge connectivity and retrieves runtime metadata.
  Future<Map<String, dynamic>?> checkKotlinBridge({
    String message = 'Ping from Flutter',
  }) async {
    try {
      final dynamic result = await _channel.invokeMethod(
        'getKotlinBridgeStatus',
        {'message': message},
      );
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      developer.log('Failed to check Kotlin bridge: ${e.message}',
          name: 'KotlinBridge');
      return {'status': 'error', 'message': e.message};
    } on MissingPluginException {
      return {
        'status': 'unsupported_platform',
        'message': 'Running on web or non-Android environment'
      };
    }
  }

  /// Executes an asynchronous Kotlin background task via Coroutines.
  Future<String?> executeAsyncKotlinTask(String payload) async {
    try {
      final String? result = await _channel.invokeMethod<String>(
        'executeAsyncKotlinTask',
        {'payload': payload},
      );
      return result;
    } on PlatformException catch (e) {
      developer.log('Async Kotlin task failed: ${e.message}',
          name: 'KotlinBridge');
      return null;
    } on MissingPluginException {
      return 'Kotlin bridge is active on Android targets.';
    }
  }
}
