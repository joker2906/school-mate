import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/public/utils/font_families.dart';
import 'package:school_management_system/public/utils/util.dart';
import 'package:school_management_system/teacher/view/tasks/AddFiles/components/SelectFile.dart';
import '../../controllers/TasksController.dart';

var _controller = Get.put<TasksController>(TasksController());

class TasksCard extends StatelessWidget {
  const TasksCard({
    Key? key,
    required this.subjectName,
    required this.name,
    required this.uploadDate,
    required this.deadline,
    this.task_id,
    this.url,
  }) : super(key: key);

  final subjectName;
  final name;
  final uploadDate;
  final deadline;
  final task_id;
  final url;

  void _showTaskOptions(BuildContext context) {
    _controller.task_id.value = task_id;
    _controller.task_name.value = name;
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              '$name',
              style: const TextStyle(
                fontSize: 18,
                fontFamily: RedHatDisplay.bold,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$subjectName',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: RedHatDisplay.regular,
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text(
                  'Download Homework',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onPressed: () async {
                  Get.back();
                  showSnackBar('Starting download...', context);
                  final dir = await getExternalStorageDirectory();
                  await FlutterDownloader.enqueue(
                    url: '$url',
                    savedDir: dir!.path,
                    fileName: '$name',
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: const Text(
                  'Upload Solution',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onPressed: () async {
                  Get.back();
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => _UploadDialog(controller: _controller),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showTaskOptions(context),
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
                  '$name',
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
                    const Icon(Icons.arrow_drop_up,
                        size: 14, color: Colors.white),
                    Expanded(
                      child: Text(
                        '$uploadDate',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.arrow_drop_down,
                        size: 14, color: Colors.white),
                    Expanded(
                      child: Text(
                        '$deadline',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
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

class _UploadDialog extends StatelessWidget {
  final TasksController controller;
  const _UploadDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Task Solution'),
      content: GetBuilder<TasksController>(
        init: controller,
        builder: (_) => Row(
          children: [
            Expanded(
              child: Text(
                controller.file_name.value.toString().isNotEmpty
                    ? controller.file_name.value.toString()
                    : 'No file selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.attach_file, color: primaryColor),
              onPressed: () async {
                var f = await selectfile();
                controller.updateFile(f);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.black54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
          onPressed: () async {
            EasyLoading.show();
            await controller.uploadTaskResult();
            Navigator.of(context).pop();
            EasyLoading.showSuccess('Done');
          },
          child: const Text('Upload',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
