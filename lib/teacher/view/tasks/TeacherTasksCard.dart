import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/public/utils/font_families.dart';
import 'package:school_management_system/routes/app_pages.dart';

class TeacherTasksCard extends StatelessWidget {
  const TeacherTasksCard({
    Key? key,
    required this.subjectName,
    required this.taskName,
    required this.uploadDate,
    required this.deadline,
    this.id,
    this.classroomId,
    this.bcontext,
  }) : super(key: key);

  final subjectName;
  final taskName;
  final uploadDate;
  final deadline;
  final id;
  final classroomId;
  final bcontext;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.toNamed(
          AppPages.studentsOfTask,
          parameters: {
            'id': id?.toString() ?? '',
            'taskName': taskName?.toString() ?? '',
            'classroomId': classroomId?.toString() ?? '',
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: gradientColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$subjectName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: RedHatDisplay.bold,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  '$taskName',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: RedHatDisplay.regular,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_drop_up,
                      size: 14,
                      color: Colors.white,
                    ),
                    Expanded(
                      child: Text(
                        '$uploadDate',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 14,
                      color: Colors.white,
                    ),
                    Expanded(
                      child: Text(
                        '$deadline',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
