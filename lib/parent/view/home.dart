import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:school_management_system/parent/view/fees/parent_fee_payment_screen.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/notifications/notification_push_bridge.dart';
import 'package:school_management_system/public/notifications/notifications_screen.dart';
import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/public/login/dividerforparent.dart';
import 'package:school_management_system/student/resources/Parent/parentApi.dart';
import 'package:school_management_system/student/resources/Parent/stparentmodel.dart';
import 'package:school_management_system/student/view/Announcements/AnnouncementsPage.dart';
import 'package:school_management_system/student/view/Attendance/student_attendance_screen.dart';
import 'package:school_management_system/student/view/Profile/stprofile.dart';
import 'package:school_management_system/student/view/TasksScreen/TasksPage.dart';

class HomeParent extends StatelessWidget {
  const HomeParent({Key? key}) : super(key: key);

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  Map<String, dynamic> _captureSession() {
    return {
      'uid': UserInformation.User_uId,
      'email': UserInformation.email,
      'first_name': UserInformation.first_name,
      'last_name': UserInformation.last_name,
      'classid': UserInformation.classid,
      'classroom': UserInformation.classroom,
      'clasname': UserInformation.clasname,
      'phone': UserInformation.phone,
      'parentphone': UserInformation.parentphone,
      'urlAvatr': UserInformation.urlAvatr,
      'grade': UserInformation.grade,
      'grade_average': UserInformation.grade_average,
      'fees': UserInformation.fees,
      'fullfees': UserInformation.fullfees,
      'uParent': UserInformation.uParent,
    };
  }

  void _restoreSession(Map<String, dynamic> snapshot) {
    UserInformation.User_uId = (snapshot['uid'] ?? '').toString();
    UserInformation.email = (snapshot['email'] ?? '').toString();
    UserInformation.first_name = (snapshot['first_name'] ?? '').toString();
    UserInformation.last_name = (snapshot['last_name'] ?? '').toString();
    UserInformation.classid = (snapshot['classid'] ?? '').toString();
    UserInformation.classroom = snapshot['classroom'];
    UserInformation.clasname = (snapshot['clasname'] ?? '').toString();
    UserInformation.phone = (snapshot['phone'] ?? '').toString();
    UserInformation.parentphone = (snapshot['parentphone'] ?? '').toString();
    UserInformation.urlAvatr = (snapshot['urlAvatr'] ?? '').toString();
    UserInformation.grade = snapshot['grade'] ?? 0;
    UserInformation.grade_average = _toDouble(snapshot['grade_average']);
    UserInformation.fees = (snapshot['fees'] ?? '').toString();
    UserInformation.fullfees = (snapshot['fullfees'] ?? '').toString();
    UserInformation.uParent = snapshot['uParent'] == true;
  }

  void _setChildContext(StudentP child) {
    UserInformation.fees = child.fees ?? '';
    UserInformation.fullfees = child.fullfees ?? '';
    UserInformation.classid = child.classid ?? '';
    UserInformation.first_name = child.firstName;
    UserInformation.last_name = child.lastName;
    UserInformation.phone = child.phone ?? '';
    UserInformation.parentphone = child.parentPhone ?? '';
    UserInformation.classroom = child.studentClass ?? '';
    UserInformation.clasname = child.studentClass ?? '';
    UserInformation.urlAvatr = child.urlAvatar ?? '';
    UserInformation.grade_average = _toDouble(child.average);
    UserInformation.grade = int.tryParse(child.studentGrade ?? '0') ?? 0;
    UserInformation.User_uId = child.id?.toString() ?? '';
  }

  Future<void> _openChildFeature(
    StudentP child,
    Widget Function() pageBuilder,
  ) async {
    final snapshot = _captureSession();
    _setChildContext(child);
    await Get.to(pageBuilder);
    _restoreSession(snapshot);
  }

  Future<List<StudentP>> _loadChildren() async {
    final result = await ParentApi.getStudents(UserInformation.email);
    return List<StudentP>.from(result ?? []);
  }

  Future<Map<String, dynamic>> _loadChildSummary(StudentP child) async {
    final firestore = FirebaseFirestore.instance;

    Future<int> countWhere(String collection, Map<String, dynamic> filters) async {
      Query query = firestore.collection(collection);
      filters.forEach((key, value) {
        query = query.where(key, isEqualTo: value);
      });
      final snapshot = await query.get();
      return snapshot.docs.length;
    }

    Future<List<int>> collectMarks(String collection) async {
      final snapshot = await firestore
          .collection(collection)
          .where('student_id', isEqualTo: child.id)
          .get();
      return snapshot.docs
          .map((doc) => int.tryParse(doc['result'].toString()) ?? 0)
          .toList();
    }

    final tasks = await countWhere('Task', {'classroom': child.classid});
    final announcements =
        await countWhere('announcement', {'class-room': child.classid});
    final submissions =
        await countWhere('Task-result', {'student_id': child.id});

    final marks = <int>[]
      ..addAll(await collectMarks('tests'))
      ..addAll(await collectMarks('homeworks'))
      ..addAll(await collectMarks('exam1'))
      ..addAll(await collectMarks('exam2'));

    final averageMark = marks.isEmpty
        ? 0
        : (marks.reduce((a, b) => a + b) / marks.length).round();

    return {
      'tasks': tasks,
      'announcements': announcements,
      'submissions': submissions,
      'averageMark': averageMark,
    };
  }

  Future<void> _openChildPortal(StudentP child) async {
    _setChildContext(child);
    UserInformation.email = child.email;
    UserInformation.uParent = false;
    await GetStorage().write('uid', UserInformation.User_uId);
    await GetStorage().write('role', 'student');
    await GetStorage().write('classid', child.classid ?? '');
    NotificationPushBridge.start(
      uid: UserInformation.User_uId,
      role: 'student',
      classId: child.classid ?? '',
    );
    Get.offAllNamed('/sthome');
  }

  Future<void> _logout() async {
    NotificationPushBridge.stop();
    await GetStorage().erase();
    Get.offAllNamed('/login');
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _flowCard(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: primaryColor),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<StudentP>>(
        future: _loadChildren(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final children = snapshot.data ?? [];
          if (children.isEmpty) {
            return const Center(
              child: Text('No linked students found for this parent account.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final child = children[index];
              return FutureBuilder<Map<String, dynamic>>(
                future: _loadChildSummary(child),
                builder: (context, summarySnapshot) {
                  final summary = summarySnapshot.data ?? {};
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: primaryColor.withOpacity(.15),
                              child: Text(
                                child.firstName.substring(0, 1),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${child.firstName} ${child.lastName}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Grade ${child.studentGrade} • ${child.studentClass}',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _openChildPortal(child),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Open Student View'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 150,
                              child: _statCard('Fees Due', child.fees ?? '0'),
                            ),
                            SizedBox(
                              width: 150,
                              child: _statCard(
                                'Average Mark',
                                '${summary['averageMark'] ?? child.average ?? 0}%',
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: _statCard('Tasks', '${summary['tasks'] ?? 0}'),
                            ),
                            SizedBox(
                              width: 150,
                              child: _statCard(
                                'Announcements',
                                '${summary['announcements'] ?? 0}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const DividerParent(text: 'Parent Flow'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _flowCard(
                              'Student\nAttendance',
                              Icons.fact_check,
                              () => _openChildFeature(
                                child,
                                () => const StudentAttendanceScreen(),
                              ),
                            ),
                            _flowCard(
                              'Homework',
                              Icons.task,
                              () => _openChildFeature(
                                child,
                                () => TasksPage(),
                              ),
                            ),
                            _flowCard(
                              'Exam\nResults',
                              Icons.assessment,
                              () => _openChildFeature(
                                child,
                                () => StudentProfile(),
                              ),
                            ),
                            _flowCard(
                              'Fee\nPayment',
                              Icons.account_balance_wallet,
                              () => Get.to(
                                () => const ParentFeePaymentScreen(),
                              ),
                            ),
                            _flowCard(
                              'Notifications',
                              Icons.notifications,
                              () => Get.to(
                                () => const NotificationsScreen(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Checked submissions: ${summary['submissions'] ?? 0}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Parent account: ${UserInformation.email}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}