import 'package:flutter/services.dart';

class FlashcardHaptics {
  FlashcardHaptics._();

  static const MethodChannel _channel = MethodChannel('cki_demo/haptics');

  static Future<void> shuffle() async {
    await confirmShuffle();
  }

  static Future<void> confirmShuffle() async {
    try {
      // Gọi mã Native để thực hiện cú rung kép cực mạnh (Amplitude 255)
      // durationMs = 150ms để đảm bảo mô-tơ rung chạy hết công suất
      await _channel.invokeMethod<void>(
        'vibrate',
        const <String, dynamic>{'durationMs': 150},
      );
      return;
    } catch (_) {
      try {
        // Fallback sang nốt rung mạnh nhất và dài nhất của Flutter
        await HapticFeedback.vibrate();
      } catch (_) {}
    }
  }

  static Future<void> cooldownThud() async {
    try {
      await _channel.invokeMethod<void>(
        'vibrate',
        const <String, dynamic>{'durationMs': 250},
      );
      return;
    } catch (_) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }
}
