import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_storage/get_storage.dart';
import 'package:school_management_system/public/notifications/notification_service.dart';

class NotificationPushBridge {
  static final GetStorage _storage = GetStorage();
  static Timer? _timer;
  static bool _syncing = false;
  static String _uid = '';
  static String _role = '';
  static String _classId = '';

  static void start({
    required String uid,
    required String role,
    String? classId,
  }) {
    final nextUid = uid.trim();
    final nextRole = role.trim();
    final nextClassId = (classId ?? '').trim();

    if (nextUid.isEmpty || nextRole.isEmpty) {
      stop();
      return;
    }

    final unchanged =
        _uid == nextUid && _role == nextRole && _classId == nextClassId;
    if (unchanged && _timer != null) {
      return;
    }

    stop();
    _uid = nextUid;
    _role = nextRole;
    _classId = nextClassId;
    unawaited(syncNow());
    _timer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(syncNow()),
    );
  }

  static void startFromStorage() {
    final uid = (_storage.read('uid') ?? '').toString();
    final role = (_storage.read('role') ?? '').toString();
    final classId = (_storage.read('classid') ?? '').toString();
    start(uid: uid, role: role, classId: classId);
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _syncing = false;
    _uid = '';
    _role = '';
    _classId = '';
  }

  static Future<void> syncNow() async {
    if (_syncing || _uid.isEmpty || _role.isEmpty) {
      return;
    }

    _syncing = true;
    try {
      final rows = await NotificationService.listFor(
        uid: _uid,
        role: _role,
        classId: _classId,
      );
      rows.sort(
        (a, b) => _sortValue(a['created_at']).compareTo(_sortValue(b['created_at'])),
      );

      final delivered = _deliveredNotificationIds();
      for (final item in rows) {
        final id = (item['id'] ?? '').toString();
        final pushEnabled = item['push_enabled'] != false;
        if (id.isEmpty || !pushEnabled || delivered.contains(id)) {
          continue;
        }

        await FirebaseMessaging.instance.simulateIncomingMessage(
          RemoteMessage(
            messageId: id,
            notification: RemoteNotification(
              title: (item['title'] ?? '').toString(),
              body: (item['body'] ?? '').toString(),
              android: AndroidNotification(channelId: 'high_importance_channel'),
            ),
            data: _stringifyData(item),
          ),
        );

        delivered.add(id);
        await _storage.write(_deliveredKey(), delivered.toList());
        await NotificationService.markPushed(notificationId: id, uid: _uid);
      }
    } finally {
      _syncing = false;
    }
  }

  static Set<String> _deliveredNotificationIds() {
    final raw = _storage.read(_deliveredKey());
    if (raw is List) {
      return raw.map((item) => item.toString()).toSet();
    }
    return <String>{};
  }

  static String _deliveredKey() => 'delivered_notifications_$_uid';

  static int _sortValue(dynamic value) {
    try {
      return value.toDate().millisecondsSinceEpoch as int;
    } catch (_) {
      return 0;
    }
  }

  static Map<String, dynamic> _stringifyData(Map<String, dynamic> item) {
    final data = <String, dynamic>{
      'notification_id': (item['id'] ?? '').toString(),
      'type': (item['type'] ?? 'general').toString(),
    };
    final payload = item['data'];
    if (payload is Map<String, dynamic>) {
      payload.forEach((key, value) {
        data[key] = value?.toString() ?? '';
      });
    }
    return data;
  }
}