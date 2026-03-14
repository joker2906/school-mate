import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/teacher/controllers/TasksControllers/TeacherTaskController.dart';
import 'package:school_management_system/teacher/view/tasks/TeacherTasksCard.dart';
import 'package:school_management_system/teacher/view/tasks/create_homework_screen.dart';
import 'package:school_management_system/teacher/widgets/ConnectionStateMessages.dart';
import 'package:school_management_system/teacher/widgets/Skilton.dart';
import 'package:shimmer/shimmer.dart';

final TeacherTasksController taskcontroller =
    Get.put(TeacherTasksController());

class TeacherTasksPage extends StatelessWidget {
  TeacherTasksPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: backgroundColor,
        drawer: Drawer(),
        appBar: AppBar(
          title: const Text('Homework'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New Homework'),
          onPressed: () => Get.to(() => const CreateHomeworkScreen()),
        ),
        body: Padding(
          padding: EdgeInsets.fromLTRB(15.w, 24.h, 15.w, 0),
          child: GetBuilder<TeacherTasksController>(
            init: TeacherTasksController(),
            builder: (_) {
              return FutureBuilder(
                future: taskcontroller.getTasks(),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: SimmerTaskLoading());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: ErrorMessage());
                  }
                  if (taskcontroller.tasksList.value.isEmpty) {
                    return const Center(child: Text('No homework yet'));
                  }

                  return GridView.builder(
                    dragStartBehavior: DragStartBehavior.down,
                    itemCount: taskcontroller.tasksList.value.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 24.w,
                      mainAxisSpacing: 24.w,
                      childAspectRatio: 1.15,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final item = taskcontroller.tasksList.value[index];
                      DateTime date = DateTime.parse(
                        item.uploadDate.toDate().toString(),
                      );
                      final uploadDate = DateFormat('yyyy/MM/dd').format(date);
                      date = DateTime.parse(item.deadLine.toDate().toString());
                      final deadline = DateFormat('yyyy/MM/dd').format(date);

                      return TeacherTasksCard(
                        subjectName: item.taskSubjectName,
                        taskName: item.taskName,
                        uploadDate: uploadDate,
                        deadline: deadline,
                        bcontext: context,
                        id: item.taskId,
                        classroomId: item.taskClassroomId,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class SimmerTaskLoadingCard extends StatelessWidget {
  const SimmerTaskLoadingCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Skilton(
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class SimmerTaskLoading extends StatelessWidget {
  const SimmerTaskLoading({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      child: GridView.builder(
        dragStartBehavior: DragStartBehavior.down,
        itemCount: 10,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 24.w,
          mainAxisSpacing: 24.w,
        ),
        itemBuilder: (BuildContext context, int index) {
          return const SimmerTaskLoadingCard();
        },
      ),
      baseColor: Colors.grey.shade100,
      highlightColor: loadingPrimarycolor,
    );
  }
}

class AddFileButton extends StatelessWidget {
  const AddFileButton({
    Key? key,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 180.w,
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: gradientColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 8.w),
            Text(
              'Add $label',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddButton extends StatelessWidget {
  const AddButton({
    Key? key,
    this.Bcontext,
    required this.onpress,
  }) : super(key: key);

  final BuildContext? Bcontext;
  final VoidCallback onpress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180.w,
      child: ElevatedButton(
        onPressed: onpress,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: white,
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Add',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
