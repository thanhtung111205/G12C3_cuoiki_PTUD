import 'package:flutter/services.dart';

class FlashcardHaptics {
  FlashcardHaptics._();

  static const MethodChannel _channel = MethodChannel('cki_demo/haptics');

  static Future<void> shuffle() async {
    await confirmShuffle();
  }

  static Future<void> confirmShuffle() async {
    try {
      await _channel.invokeMethod<void>(
        'vibrate',
        const <String, dynamic>{'durationMs': 120},
      );
      return;
    } catch (_) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  static Future<void> cooldownThud() async {
    try {
      await _channel.invokeMethod<void>(
        'vibrate',
        const <String, dynamic>{'durationMs': 220},
      );
      return;
    } catch (_) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }
}