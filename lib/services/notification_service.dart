import 'package:flutter/services.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  DateTime? _lastSoundAt;
  final Set<String> _playedEventKeys = <String>{};

  Future<void> playIncomingMessageSound({required String eventKey}) async {
    if (_playedEventKeys.contains(eventKey)) {
      return;
    }

    final DateTime now = DateTime.now();
    if (_lastSoundAt != null &&
        now.difference(_lastSoundAt!).inMilliseconds < 900) {
      return;
    }

    _playedEventKeys.add(eventKey);
    if (_playedEventKeys.length > 300) {
      _playedEventKeys.remove(_playedEventKeys.first);
    }

    _lastSoundAt = now;
    await SystemSound.play(SystemSoundType.alert);
  }
}
