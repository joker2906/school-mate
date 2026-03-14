import 'dart:async';
import 'dart:math';

typedef BackgroundMessageHandler = Future<void> Function(RemoteMessage message);

class RemoteNotification {
  final String? title;
  final String? body;
  final AndroidNotification? android;

  RemoteNotification({this.title, this.body, this.android});
}

class AndroidNotification {
  final String? channelId;

  AndroidNotification({this.channelId});
}

class RemoteMessage {
  final String? messageId;
  final RemoteNotification? notification;
  final Map<String, dynamic> data;

  RemoteMessage({this.messageId, this.notification, this.data = const {}});
}

class FirebaseMessaging {
  FirebaseMessaging._();

  static final FirebaseMessaging instance = FirebaseMessaging._();

  static final StreamController<RemoteMessage> _onMessageController =
      StreamController<RemoteMessage>.broadcast();
  static final StreamController<RemoteMessage> _onOpenedController =
      StreamController<RemoteMessage>.broadcast();
  static final StreamController<String> _onTokenController =
      StreamController<String>.broadcast();

  static Stream<RemoteMessage> get onMessage => _onMessageController.stream;

  static Stream<RemoteMessage> get onMessageOpenedApp =>
      _onOpenedController.stream;

  static BackgroundMessageHandler? _backgroundHandler;
  static RemoteMessage? _initialMessage;

  static void onBackgroundMessage(BackgroundMessageHandler handler) {
    _backgroundHandler = handler;
  }

  Stream<String> get onTokenRefresh => _onTokenController.stream;

  Future<String?> getToken() async {
    final token = _randomToken();
    _onTokenController.add(token);
    return token;
  }

  Future<RemoteMessage?> getInitialMessage() async {
    final message = _initialMessage;
    _initialMessage = null;
    return message;
  }

  Future<void> setForegroundNotificationPresentationOptions({
    required bool alert,
    required bool badge,
    required bool sound,
  }) async {
    // No-op in FastAPI migration mode.
  }

  Future<void> simulateIncomingMessage(
    RemoteMessage message, {
    bool openedApp = false,
    bool makeInitialMessage = false,
  }) async {
    if (makeInitialMessage) {
      _initialMessage = message;
    }
    _onMessageController.add(message);
    if (openedApp) {
      _onOpenedController.add(message);
    }
  }

  static String _randomToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(32, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
