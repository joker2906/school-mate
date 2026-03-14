import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/public/utils/font_families.dart';
import 'package:school_management_system/student/Widgets/custom_appbar.dart';
import 'package:school_management_system/student/view/Home/home_appbar.dart';
import 'package:school_management_system/teacher/controllers/TasksControllers/CheckedStudentTaskInfoController.dart';
import 'package:school_management_system/teacher/controllers/TasksControllers/studentTaskInfo.dart';
import 'package:school_management_system/teacher/widgets/ConnectionStateMessages.dart';
import 'package:school_management_system/teacher/resources/TaskServices/TaskServices.dart';

class StudentsOfTask extends StatelessWidget {
  StudentsOfTask({Key? key, this.taskId, this.taskName}) : super(key: key);
  var uncontroller = Get.find<StudentTaskInfoController>();
  var chcontroller = Get.find<CheckedStudentTaskInfoController>();
  var taskId;
  var taskName;
  @override
  Widget build(BuildContext context) {
    var data = Get.parameters;
    final taskId = data['id'] ?? '';
    final classroomId = data['classroomId'] ?? '';
    uncontroller.task_id.value = taskId;
    chcontroller.task_id.value = taskId;
    return Scaffold(
      appBar: AppBar(
        elevation: 5,
        title: Row(
          children: [
            Text(
              '${data['taskName'].toString()}',
              style: TextStyle(
                color: white,
                fontSize: 24,
                fontFamily: RedHatDisplay.regular,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: gradientColor,
            image: DecorationImage(
              image: AssetImage('assets/images/appbar-background-squares.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      backgroundColor: backgroundColor,
      body: FutureBuilder(
        future: Future.wait<dynamic>(<Future<dynamic>>[
          uncontroller.getUnCheckedStudentsOftask(),
          chcontroller.getCheckedStudentsOfTask(),
          TaskServices().getNotUploadedStudents(taskId, classroomId),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notUploaded =
              (snap.data?[2] as List<Map<String, dynamic>>?) ?? [];
          final submittedCount =
              uncontroller.studentsTaskList.value.length +
                  chcontroller.studentList.value.length;
          final notSubmittedCount = notUploaded.length;
          return Column(children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatChip(
                    label: 'Submitted',
                    count: submittedCount,
                    color: Colors.green,
                  ),
                  _StatChip(
                    label: 'Not Submitted',
                    count: notSubmittedCount,
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _SectionHeader(
                      title: 'Submitted — Pending Grade', color: Colors.orange),
                  if (uncontroller.studentsTaskList.value.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('None')),
                    ),
                  ...List.generate(
                      uncontroller.studentsTaskList.value.length, (index) {
                    return StudenOfTaskCard(
                      studentName:
                          uncontroller.studentsTaskList.value[index].name,
                      uploadDate: DateFormat("yyyy/MM/dd").format(
                          uncontroller.studentsTaskList.value[index].uploadeDate),
                      taskId:
                          uncontroller.studentsTaskList.value[index].task_id,
                      taskUrl:
                          uncontroller.studentsTaskList.value[index].taskUrl,
                      photoUrl:
                          uncontroller.studentsTaskList.value[index].photoUrl,
                      index: index,
                      task_result_id:
                          uncontroller.studentsTaskList.value[index].id,
                    );
                  }),
                  _SectionHeader(title: 'Graded', color: Colors.green),
                  if (chcontroller.studentList.value.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('None')),
                    ),
                  ...List.generate(chcontroller.studentList.value.length,
                      (index) {
                    return CheckedStudentsOfTaskCard(
                      name: chcontroller.studentList.value[index].name,
                      uploadeDate: DateFormat("yyyy/MM/dd").format(
                          chcontroller.studentList.value[index].uploadeDate),
                      mark: chcontroller.studentList.value[index].mark,
                      photoUrl:
                          chcontroller.studentList.value[index].photoUrl,
                      id: chcontroller.studentList.value[index].id,
                      taskUrl:
                          chcontroller.studentList.value[index].taskUrl,
                      task_id:
                          chcontroller.studentList.value[index].task_id,
                      class_id:
                          chcontroller.studentList.value[index].class_id,
                      student_id:
                          chcontroller.studentList.value[index].student_id,
                    );
                  }),
                  _SectionHeader(
                      title: 'Not Submitted', color: Colors.redAccent),
                  if (notUploaded.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('All students submitted!')),
                    ),
                  ...notUploaded.map((s) => _NotSubmittedCard(
                        name: s['name'] ?? '',
                        photoUrl: s['photoUrl'] ?? '',
                      )),
                ],
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip(
      {required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: RedHatDisplay.bold),
          ),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontFamily: RedHatDisplay.medium)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: color.withOpacity(0.08),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontFamily: RedHatDisplay.bold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _NotSubmittedCard extends StatelessWidget {
  final String name;
  final String photoUrl;

  const _NotSubmittedCard({required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: RedHatDisplay.regular,
                  color: Colors.black87,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Not submitted',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontFamily: RedHatDisplay.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckedStudentsOfTaskCard extends StatelessWidget {
  const CheckedStudentsOfTaskCard({
    Key? key,
    this.name,
    this.photoUrl,
    this.uploadeDate,
    this.mark,
    this.id,
    this.taskUrl,
    this.class_id,
    this.student_id,
    this.task_id,
  }) : super(key: key);

  final name;
  final uploadeDate;
  final photoUrl;
  final id;
  final taskUrl;
  final task_id;
  final student_id;
  final class_id;
  final mark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        var data = Get.parameters;
        await openFile(
          url: taskUrl,
          fileName: '$name solution for ${data['taskName']}',
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(photoUrl.toString()),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name',
                      style: const TextStyle(
                        color: primaryColor,
                        fontFamily: RedHatDisplay.regular,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '$uploadeDate',
                      style: const TextStyle(
                        color: gray,
                        fontFamily: RedHatDisplay.medium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$mark',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontFamily: RedHatDisplay.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudenOfTaskCard extends StatelessWidget {
  StudenOfTaskCard({
    Key? key,
    this.studentName,
    this.uploadDate,
    this.photoUrl,
    this.taskId,
    this.taskUrl,
    this.index,
    this.task_result_id,
  }) : super(key: key);

  final studentName;
  final uploadDate;
  final photoUrl;
  final taskUrl;
  final taskId;
  final index;
  final task_result_id;
  final StudentTaskInfoController uncontroller =
      Get.find<StudentTaskInfoController>();

  @override
  Widget build(BuildContext context) {
    uncontroller.task_id.value = taskId.toString();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: GestureDetector(
        onTap: () async {
          var data = Get.parameters;
          await openFile(
            url: taskUrl,
            fileName: '$studentName solution for ${data['taskName']}',
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(photoUrl.toString()),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$studentName',
                      style: const TextStyle(
                        color: darkGray,
                        fontFamily: RedHatDisplay.regular,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '$uploadDate',
                      style: const TextStyle(
                        color: gray,
                        fontFamily: RedHatDisplay.medium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Get.defaultDialog(
                    title: 'Add mark for a task',
                    titleStyle: const TextStyle(
                      color: primaryColor,
                      fontSize: 20,
                      fontFamily: RedHatDisplay.medium,
                    ),
                    content: Column(
                      children: [
                        Text(
                          '$studentName',
                          style: const TextStyle(
                            color: black,
                            fontSize: 15,
                            fontFamily: RedHatDisplay.bold,
                          ),
                        ),
                        SizedBox(height: 15.h),
                        TextField(
                          onChanged: (String value) {
                            uncontroller.newMark.value = value;
                          },
                          decoration: InputDecoration(
                            label: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Enter mark'),
                            ),
                            labelStyle: const TextStyle(
                              color: primaryColor,
                              fontSize: 15,
                            ),
                            fillColor: backgroundColor,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                width: 0.0,
                                color: backgroundColor,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(8.0),
                          ),
                        ),
                      ],
                    ),
                    confirm: ElevatedButton(
                      onPressed: () async {
                        uncontroller.indexForStd.value = index;
                        uncontroller.task_result_id.value = task_result_id;
                        EasyLoading.show();
                        await uncontroller.addMarkForTask();
                        Get.back();
                        EasyLoading.showSuccess('Done');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: white,
                      ),
                      child: const Text('Add Mark'),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.add_circle,
                  color: primaryColor,
                  size: 34,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future openFile({required String url, String? fileName}) async {
  final file = await downloadFile(url, fileName ?? 'file');
  if (file == null) return;
  OpenFile.open(file.path);
}

Future<File?> downloadFile(String url, String name) async {
  final appStorage = await getApplicationDocumentsDirectory();
  final file = File('/${appStorage.path}/$name');
  final dest = '/storage/emulated/0/School mate files/$name';

  try {
    await Dio().download(
      url,
      dest,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: false,
        receiveTimeout: Duration.zero,
      ),
    );

    if (await File(dest).exists()) {
      return File(dest);
    }

    return file;
  } catch (e) {
    print(e);
    return null;
  }
}
