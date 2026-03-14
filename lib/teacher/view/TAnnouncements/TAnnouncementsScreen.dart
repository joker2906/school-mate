import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/public/utils/font_families.dart';
import 'package:school_management_system/student/view/Announcements/announcementsCard.dart';
import 'package:school_management_system/teacher/controllers/AnnouncementsController/AnnouncementsController.dart';
import 'package:school_management_system/teacher/resources/TAnnouncementsServces/TAnnouncementsServices.dart';

var _controller = Get.put<TAnnouncementsController>(TAnnouncementsController());
final _services = TAnnouncementsServices();

Future<void> _showCreateAnnouncementDialog(BuildContext context) async {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  final shouldCreate = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Send Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Content'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      );
    },
  );

  if (shouldCreate != true) {
    return;
  }

  final title = titleController.text.trim();
  final content = contentController.text.trim();

  if (title.isEmpty || content.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Title and content are required.')),
    );
    return;
  }

  await _services.createClassAnnouncement(
    title: title,
    content: content,
  );

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Message sent successfully.')),
  );
}

class TAnnouncementsScreen extends StatelessWidget {
  const TAnnouncementsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 5,
        title: Row(
          children: [
            const Text(
              'Class Messages',
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: SizedBox(
                height: 770.h,
                width: 428.w,
                child: GetBuilder(
                  init: TAnnouncementsController(),
                  builder: (controller) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('announcement')
                          .where('type', whereIn: ['Teachers', 'All', 'Students'])
                          .snapshots(),
                      builder: (BuildContext context, AsyncSnapshot snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Text('Laoding...'),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('Nothing to show'),
                          );
                        }

                        return ListView.builder(
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (BuildContext context, int index) {
                            final DateTime docDateTime = DateTime.parse(
                              snapshot.data!.docs[index]['date']
                                  .toDate()
                                  .toString(),
                            );
                            var annoDate =
                                DateFormat('yyyy/MM/dd').format(docDateTime);

                            return AnnouncementsCard(
                              title: snapshot.data!.docs[index]['title'],
                              content: snapshot.data!.docs[index]['content'],
                              date: annoDate,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: white,
        onPressed: () => _showCreateAnnouncementDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Send'),
      ),
    );
  }
}
