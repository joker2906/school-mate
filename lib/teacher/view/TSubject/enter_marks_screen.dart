import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/notifications/notification_service.dart';
import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/teacher/resources/AttendanceServices/TAttendanceServices.dart';

/// Exam types → Firestore collections
const _kExamTypes = <String, String>{
  'Exam 1': 'exam1',
  'Exam 2': 'exam2',
  'Test': 'tests',
  'Homework': 'homeworks',
};

class EnterMarksScreen extends StatefulWidget {
  const EnterMarksScreen({Key? key}) : super(key: key);

  @override
  State<EnterMarksScreen> createState() => _EnterMarksScreenState();
}

class _EnterMarksScreenState extends State<EnterMarksScreen> {
  // ── state ────────────────────────────────────────────────────────────────
  bool _loadingMeta = true;
  bool _loadingStudents = false;
  bool _submitting = false;

  List<Map<String, String>> _classes = [];
  List<Map<String, String>> _subjects = [];
  List<Map<String, dynamic>> _students = [];     // {uid, name, parent_email}

  String? _selectedClassId;
  String? _selectedClassGrade;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String _selectedExamTypeLabel = _kExamTypes.keys.first;
  int _maxMarks = 100;

  /// uid → entered mark (as string during editing)
  final Map<String, TextEditingController> _markCtrl = {};

  // ── init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    for (final c in _markCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────────────────────
  Future<void> _loadClasses() async {
    setState(() => _loadingMeta = true);
    try {
      final service = TAttendanceServices();
      final classes =
          await service.getTeacherClasses(UserInformation.User_uId);
      setState(() {
        _classes = classes;
        if (classes.isNotEmpty) _selectedClassId = classes.first['id'];
      });
      if (_selectedClassId != null) {
        await _loadSubjectsForClass(_selectedClassId!);
      }
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  Future<void> _loadSubjectsForClass(String classId) async {
    // Resolve grade from class-room doc
    String grade = '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('class-room')
          .doc(classId)
          .get();
      grade = (snap.data()?['acadimic_year'] ?? '').toString();
    } catch (_) {}

    setState(() {
      _selectedClassGrade = grade;
      _subjects = [];
      _selectedSubjectId = null;
      _selectedSubjectName = null;
    });

    final relations = await FirebaseFirestore.instance
        .collection('relation')
        .where('teacher', isEqualTo: UserInformation.User_uId)
        .where('grade', isEqualTo: grade)
        .get();

    final subjects = <Map<String, String>>[];
    for (final doc in relations.docs) {
      final name = (doc.data()['subject_name'] ?? '').toString();
      final id = (doc.data()['subject_id'] ?? doc.id).toString();
      if (name.isNotEmpty) subjects.add({'id': id, 'name': name});
    }

    setState(() {
      _subjects = subjects;
      if (subjects.isNotEmpty) {
        _selectedSubjectId = subjects.first['id'];
        _selectedSubjectName = subjects.first['name'];
      }
    });

    if (_selectedSubjectId != null) await _loadStudentsAndMarks();
  }

  Future<void> _loadStudentsAndMarks() async {
    final classId = _selectedClassId;
    final subjectId = _selectedSubjectId;
    if (classId == null || subjectId == null) return;

    setState(() => _loadingStudents = true);
    try {
      final service = TAttendanceServices();
      final students = await service.getStudentsForClass(classId);

      // Load existing marks for this exam type
      final collection = _kExamTypes[_selectedExamTypeLabel]!;
      final grade = _selectedClassGrade ?? '';
      final existingSnap = await FirebaseFirestore.instance
          .collection(collection)
          .where('subject_id', isEqualTo: subjectId)
          .where('grade', isEqualTo: grade)
          .get();

      final existingMarks = <String, int>{};
      for (final doc in existingSnap.docs) {
        final uid = (doc.data()['student_id'] ?? '').toString();
        final mark = (doc.data()['result'] as num?)?.toInt() ?? 0;
        if (uid.isNotEmpty) existingMarks[uid] = mark;
      }

      // Rebuild controllers
      for (final c in _markCtrl.values) {
        c.dispose();
      }
      _markCtrl.clear();
      for (final s in students) {
        final uid = s['uid'].toString();
        final existingMark = existingMarks[uid];
        _markCtrl[uid] = TextEditingController(
          text: existingMark != null ? existingMark.toString() : '',
        );
      }

      setState(() => _students = students);
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  // ── submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final classId = _selectedClassId;
    final subjectId = _selectedSubjectId;
    final grade = _selectedClassGrade ?? '';
    final subjectName = _selectedSubjectName ?? '';
    final collection = _kExamTypes[_selectedExamTypeLabel]!;

    if (classId == null || subjectId == null || _students.isEmpty) {
      _snack('Select a class, subject and ensure students are loaded.');
      return;
    }

    setState(() => _submitting = true);
    try {
      int saved = 0;
      final studentUids = <String>[];

      for (final student in _students) {
        final uid = student['uid'].toString();
        final markText = _markCtrl[uid]?.text.trim() ?? '';
        if (markText.isEmpty) continue;
        final mark = int.tryParse(markText);
        if (mark == null || mark < 0 || mark > _maxMarks) continue;

        studentUids.add(uid);

        // Upsert mark doc
        final docId = '${collection}_${subjectId}_${uid}_$grade';
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(docId)
            .set({
          'id': docId,
          'subject_id': subjectId,
          'student_id': uid,
          'grade': grade,
          'result': mark,
          'final_mark': _maxMarks,
          'updated_at': Timestamp.now(),
          'marked_by': UserInformation.User_uId,
        }, const SetOptions(merge: true));

        // Recalculate grade_average for this student
        await _recalculateAverage(uid, grade);
        saved++;
      }

      // Notify students and parents
      if (studentUids.isNotEmpty) {
        // Resolve parent UIDs for notifications
        final parentUids = await _resolveParentUids(studentUids);

        await NotificationService.createNotification(
          title: 'Exam Results Published',
          body:
              '$subjectName ${_selectedExamTypeLabel} results are now available. Check your profile.',
          targets: [
            'role:student',
            'role:parent',
            'class:$classId',
            ...studentUids,
            ...parentUids,
          ],
          type: 'result',
          data: {
            'subject_id': subjectId,
            'subject_name': subjectName,
            'exam_type': collection,
            'class_id': classId,
            'grade': grade,
          },
        );
      }

      if (!mounted) return;
      _showSuccess(saved, subjectName);
    } catch (e) {
      if (mounted) _snack('Error saving marks: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _recalculateAverage(String uid, String grade) async {
    final collections = ['tests', 'homeworks', 'exam1', 'exam2'];
    final marks = <int>[];

    for (final col in collections) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection(col)
            .where('student_id', isEqualTo: uid)
            .where('grade', isEqualTo: grade)
            .get();
        for (final doc in snap.docs) {
          final r = (doc.data()['result'] as num?)?.toInt();
          if (r != null) marks.add(r);
        }
      } catch (_) {}
    }

    if (marks.isEmpty) return;
    final avg = marks.reduce((a, b) => a + b) / marks.length;

    // Update student doc
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(snap.docs.first.id)
            .update({'grade_average': avg});
      }
    } catch (_) {}
  }

  Future<List<String>> _resolveParentUids(List<String> studentUids) async {
    final parentUids = <String>[];
    // Get parent emails from student docs
    for (final uid in studentUids) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('students')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (snap.docs.isEmpty) continue;
        final parentEmail =
            (snap.docs.first.data()['parent_email'] ?? '').toString();
        if (parentEmail.isEmpty) continue;
        final pSnap = await FirebaseFirestore.instance
            .collection('parents')
            .where('email', isEqualTo: parentEmail)
            .limit(1)
            .get();
        if (pSnap.docs.isNotEmpty) {
          final pUid =
              (pSnap.docs.first.data()['uid'] ?? pSnap.docs.first.id).toString();
          if (!parentUids.contains(pUid)) parentUids.add(pUid);
        }
      } catch (_) {}
    }
    return parentUids;
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _showSuccess(int saved, String subject) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Marks Saved'),
        content: Text(
          '$saved mark${saved == 1 ? '' : 's'} saved for $subject '
          '(${_selectedExamTypeLabel}).\n\n'
          'Student averages recalculated.\n'
          'Students & parents have been notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
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

  Widget _dropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String hint = 'Select',
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(.4)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            hint: Text(hint),
            items: items,
            onChanged: _submitting ? null : onChanged,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Enter Exam Marks'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── controls ────────────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Class'),
                      _dropdown<String>(
                        value: _selectedClassId,
                        hint: 'Select class',
                        items: _classes
                            .map((c) => DropdownMenuItem<String>(
                                  value: c['id'],
                                  child: Text(c['label'] ?? c['id'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (val) async {
                          setState(() {
                            _selectedClassId = val;
                            _students = [];
                          });
                          if (val != null) await _loadSubjectsForClass(val);
                        },
                      ),
                      _label('Subject'),
                      _dropdown<String>(
                        value: _selectedSubjectId,
                        hint: 'Select subject',
                        items: _subjects
                            .map((s) => DropdownMenuItem<String>(
                                  value: s['id'],
                                  child: Text(s['name'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (val) async {
                          final chosen =
                              _subjects.firstWhere((s) => s['id'] == val,
                                  orElse: () => {});
                          setState(() {
                            _selectedSubjectId = val;
                            _selectedSubjectName = chosen['name'];
                            _students = [];
                          });
                          if (val != null) await _loadStudentsAndMarks();
                        },
                      ),
                      _label('Exam Type'),
                      Row(
                        children: [
                          Expanded(
                            child: _dropdown<String>(
                              value: _selectedExamTypeLabel,
                              items: _kExamTypes.keys
                                  .map((k) => DropdownMenuItem<String>(
                                        value: k,
                                        child: Text(k),
                                      ))
                                  .toList(),
                              onChanged: (val) async {
                                if (val == null) return;
                                setState(() {
                                  _selectedExamTypeLabel = val;
                                  _students = [];
                                });
                                await _loadStudentsAndMarks();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Max marks',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: primaryColor.withOpacity(.4)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: primaryColor.withOpacity(.4)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              controller:
                                  TextEditingController(text: '$_maxMarks')
                                    ..selection = TextSelection.fromPosition(
                                      TextPosition(
                                          offset: '$_maxMarks'.length),
                                    ),
                              onChanged: (v) =>
                                  _maxMarks = int.tryParse(v) ?? 100,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── student list ─────────────────────────────────────────────
                Expanded(
                  child: _loadingStudents
                      ? const Center(child: CircularProgressIndicator())
                      : _students.isEmpty
                          ? const Center(
                              child: Text('No students found for selection.'))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              itemCount: _students.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final student = _students[index];
                                final uid = student['uid'].toString();
                                final name = student['name'].toString();
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            primaryColor.withOpacity(.12),
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          name.isEmpty ? uid : name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: TextField(
                                          controller: _markCtrl[uid],
                                          enabled: !_submitting,
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          decoration: InputDecoration(
                                            hintText: '/$_maxMarks',
                                            hintStyle: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                            filled: true,
                                            fillColor: backgroundColor,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                  color: primaryColor
                                                      .withOpacity(.4)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                  color: primaryColor
                                                      .withOpacity(.4)),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
                // ── submit button ─────────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(
                          _submitting ? 'Saving…' : 'Save Marks & Notify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
