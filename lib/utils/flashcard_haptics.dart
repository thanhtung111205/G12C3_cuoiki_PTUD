import 'package:flutter/services.dart';

class FlashcardHaptics {
  FlashcardHaptics._();

  static const MethodChannel _channel = MethodChannel('cki_demo/haptics');

  static Future<void> shuffle() async {
    try {
      await _channel.invokeMethod<void>(
        'vibrate',
        const <String, dynamic>{'durationMs': 180},
      );
      return;
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }
}