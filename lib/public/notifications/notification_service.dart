import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static Future<void> createNotification({
    required String title,
    required String body,
    required List<String> targets,
    String type = 'general',
    Map<String, dynamic>? data,
    String? senderUid,
    String? senderRole,
    bool pushEnabled = true,
  }) async {
    final id = FirebaseFirestore.instance.collection('notifications').doc().id;
    await FirebaseFirestore.instance.collection('notifications').doc(id).set({
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'targets': targets,
      'data': data ?? <String, dynamic>{},
      'sender_uid': senderUid ?? '',
      'sender_role': senderRole ?? '',
      'push_enabled': pushEnabled,
      'created_at': Timestamp.now(),
      'read_by': <String>[],
      'pushed_to': <String>[],
    }, const SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>> listFor({
    required String uid,
    required String role,
    String? classId,
  }) async {
    final result = <Map<String, dynamic>>[];
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('created_at', descending: true)
        .get();

    for (final doc in snap.docs) {
      final map = Map<String, dynamic>.from(doc.data());
      final targets = (map['targets'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      final directTargets =
          targets.where((target) => !_isScopedTarget(target)).toList();
      final roleTargets =
          targets.where((target) => target.startsWith('role:')).toList();
      final classTargets =
          targets.where((target) => target.startsWith('class:')).toList();

      final roleMatch = role.isNotEmpty && roleTargets.contains('role:$role');
      final classMatch = classId != null &&
          classId.isNotEmpty &&
          (classTargets.contains('class:$classId') ||
              map['class-room']?.toString() == classId ||
              map['classroom']?.toString() == classId);
      final hasScopedAudience =
          directTargets.isNotEmpty || classTargets.isNotEmpty;

      var isForUser = false;
      if (targets.contains('all')) {
        isForUser = true;
      } else if (directTargets.contains(uid)) {
        isForUser = true;
      } else if (!hasScopedAudience && roleMatch) {
        isForUser = true;
      } else if (classTargets.isNotEmpty && roleTargets.isEmpty && classMatch) {
        isForUser = true;
      } else if (classTargets.isNotEmpty && roleTargets.isNotEmpty) {
        isForUser = classMatch && roleMatch;
      }

      if (!isForUser) {
        continue;
      }
      result.add(map);
    }

    return result;
  }

  static Future<void> markRead({
    required String notificationId,
    required String uid,
  }) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({
      'read_by': FieldValue.arrayUnion([uid]),
    });
  }

  static Future<void> markPushed({
    required String notificationId,
    required String uid,
  }) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({
      'pushed_to': FieldValue.arrayUnion([uid]),
      'last_pushed_at': Timestamp.now(),
    });
  }

  static bool _isScopedTarget(String target) {
    return target == 'all' ||
        target.startsWith('role:') ||
        target.startsWith('class:');
  }
}
