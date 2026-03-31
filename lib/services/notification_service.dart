import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _chatChannelId = 'chat_messages';
  static const String _chatChannelName = 'Tin nhan chat';
  static const String _chatChannelDescription =
      'Thong bao tin nhan moi trong ung dung';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  DateTime? _lastSoundAt;
  final Set<String> _playedEventKeys = <String>{};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _notificationsPlugin.initialize(settings);

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _chatChannelId,
        _chatChannelName,
        description: _chatChannelDescription,
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> playIncomingMessageSound({
    required String eventKey,
    String title = 'Tin nhan moi',
    String body = 'Ban vua nhan duoc mot tin nhan moi.',
  }) async {
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

    try {
      await initialize();
      await _notificationsPlugin.show(
        eventKey.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _chatChannelId,
            _chatChannelName,
            channelDescription: _chatChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
          ),
        ),
      );
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }
}
