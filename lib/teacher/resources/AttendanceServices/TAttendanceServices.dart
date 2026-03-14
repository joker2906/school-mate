import 'package:cloud_firestore/cloud_firestore.dart';

class TAttendanceServices {
  Future<List<Map<String, String>>> getTeacherClasses(String teacherId) async {
    final classes = <Map<String, String>>[];
    final classIds = <String>{};

    final relations = await FirebaseFirestore.instance
        .collection('relation')
        .where('teacher', isEqualTo: teacherId)
        .get();

    for (final doc in relations.docs) {
      final list = doc.data()['classrooms'];
      if (list is List) {
        for (final item in list) {
          final id = item.toString();
          if (id.isNotEmpty) {
            classIds.add(id);
          }
        }
      }
    }

    for (final classId in classIds) {
      final snap = await FirebaseFirestore.instance
          .collection('class-room')
          .doc(classId)
          .get();
      final data = snap.data();
      if (data == null) {
        continue;
      }
      classes.add({
        'id': classId,
        'label': '${data['section']}-${data['acadimic_year']}',
      });
    }

    classes.sort((a, b) => a['label']!.compareTo(b['label']!));
    return classes;
  }

  Future<List<Map<String, dynamic>>> getStudentsForClass(String classId) async {
    final students = <Map<String, dynamic>>[];

    final snap = await FirebaseFirestore.instance
        .collection('students')
        .where('class_id', isEqualTo: classId)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final uid = (data['uid'] ?? doc.id).toString();
      students.add({
        'uid': uid,
        'name': '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
        'parent_email': (data['parent_email'] ?? '').toString(),
      });
    }

    students.sort((a, b) =>
        a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
    return students;
  }

  Future<Map<String, String>> getAttendanceForDate(
    String classId,
    String dateKey,
  ) async {
    final result = <String, String>{};

    final snap = await FirebaseFirestore.instance
        .collection('attendance')
        .where('class_id', isEqualTo: classId)
        .where('date_key', isEqualTo: dateKey)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final studentId = (data['student_id'] ?? '').toString();
      final status = (data['status'] ?? 'absent').toString();
      if (studentId.isNotEmpty) {
        result[studentId] = status;
      }
    }

    return result;
  }

  Future<void> saveAttendance({
    required String classId,
    required String dateKey,
    required String teacherId,
    required Map<String, String> statusByStudent,
    List<Map<String, dynamic>> students = const [],
  }) async {
    // Build student-uid → parent-uid lookup
    final parentEmailToUid = <String, String>{};
    final studentUidToParentEmail = <String, String>{};
    for (final s in students) {
      final uid = s['uid'].toString();
      final email = (s['parent_email'] ?? '').toString();
      if (email.isNotEmpty) {
        studentUidToParentEmail[uid] = email;
        if (!parentEmailToUid.containsKey(email)) {
          try {
            final snap = await FirebaseFirestore.instance
                .collection('parents')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
            if (snap.docs.isNotEmpty) {
              final d = snap.docs.first.data();
              parentEmailToUid[email] =
                  (d['uid'] ?? snap.docs.first.id).toString();
            }
          } catch (_) {}
        }
      }
    }

    for (final entry in statusByStudent.entries) {
      final studentId = entry.key;
      final status = entry.value;
      final docId = '${classId}_${studentId}_$dateKey';

      await FirebaseFirestore.instance.collection('attendance').doc(docId).set({
        'id': docId,
        'class_id': classId,
        'student_id': studentId,
        'status': status,
        'date_key': dateKey,
        'marked_by': teacherId,
        'updated_at': Timestamp.now(),
      }, const SetOptions(merge: true));

      final parentEmail = studentUidToParentEmail[studentId] ?? '';
      final parentUid = parentEmailToUid[parentEmail] ?? '';
      final notifTargets = <String>[studentId, 'role:student'];
      if (parentUid.isNotEmpty) notifTargets.add(parentUid);

      final notificationId = 'attendance_$docId';
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .set({
        'id': notificationId,
        'title': 'Attendance Updated',
        'body':
            'Your attendance for $dateKey is marked as ${status.toUpperCase()}.',
        'type': 'attendance',
        'targets': notifTargets,
        'data': {
          'class_id': classId,
          'date_key': dateKey,
          'status': status,
        },
        'created_at': Timestamp.now(),
        'read_by': <String>[],
      }, const SetOptions(merge: true));

      // Dedicated parent notification
      if (parentUid.isNotEmpty) {
        final parentNotifId =
            'parent_attendance_${classId}_${studentId}_$dateKey';
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(parentNotifId)
            .set({
          'id': parentNotifId,
          'title': 'Child Attendance Update',
          'body':
              'Your child\'s attendance for $dateKey has been marked as ${status.toUpperCase()}.',
          'type': 'attendance',
          'targets': [parentUid, 'role:parent'],
          'data': {
            'class_id': classId,
            'date_key': dateKey,
            'status': status,
            'student_id': studentId,
          },
          'created_at': Timestamp.now(),
          'read_by': <String>[],
        }, const SetOptions(merge: true));
      }
    }
  }
}
