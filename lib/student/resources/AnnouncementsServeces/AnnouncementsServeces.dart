import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/student/models/Announcements/AnnouncementsModel.dart';

class AnnouncementsServeces {
  String _resolveStudentClassroom(Map<String, dynamic>? data) {
    if (data == null) {
      return UserInformation.classid.toString();
    }

    final directClassId = data['class_id'];
    if (directClassId != null && directClassId.toString().isNotEmpty) {
      return directClassId.toString();
    }

    final classValue = data['class'];
    if (classValue is String && classValue.isNotEmpty) {
      return classValue;
    }
    if (classValue is Map && classValue['id'] != null) {
      return classValue['id'].toString();
    }

    return UserInformation.classid.toString();
  }

  getUserClassroom() async {
    var userId = UserInformation.User_uId;
    String userclassroomId = '';
    await FirebaseFirestore.instance
        .collection('students')
        .doc(userId)
        .get()
        .then((value) {
      if (value.data() != null) {
        userclassroomId = _resolveStudentClassroom(value.data());
      }
      print('Serverss');
      print(userclassroomId);
    });
    print(userclassroomId.toString());
    return userclassroomId;
  }

  /*Stream<List<AnnouncementsModesl>> annoStream() {
    return FirebaseFirestore.instance
        .collection('announcement')
        .doc()
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> query) {
      var annList = <AnnouncementsModesl>[];
      for (var i = 0; i < query.data()!.length; i++) {
        if (query.data()![i]['class-room-id'].id == getUserClassroom()) {
          final DateTime docDateTime =
              DateTime.parse(query.data()![i]['date'].toDate().toString());
          var annoDate = DateFormat("yyyy/MM/dd").format(docDateTime);
          annList.add(AnnouncementsModesl(
            title: query.data()![i]['title'],
            content: query.data()![i]['content'],
            date: annoDate,
          ));
        }
      }
      return annList;
    });
  }*/

  getUserAnn() {
    /*Stream<QuerySnapshot> announcementFromFirebase =
        FirebaseFirestore.instance.collection('announcement').snapshots();

    return announcementFromFirebase.map((event) {
      return event.docs.map((doc) {
        return AnnouncementsModesl(
          title: doc.data['title'],
          content: doc.data['content'],
          date: doc.data['date'],
        );
      });
    }).toList();*/
  }

  /* for (var i = 0; i < doc.length; i++) {
        if (doc[i].data()['class-room-id'].id.toString() ==
            userclassroomId.toString()) {
          
        }
      }
      */
}
