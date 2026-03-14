import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/notifications/notification_service.dart';

class TAnnouncementsServices {
  getAnnouncements() async {
    var stream = await FirebaseFirestore.instance
        .collection('announcement')
        .where('type', isEqualTo: 'Teachers')
        .snapshots();

    return stream;
  }

  Future<String> _resolveTeacherClassroom() async {
    if (UserInformation.classid.toString().isNotEmpty) {
      return UserInformation.classid.toString();
    }

    final relation = await FirebaseFirestore.instance
        .collection('relation')
        .where('teacher', isEqualTo: UserInformation.User_uId)
        .limit(1)
        .get();

    if (relation.docs.isNotEmpty) {
      final data = relation.docs.first.data();
      final classrooms = data['classrooms'];
      if (classrooms is List && classrooms.isNotEmpty) {
        return classrooms.first.toString();
      }
    }

    return '';
  }

  Future<void> createClassAnnouncement({
    required String title,
    required String content,
  }) async {
    final classRoomId = await _resolveTeacherClassroom();
    final id = FirebaseFirestore.instance.collection('announcement').doc().id;

    final data = {
      'id': id,
      'title': title,
      'content': content,
      'date': Timestamp.now(),
      'type': 'Students',
      'teacher': UserInformation.User_uId,
    };

    if (classRoomId.isNotEmpty) {
      data['class-room'] = classRoomId;
    }

    await FirebaseFirestore.instance.collection('announcement').doc(id).set(
          data,
          const SetOptions(merge: true),
        );

    final recipientTargets = <String>[];
    if (classRoomId.isNotEmpty) {
      final studentSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('class_id', isEqualTo: classRoomId)
          .get();

      final parentEmails = <String>[];
      for (final studentDoc in studentSnap.docs) {
        final studentData = studentDoc.data();
        final studentUid = (studentData['uid'] ?? studentDoc.id).toString();
        recipientTargets.add(studentUid);
        final parentEmail = (studentData['parent_email'] ?? '').toString();
        if (parentEmail.isNotEmpty && !parentEmails.contains(parentEmail)) {
          parentEmails.add(parentEmail);
        }
      }

      for (final parentEmail in parentEmails) {
        final parentSnap = await FirebaseFirestore.instance
            .collection('parents')
            .where('email', isEqualTo: parentEmail)
            .limit(1)
            .get();
        if (parentSnap.docs.isEmpty) {
          continue;
        }
        final parentData = parentSnap.docs.first.data();
        final parentUid =
            (parentData['uid'] ?? parentSnap.docs.first.id).toString();
        if (!recipientTargets.contains(parentUid)) {
          recipientTargets.add(parentUid);
        }
      }
    }

    await NotificationService.createNotification(
      title: title,
      body: content,
      targets: recipientTargets,
      type: 'message',
      senderUid: UserInformation.User_uId,
      senderRole: 'teacher',
      data: {
        'announcement_id': id,
        'class-room': classRoomId,
      },
    );
  }
}
