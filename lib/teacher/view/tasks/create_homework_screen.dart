import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/notifications/notification_service.dart';
import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/teacher/resources/TaskServices/TaskServices.dart';
import 'package:school_management_system/teacher/view/tasks/AddFiles/components/SelectFile.dart';

class CreateHomeworkScreen extends StatefulWidget {
  const CreateHomeworkScreen({Key? key}) : super(key: key);

  @override
  State<CreateHomeworkScreen> createState() => _CreateHomeworkScreenState();
}

class _CreateHomeworkScreenState extends State<CreateHomeworkScreen> {
  // ── data ────────────────────────────────────────────────────────────────────
  bool _loadingMeta = true;
  bool _submitting = false;

  List<Map<String, String>> _classes = [];   // {id, label}
  List<Map<String, String>> _subjects = [];  // {id, name}

  String? _selectedClassId;
  String? _selectedSubjectName;
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  File? _file;
  String _fileName = '';

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // ── init ────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────────────────────
  Future<void> _loadClasses() async {
    setState(() => _loadingMeta = true);
    try {
      final relations = await FirebaseFirestore.instance
          .collection('relation')
          .where('teacher', isEqualTo: UserInformation.User_uId)
          .get();

      final classIds = <String>{};
      for (final doc in relations.docs) {
        final list = doc.data()['classrooms'];
        if (list is List) {
          for (final item in list) {
            final id = item.toString();
            if (id.isNotEmpty) classIds.add(id);
          }
        }
      }

      final classes = <Map<String, String>>[];
      for (final classId in classIds) {
        final snap = await FirebaseFirestore.instance
            .collection('class-room')
            .doc(classId)
            .get();
        final data = snap.data();
        if (data == null) continue;
        classes.add({
          'id': classId,
          'label': '${data['section'] ?? ''}-${data['acadimic_year'] ?? ''}',
        });
      }
      classes.sort((a, b) => a['label']!.compareTo(b['label']!));

      setState(() {
        _classes = classes;
        if (classes.isNotEmpty) {
          _selectedClassId = classes.first['id'];
        }
      });
      if (_selectedClassId != null) await _loadSubjects(_selectedClassId!);
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  Future<void> _loadSubjects(String classId) async {
    // Get the grade from the class-room doc
    String grade = '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('class-room')
          .doc(classId)
          .get();
      grade = (snap.data()?['acadimic_year'] ?? '').toString();
    } catch (_) {}

    final relations = await FirebaseFirestore.instance
        .collection('relation')
        .where('teacher', isEqualTo: UserInformation.User_uId)
        .where('grade', isEqualTo: grade)
        .get();

    final subjects = <Map<String, String>>[];
    for (final doc in relations.docs) {
      final name = (doc.data()['subject_name'] ?? '').toString();
      final id = (doc.data()['subject_id'] ?? doc.id).toString();
      if (name.isNotEmpty) {
        subjects.add({'id': id, 'name': name});
      }
    }

    setState(() {
      _subjects = subjects;
      _selectedSubjectName =
          subjects.isNotEmpty ? subjects.first['name'] : null;
    });
  }

  Future<void> _pickFile() async {
    final file = await selectfile();
    if (file == null) return;
    setState(() {
      _file = file;
      _fileName = p.basename(file.path);
    });
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              ColorScheme.light(primary: primaryColor, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (_selectedClassId == null || _selectedClassId!.isEmpty) {
      _snack('Please select a class');
      return;
    }
    if (_selectedSubjectName == null || _selectedSubjectName!.isEmpty) {
      _snack('Please select a subject');
      return;
    }
    if (title.isEmpty) {
      _snack('Please enter a homework title');
      return;
    }
    if (_file == null) {
      _snack('Please attach a file');
      return;
    }

    setState(() => _submitting = true);
    try {
      final classId = _selectedClassId!;
      final subject = _selectedSubjectName!;
      final desc = _descCtrl.text.trim();
      final teacherName =
          '${UserInformation.first_name} ${UserInformation.last_name}'.trim();

      // 1. Upload file
      final url = await TaskServices.uploadFile(
        _file!,
        teacherName,
        title,
        '',
      );

      // 2. Save Task document
      final docId =
          FirebaseFirestore.instance.collection('Task').doc().id;
      final deadlineTs = Timestamp.fromDate(_deadline);
      await FirebaseFirestore.instance
          .collection('Task')
          .doc(docId)
          .set({
        'id': docId,
        'classroom': classId,
        'name': title,
        'description': desc,
        'subjectName': subject,
        'teacher_id': UserInformation.User_uId,
        'deadline': deadlineTs,
        'uploadDate': Timestamp.fromDate(DateTime.now()),
        'url': url?.toString() ?? '',
      });

      // 3. Notify students in the class
      final studentSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('class_id', isEqualTo: classId)
          .get();

      final studentUids = studentSnap.docs
          .map((d) => (d.data()['uid'] ?? d.id).toString())
          .toList();

      await NotificationService.createNotification(
        title: 'New Homework: $title',
        body:
            '$subject homework posted by $teacherName. Deadline: ${DateFormat('dd MMM yyyy').format(_deadline)}',
        targets: [
          'role:student',
          'role:parent',
          'class:$classId',
          ...studentUids,
        ],
        type: 'homework',
        data: {
          'task_id': docId,
          'classroom': classId,
          'subject_name': subject,
          'deadline': _deadline.toIso8601String(),
        },
      );

      if (!mounted) return;
      _showSuccess(title, studentUids.length);
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccess(String title, int studentCount) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Homework Posted'),
        content: Text(
          '"$title" has been saved.\n\n'
          '$studentCount student${studentCount == 1 ? '' : 's'} notified.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Get.back();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────────────────────
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 16),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Create Homework'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Step 1: Class ──────────────────────────────────────────
                  _label('Step 1 · Select Class'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedClassId,
                        hint: const Text('Choose class'),
                        items: _classes
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['id'],
                                child: Text(c['label'] ?? c['id'] ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (val) async {
                                setState(() {
                                  _selectedClassId = val;
                                  _subjects = [];
                                  _selectedSubjectName = null;
                                });
                                if (val != null) await _loadSubjects(val);
                              },
                      ),
                    ),
                  ),

                  // ── Step 2: Subject ────────────────────────────────────────
                  _label('Step 2 · Select Subject'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedSubjectName,
                        hint: const Text('Choose subject'),
                        items: _subjects
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s['name'],
                                child: Text(s['name'] ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (val) =>
                                setState(() => _selectedSubjectName = val),
                      ),
                    ),
                  ),

                  // ── Step 3: Title + Description ────────────────────────────
                  _label('Step 3 · Homework Title'),
                  TextField(
                    controller: _titleCtrl,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      hintText: 'e.g. Chapter 5 exercises',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: primaryColor.withOpacity(.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: primaryColor.withOpacity(.4)),
                      ),
                    ),
                  ),
                  _label('Description (optional)'),
                  TextField(
                    controller: _descCtrl,
                    enabled: !_submitting,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Instructions, page numbers, notes…',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: primaryColor.withOpacity(.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: primaryColor.withOpacity(.4)),
                      ),
                    ),
                  ),

                  // ── Step 4: File ───────────────────────────────────────────
                  _label('Step 4 · Attach File'),
                  GestureDetector(
                    onTap: _submitting ? null : _pickFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _file != null
                              ? primaryColor
                              : primaryColor.withOpacity(.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _file != null
                                ? Icons.attach_file
                                : Icons.upload_file,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _file != null ? _fileName : 'Tap to choose a file',
                              style: TextStyle(
                                color: _file != null
                                    ? Colors.black87
                                    : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_file != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: _submitting
                                  ? null
                                  : () => setState(() {
                                        _file = null;
                                        _fileName = '';
                                      }),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Deadline ───────────────────────────────────────────────
                  _label('Deadline'),
                  GestureDetector(
                    onTap: _submitting ? null : _pickDeadline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withOpacity(.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: primaryColor),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('dd MMM yyyy').format(_deadline),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Icon(Icons.edit, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Submit ─────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                          _submitting ? 'Posting…' : 'Post Homework'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
