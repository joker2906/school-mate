import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:school_management_system/public/fees/fee_flow_service.dart';
import 'package:school_management_system/public/notifications/notification_push_bridge.dart';
import 'package:school_management_system/public/notifications/notification_service.dart';
import 'package:school_management_system/public/utils/constant.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({Key? key}) : super(key: key);

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  static const Color _adminInk = Color(0xFF18324A);
  static const Color _adminAccent = Color(0xFFE4A93A);
  static const Color _adminCanvas = Color(0xFFF3F7FB);
  static const Color _adminCard = Colors.white;
  static const Color _adminMuted = Color(0xFF6B7C8C);

  final _firestore = FirebaseFirestore.instance;
  bool _loading = false;

  final _classId = TextEditingController();
  final _classGrade = TextEditingController();
  final _classSection = TextEditingController();
  final _classStudents = TextEditingController(text: '0');

  final _subjectId = TextEditingController();
  final _subjectName = TextEditingController();
  final _subjectGrade = TextEditingController();

  final _userFirstName = TextEditingController();
  final _userLastName = TextEditingController();
  final _userEmail = TextEditingController();
  final _userPassword = TextEditingController();
  final _userPhone = TextEditingController();
  final _userClassId = TextEditingController();
  final _userClassName = TextEditingController();
  final _userGrade = TextEditingController();
  final _userStudentId = TextEditingController();

  final _linkStudentLookup = TextEditingController();
  final _linkParentLookup = TextEditingController();

  final _assignTeacherUid = TextEditingController();
  final _assignSubjectUid = TextEditingController();
  final _assignGrade = TextEditingController();
  final _assignClassIds = TextEditingController();

  final _feeStudentUid = TextEditingController();
  final _feeTotal = TextEditingController();
  final _feePaymentAmount = TextEditingController();
  final _feePaymentNote = TextEditingController();
  final _feeStructureTitle = TextEditingController();
  final _feeStructureClassId = TextEditingController();
  final _feeStructureGrade = TextEditingController();
  final _feeStructureAmount = TextEditingController();
  final _feeAcademicYear = TextEditingController();
  final _feeTerm = TextEditingController();
  final _feeNotes = TextEditingController();
  DateTime? _feeDueDate;

  final _notifyTitle = TextEditingController();
  final _notifyBody = TextEditingController();

  // Exam management
  final _examName = TextEditingController();
  final _examSubjectId = TextEditingController();
  final _examClassId = TextEditingController();
  final _examGrade = TextEditingController();
  final _examMaxMarks = TextEditingController(text: '100');
  String _examType = 'exam1';

  String _selectedRole = 'student';
  String _selectedNotifyTarget = 'all';
  String? _editingUserUid;
  String? _editingUserCollection;

  @override
  void dispose() {
    _classId.dispose();
    _classGrade.dispose();
    _classSection.dispose();
    _classStudents.dispose();
    _subjectId.dispose();
    _subjectName.dispose();
    _subjectGrade.dispose();
    _userFirstName.dispose();
    _userLastName.dispose();
    _userEmail.dispose();
    _userPassword.dispose();
    _userPhone.dispose();
    _userClassId.dispose();
    _userClassName.dispose();
    _userGrade.dispose();
    _userStudentId.dispose();
    _linkStudentLookup.dispose();
    _linkParentLookup.dispose();
    _assignTeacherUid.dispose();
    _assignSubjectUid.dispose();
    _assignGrade.dispose();
    _assignClassIds.dispose();
    _feeStudentUid.dispose();
    _feeTotal.dispose();
    _feePaymentAmount.dispose();
    _feePaymentNote.dispose();
    _feeStructureTitle.dispose();
    _feeStructureClassId.dispose();
    _feeStructureGrade.dispose();
    _feeStructureAmount.dispose();
    _feeAcademicYear.dispose();
    _feeTerm.dispose();
    _feeNotes.dispose();
    _notifyTitle.dispose();
    _notifyBody.dispose();
    _examName.dispose();
    _examSubjectId.dispose();
    _examClassId.dispose();
    _examGrade.dispose();
    _examMaxMarks.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) => int.tryParse((value ?? '0').toString()) ?? 0;

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '0').toString()) ?? 0.0;
  }

  List<String> _csvToList(String value) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _safeIdPart(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  String _csvCell(dynamic value) {
    final raw = (value ?? '').toString().replaceAll('"', '""');
    return '"$raw"';
  }

  String _dateLabel(DateTime? value) {
    if (value == null) {
      return 'Select due date';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _recordId(Map<String, dynamic> item) {
    return (item['uid'] ?? item['id'] ?? '').toString();
  }

  String _personName(Map<String, dynamic> item) {
    final first = (item['first_name'] ?? item['name'] ?? '').toString().trim();
    final last = (item['last_name'] ?? '').toString().trim();
    final combined = '$first $last'.trim();
    return combined.isEmpty ? _recordId(item) : combined;
  }

  String _classLabel(Map<String, dynamic> item) {
    final section = (item['section'] ?? '').toString().trim();
    final grade =
        (item['acadimic_year'] ?? item['grade'] ?? '').toString().trim();
    if (section.isEmpty && grade.isEmpty) {
      return _recordId(item);
    }
    if (section.isEmpty) {
      return 'Grade $grade';
    }
    if (grade.isEmpty) {
      return section;
    }
    return '$section - Grade $grade';
  }

  String _buildStudentId() {
    final classHint = _safeIdPart(
      _userClassId.text.trim().isEmpty ? 'GEN' : _userClassId.text.trim(),
    ).toUpperCase();
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    return 'STD-$classHint-${stamp.substring(stamp.length - 5)}';
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    Future<List<Map<String, dynamic>>> loadDirectory(String collection) async {
      final snapshot = await _firestore.collection(collection).get();
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    }

    final students = await loadDirectory('students');
    final teachers = await loadDirectory('teacher');
    final parents = await loadDirectory('parents');
    final admins = await loadDirectory('admins');
    final classes = await loadDirectory('class-room');
    final subjects = await loadDirectory('subject');
    final tasks = await loadDirectory('Task');
    final announcements = await loadDirectory('announcement');
    final relations = await loadDirectory('relation');
    final attendance = await loadDirectory('attendance');
    final feePayments = await loadDirectory('fee-payments');
    final feeStructures = await loadDirectory('fee-structures');
    final receipts = await loadDirectory('receipts');
    final complaints = await loadDirectory('complaint');
    final notifications = await loadDirectory('notifications');

    return {
      'students': students,
      'teachers': teachers,
      'parents': parents,
      'admins': admins,
      'classes': classes,
      'subjects': subjects,
      'tasks': tasks,
      'announcements': announcements,
      'relations': relations,
      'attendance': attendance,
      'feePayments': feePayments,
      'feeStructures': feeStructures,
      'receipts': receipts,
      'complaints': complaints,
      'notifications': notifications,
    };
  }

  Future<void> _pickFeeDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _feeDueDate ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) {
      setState(() => _feeDueDate = picked);
    }
  }

  String _collectionForRole(String role) {
    switch (role) {
      case 'teacher':
        return 'teacher';
      case 'parent':
        return 'parents';
      case 'admin':
        return 'admins';
      default:
        return 'students';
    }
  }

  String _roleForCollection(String collection) {
    switch (collection) {
      case 'teacher':
        return 'teacher';
      case 'parents':
        return 'parent';
      case 'admins':
        return 'admin';
      default:
        return 'student';
    }
  }

  void _clearUserForm({bool resetRole = false}) {
    _userFirstName.clear();
    _userLastName.clear();
    _userEmail.clear();
    _userPassword.clear();
    _userPhone.clear();
    _userClassId.clear();
    _userClassName.clear();
    _userGrade.clear();
    _userStudentId.clear();
    setState(() {
      _editingUserUid = null;
      _editingUserCollection = null;
      if (resetRole) {
        _selectedRole = 'student';
      }
    });
  }

  void _startUserEdit(Map<String, dynamic> user) {
    final collection = (user['_collection'] ?? '').toString();
    final uid = (user['uid'] ?? user['id'] ?? '').toString();
    if (uid.isEmpty || collection.isEmpty) {
      return;
    }

    setState(() {
      _editingUserUid = uid;
      _editingUserCollection = collection;
      _selectedRole = _roleForCollection(collection);
      _userFirstName.text = (user['first_name'] ?? '').toString();
      _userLastName.text = (user['last_name'] ?? '').toString();
      _userEmail.text = (user['email'] ?? '').toString();
      _userPassword.clear();
      _userPhone.text = (user['phone'] ?? '').toString();
      _userClassId.text = (user['class_id'] ?? '').toString();
      _userClassName.text = (user['class_name'] ?? '').toString();
      _userGrade.text = (user['grade'] ?? '').toString();
      _userStudentId.text = (user['student_id'] ?? '').toString();
    });
  }

  Future<Map<String, dynamic>?> _findDirectoryDoc(
    String collection,
    String lookup,
    List<String> fields,
  ) async {
    final trimmed = lookup.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final direct = await _firestore.collection(collection).doc(trimmed).get();
    if (direct.exists && direct.data() != null) {
      return {
        'id': direct.id,
        ...Map<String, dynamic>.from(direct.data()!),
      };
    }

    for (final field in fields) {
      final snap = await _firestore
          .collection(collection)
          .where(field, isEqualTo: trimmed)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return {
          'id': snap.docs.first.id,
          ...Map<String, dynamic>.from(snap.docs.first.data()),
        };
      }
    }

    return null;
  }

  Future<String?> _findUidByEmail(String collection, String email) async {
    final snap = await _firestore
        .collection(collection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      return null;
    }
    return snap.docs.first.id;
  }

  Future<void> _saveClass() async {
    if (_classId.text.trim().isEmpty ||
        _classGrade.text.trim().isEmpty ||
        _classSection.text.trim().isEmpty) {
      Get.snackbar(
          'Missing fields', 'Class id, grade and section are required');
      return;
    }

    setState(() => _loading = true);
    final classId = _classId.text.trim();
    final grade = _classGrade.text.trim();

    await _firestore.collection('class-room').doc(classId).set({
      'uid': classId,
      'acadimic_year': grade,
      'section': _classSection.text.trim(),
      'number_of_students': int.tryParse(_classStudents.text.trim()) ?? 0,
    }, const SetOptions(merge: true));

    await _firestore.collection('acadimic_year').doc(grade).set({
      'id': grade,
      'grade': int.tryParse(grade) ?? grade,
      'subject': [],
    }, const SetOptions(merge: true));

    await NotificationService.createNotification(
      title: 'Class Updated',
      body: 'Class ${_classSection.text.trim()}-$grade was updated by admin.',
      targets: ['role:teacher', 'role:student'],
      type: 'class',
    );

    setState(() => _loading = false);
    Get.snackbar('Done', 'Class saved');
  }

  Future<void> _saveSubject() async {
    if (_subjectId.text.trim().isEmpty ||
        _subjectName.text.trim().isEmpty ||
        _subjectGrade.text.trim().isEmpty) {
      Get.snackbar('Missing fields', 'Subject id, name and grade are required');
      return;
    }

    setState(() => _loading = true);
    final subjectId = _subjectId.text.trim();
    final grade = _subjectGrade.text.trim();

    await _firestore.collection('subject').doc(subjectId).set({
      'id': subjectId,
      'name': _subjectName.text.trim(),
      'subject_grade': grade,
    }, const SetOptions(merge: true));

    await _firestore.collection('acadimic_year').doc(grade).set({
      'id': grade,
      'grade': int.tryParse(grade) ?? grade,
      'subject': FieldValue.arrayUnion([subjectId]),
    }, const SetOptions(merge: true));

    await NotificationService.createNotification(
      title: 'Subject Updated',
      body: 'Subject ${_subjectName.text.trim()} for grade $grade was updated.',
      targets: ['role:teacher', 'role:student'],
      type: 'subject',
    );

    setState(() => _loading = false);
    Get.snackbar('Done', 'Subject saved');
  }

  Future<void> _saveUser() async {
    final email = _userEmail.text.trim();
    final firstName = _userFirstName.text.trim();
    final lastName = _userLastName.text.trim();
    if (email.isEmpty || firstName.isEmpty || lastName.isEmpty) {
      Get.snackbar('Missing fields',
          'User first name, last name and email are required');
      return;
    }

    setState(() => _loading = true);

    final collection = _collectionForRole(_selectedRole);
    final isEditing = _editingUserUid != null && _editingUserUid!.isNotEmpty;

    if (isEditing &&
        _editingUserCollection != null &&
        _editingUserCollection != collection) {
      setState(() => _loading = false);
      Get.snackbar(
        'Role mismatch',
        'Clear current edit before changing role',
      );
      return;
    }

    String? uid;

    if (!isEditing && _userPassword.text.trim().isNotEmpty) {
      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: email, password: _userPassword.text.trim());
        uid = credential.user?.uid;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') {
          setState(() => _loading = false);
          Get.snackbar('Auth error', e.message ?? e.code);
          return;
        }
      }
    }

    uid ??= isEditing ? _editingUserUid : null;
    uid ??= await _findUidByEmail(collection, email);
    uid ??= 'manual_${DateTime.now().millisecondsSinceEpoch}';

    final data = <String, dynamic>{
      'uid': uid,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': _userPhone.text.trim(),
      'urlAvatar': '',
    };

    if (_selectedRole == 'teacher') {
      data['subjects'] = [];
    }

    if (_selectedRole == 'student') {
      final studentId = _userStudentId.text.trim().isEmpty
          ? _buildStudentId()
          : _userStudentId.text.trim();
      data['class_id'] = _userClassId.text.trim();
      data['class_name'] = _userClassName.text.trim();
      data['grade'] = _userGrade.text.trim();
      data['student_id'] = studentId;
      data['fees'] = '0';
      data['full_fees'] = '0';
      data['paid_fees'] = '0';
      data['grade_average'] = 0;
      data['parent_phone'] = '';
      data['parent_email'] = '';
    }

    await _firestore.collection(collection).doc(uid).set(
          data,
          const SetOptions(merge: true),
        );

    if (_selectedRole == 'student' && _userStudentId.text.trim().isEmpty) {
      _userStudentId.text = (data['student_id'] ?? '').toString();
    }

    await NotificationService.createNotification(
      title: 'Profile Updated',
      body: 'Your $_selectedRole profile has been updated by admin.',
      targets: ['role:$_selectedRole', uid],
      type: 'profile',
    );

    _userPassword.clear();
    if (isEditing) {
      _clearUserForm();
    }
    setState(() => _loading = false);
    Get.snackbar(
      'Done',
      isEditing
          ? '${_selectedRole.toUpperCase()} profile updated'
          : '${_selectedRole.toUpperCase()} profile saved',
    );
  }

  Future<void> _linkStudentToParent() async {
    final studentLookup = _linkStudentLookup.text.trim();
    final parentLookup = _linkParentLookup.text.trim();
    if (studentLookup.isEmpty || parentLookup.isEmpty) {
      Get.snackbar(
        'Missing fields',
        'Student UID/Student ID and parent UID/email are required',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final student = await _findDirectoryDoc(
        'students',
        studentLookup,
        ['uid', 'student_id', 'email'],
      );
      if (student == null) {
        Get.snackbar('Not found', 'Student not found');
        return;
      }

      final parent = await _findDirectoryDoc(
        'parents',
        parentLookup,
        ['uid', 'email'],
      );
      if (parent == null) {
        Get.snackbar('Not found', 'Parent not found');
        return;
      }

      final studentDocId = (student['id'] ?? '').toString();
      final studentUid = _recordId(student);
      final parentDocId = (parent['id'] ?? '').toString();
      final parentUid = _recordId(parent);
      final parentEmail = (parent['email'] ?? '').toString();
      final parentPhone = (parent['phone'] ?? '').toString();

      if (studentDocId.isEmpty ||
          studentUid.isEmpty ||
          parentDocId.isEmpty ||
          parentUid.isEmpty) {
        Get.snackbar('Invalid data', 'Student or parent record is incomplete');
        return;
      }

      await _firestore.collection('students').doc(studentDocId).set({
        'parent_uid': parentUid,
        'parent_email': parentEmail,
        'parent_phone': parentPhone,
      }, const SetOptions(merge: true));

      await _firestore.collection('parents').doc(parentDocId).set({
        'linked_students': FieldValue.arrayUnion([studentUid]),
      }, const SetOptions(merge: true));

      await NotificationService.createNotification(
        title: 'Parent Linked',
        body:
            'Admin linked ${_personName(student)} with ${_personName(parent)}.',
        targets: [studentUid, parentUid, 'role:parent'],
        type: 'profile',
      );

      _linkStudentLookup.clear();
      _linkParentLookup.clear();
      Get.snackbar('Done', 'Student linked to parent');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _assignTeacherSubject() async {
    final teacherUid = _assignTeacherUid.text.trim();
    final subjectUid = _assignSubjectUid.text.trim();
    if (teacherUid.isEmpty || subjectUid.isEmpty) {
      Get.snackbar(
        'Missing fields',
        'Teacher UID and Subject UID are required',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final teacherSnap =
          await _firestore.collection('teacher').doc(teacherUid).get();
      if (!teacherSnap.exists || teacherSnap.data() == null) {
        Get.snackbar('Not found', 'Teacher not found');
        return;
      }

      final subjectSnap =
          await _firestore.collection('subject').doc(subjectUid).get();
      if (!subjectSnap.exists || subjectSnap.data() == null) {
        Get.snackbar('Not found', 'Subject not found');
        return;
      }

      final teacherData = Map<String, dynamic>.from(teacherSnap.data()!);
      final subjectData = Map<String, dynamic>.from(subjectSnap.data()!);
      final grade = _assignGrade.text.trim().isNotEmpty
          ? _assignGrade.text.trim()
          : (subjectData['subject_grade'] ?? '').toString();
      final classrooms = _csvToList(_assignClassIds.text.trim());

      final relationId =
          'rel_${_safeIdPart(teacherUid)}_${_safeIdPart(subjectUid)}_${_safeIdPart(grade)}_${_safeIdPart(classrooms.join('_'))}';

      await _firestore.collection('relation').doc(relationId).set({
        'uid': relationId,
        'teacher': teacherUid,
        'teacher_name':
            '${teacherData['first_name'] ?? ''} ${teacherData['last_name'] ?? ''}'
                .trim(),
        'grade': grade,
        'subject': subjectUid,
        'subject_name': (subjectData['name'] ?? subjectUid).toString(),
        'classrooms': classrooms,
      }, const SetOptions(merge: true));

      await _firestore.collection('teacher').doc(teacherUid).set({
        'subjects': FieldValue.arrayUnion([subjectUid]),
      }, const SetOptions(merge: true));

      await NotificationService.createNotification(
        title: 'Subject Assigned',
        body:
            'You were assigned to subject ${subjectData['name'] ?? subjectUid}.',
        targets: ['role:teacher', teacherUid],
        type: 'subject',
      );

      Get.snackbar('Done', 'Subject assigned to teacher');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteDoc(String collection, String id) async {
    setState(() => _loading = true);
    await _firestore.collection(collection).doc(id).delete();
    setState(() => _loading = false);
    Get.snackbar('Deleted', '$collection/$id removed');
  }

  Future<void> _saveStudentFeePlan() async {
    final uid = _feeStudentUid.text.trim();
    final total = _toInt(_feeTotal.text.trim());
    if (uid.isEmpty || total <= 0) {
      Get.snackbar('Missing fields', 'Student UID and total fees are required');
      return;
    }

    setState(() => _loading = true);
    try {
      final studentRef = _firestore.collection('students').doc(uid);
      final snap = await studentRef.get();
      if (!snap.exists || snap.data() == null) {
        Get.snackbar('Not found', 'Student not found');
        return;
      }

      final current = Map<String, dynamic>.from(snap.data()!);
      int paid = _toInt(current['paid_fees']);
      final oldFull = _toInt(current['full_fees']);
      final oldDue = _toInt(current['fees']);
      if (paid == 0 && oldFull > 0) {
        paid = oldFull - oldDue;
      }
      if (paid < 0) {
        paid = 0;
      }

      final due = total - paid < 0 ? 0 : total - paid;

      await _firestore.collection('student-fees').doc('manual_fee_$uid').set({
        'id': 'manual_fee_$uid',
        'structure_id': 'manual_admin_override',
        'student_id': uid,
        'class_id': (current['class_id'] ?? '').toString(),
        'class_name': (current['class_name'] ?? '').toString(),
        'grade': (current['grade'] ?? '').toString(),
        'title': 'Direct Fee Plan',
        'amount': total,
        'paid_amount': paid,
        'due_amount': due,
        'term': 'manual',
        'academic_year': 'manual',
        'notes': 'Saved from admin direct override',
        'generated_at': Timestamp.now(),
        'due_date': Timestamp.now(),
        'status': due == 0 ? 'paid' : (paid > 0 ? 'partial' : 'due'),
      }, const SetOptions(merge: true));

      await FeeFlowService.syncStudentFeeSummary(uid);

      await NotificationService.createNotification(
        title: 'Fee Plan Updated',
        body: 'Your total fees have been updated. Current due: $due',
        targets: [uid, 'role:student'],
        type: 'fees',
      );

      Get.snackbar('Done', 'Fee plan saved for student');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveFeeStructure() async {
    final title = _feeStructureTitle.text.trim();
    final classId = _feeStructureClassId.text.trim();
    final grade = _feeStructureGrade.text.trim();
    final amount = _toInt(_feeStructureAmount.text.trim());
    final academicYear = _feeAcademicYear.text.trim();
    final term = _feeTerm.text.trim();
    final notes = _feeNotes.text.trim();

    if (title.isEmpty ||
        classId.isEmpty ||
        grade.isEmpty ||
        amount <= 0 ||
        academicYear.isEmpty ||
        term.isEmpty) {
      Get.snackbar(
        'Missing fields',
        'Title, class ID, grade, amount, academic year and term are required',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final generated = await FeeFlowService.createFeeStructure(
        title: title,
        classId: classId,
        grade: grade,
        amount: amount,
        academicYear: academicYear,
        term: term,
        notes: notes,
        dueDate: _feeDueDate,
        createdBy: FirebaseAuth.instance.currentUser?.uid ?? 'admin',
      );

      _feeStructureTitle.clear();
      _feeStructureClassId.clear();
      _feeStructureGrade.clear();
      _feeStructureAmount.clear();
      _feeAcademicYear.clear();
      _feeTerm.clear();
      _feeNotes.clear();
      _feeDueDate = null;

      Get.snackbar(
        'Done',
        'Fee structure created and generated for $generated students',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addFeePayment() async {
    final uid = _feeStudentUid.text.trim();
    final amount = _toInt(_feePaymentAmount.text.trim());
    final note = _feePaymentNote.text.trim();
    if (uid.isEmpty || amount <= 0) {
      Get.snackbar('Missing fields',
          'Student UID and valid payment amount are required');
      return;
    }

    setState(() => _loading = true);
    try {
      final snap = await _firestore.collection('students').doc(uid).get();
      if (!snap.exists || snap.data() == null) {
        Get.snackbar('Not found', 'Student not found');
        return;
      }

      final result = await FeeFlowService.processParentPayment(
        studentUid: uid,
        parentUid: 'admin',
        amount: amount,
        paymentMethod: 'Manual',
        note: note.isEmpty ? 'Admin recorded payment' : note,
      );

      _feePaymentAmount.clear();
      _feePaymentNote.clear();
      Get.snackbar(
        'Done',
        'Payment recorded successfully. Receipt ${result.receiptNumber}',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveExam() async {
    final name = _examName.text.trim();
    final subjectId = _examSubjectId.text.trim();
    final classId = _examClassId.text.trim();
    final grade = _examGrade.text.trim();
    final maxMarks = int.tryParse(_examMaxMarks.text.trim()) ?? 100;
    if (name.isEmpty || subjectId.isEmpty || classId.isEmpty || grade.isEmpty) {
      Get.snackbar('Missing fields',
          'Exam name, subject ID, class ID and grade are required');
      return;
    }
    setState(() => _loading = true);
    try {
      final docId = _firestore.collection('exams').doc().id;
      await _firestore.collection('exams').doc(docId).set({
        'id': docId,
        'name': name,
        'subject_id': subjectId,
        'class_id': classId,
        'grade': grade,
        'exam_type': _examType,
        'max_marks': maxMarks,
        'created_at': Timestamp.now(),
        'created_by': 'admin',
      });
      _examName.clear();
      _examSubjectId.clear();
      _examClassId.clear();
      _examGrade.clear();
      _examMaxMarks.text = '100';
      await NotificationService.createNotification(
        title: 'New Exam Created: $name',
        body:
            'An exam "$name" (${_examType.toUpperCase()}) has been created for grade $grade. Max marks: $maxMarks.',
        targets: ['role:teacher'],
        type: 'exam',
        data: {
          'exam_id': docId,
          'subject_id': subjectId,
          'class_id': classId,
          'grade': grade,
          'exam_type': _examType,
        },
      );
      Get.snackbar('Done', 'Exam "$name" created and teachers notified.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _broadcastNotification() async {
    final title = _notifyTitle.text.trim();
    final body = _notifyBody.text.trim();
    if (title.isEmpty || body.isEmpty) {
      Get.snackbar(
          'Missing fields', 'Notification title and body are required');
      return;
    }

    setState(() => _loading = true);
    try {
      await NotificationService.createNotification(
        title: title,
        body: body,
        targets: [_selectedNotifyTarget],
        type: 'message',
        senderUid: FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        senderRole: 'admin',
      );
      _notifyTitle.clear();
      _notifyBody.clear();
      Get.snackbar('Done', 'Notification sent');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resolveComplaint(Map<String, dynamic> complaint) async {
    final id = complaint['id']?.toString() ?? '';
    if (id.isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      await _firestore.collection('complaint').doc(id).set({
        'resolved': true,
        'resolved_at': Timestamp.now(),
      }, const SetOptions(merge: true));

      final studentId = (complaint['student'] ?? '').toString();
      if (studentId.isNotEmpty) {
        await NotificationService.createNotification(
          title: 'Report Status Updated',
          body: 'Your submitted report has been marked as resolved.',
          targets: [studentId, 'role:student'],
          type: 'report',
        );
      }

      Get.snackbar('Done', 'Complaint marked as resolved');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _exportReportCsv({
    required List<Map<String, dynamic>> students,
    required List<Map<String, dynamic>> feePayments,
    required List<Map<String, dynamic>> complaints,
  }) async {
    final totalExpected =
        students.fold<int>(0, (sum, s) => sum + _toInt(s['full_fees']));
    final totalDue = students.fold<int>(0, (sum, s) => sum + _toInt(s['fees']));
    final totalCollected = feePayments.fold<int>(
      0,
      (sum, p) => sum + _toInt(p['amount']),
    );
    final openComplaints =
        complaints.where((c) => c['resolved'] != true).length;

    final rows = <String>[
      'metric,value',
      '${_csvCell('students')},${_csvCell(students.length)}',
      '${_csvCell('total_expected_fees')},${_csvCell(totalExpected)}',
      '${_csvCell('total_collected_fees')},${_csvCell(totalCollected)}',
      '${_csvCell('total_due_fees')},${_csvCell(totalDue)}',
      '${_csvCell('open_complaints')},${_csvCell(openComplaints)}',
      '',
      'student_uid,name,class_id,full_fees,paid_fees,due_fees',
      ...students.map((s) {
        final uid = s['uid']?.toString() ?? s['id']?.toString() ?? '';
        final name = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
        return '${_csvCell(uid)},${_csvCell(name)},${_csvCell(s['class_id'])},${_csvCell(s['full_fees'])},${_csvCell(s['paid_fees'])},${_csvCell(s['fees'])}';
      }),
    ];

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/schoolmate_report_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(rows.join('\n'));
    await OpenFile.open(file.path);
    Get.snackbar('Exported', 'Report CSV saved to ${file.path}');
  }

  Future<void> _logout() async {
    NotificationPushBridge.stop();
    await GetStorage().erase();
    Get.offAllNamed('/login');
  }

  List<Map<String, dynamic>> _buildClassSummaries({
    required List<Map<String, dynamic>> classes,
    required List<Map<String, dynamic>> students,
    required List<Map<String, dynamic>> attendance,
  }) {
    final summaries = classes.map((item) {
      final classId = _recordId(item);
      final classStudents = students
          .where((student) => (student['class_id'] ?? '').toString() == classId)
          .toList();
      final classAttendance = attendance
          .where((record) => (record['class_id'] ?? '').toString() == classId)
          .toList();
      final present = classAttendance
          .where(
            (record) =>
                (record['status'] ?? '').toString().toLowerCase() == 'present',
          )
          .length;
      final absent = classAttendance
          .where(
            (record) =>
                (record['status'] ?? '').toString().toLowerCase() == 'absent',
          )
          .length;
      final attendancePercent = classAttendance.isEmpty
          ? 0.0
          : (present / classAttendance.length) * 100;

      return {
        'class': item,
        'id': classId,
        'label': _classLabel(item),
        'studentCount': classStudents.length,
        'presentCount': present,
        'absentCount': absent,
        'attendancePercent': attendancePercent,
      };
    }).toList();

    summaries.sort(
      (a, b) => a['label'].toString().toLowerCase().compareTo(
            b['label'].toString().toLowerCase(),
          ),
    );
    return summaries;
  }

  Future<Map<String, dynamic>> _loadClassInsights({
    required Map<String, dynamic> classroom,
    required List<Map<String, dynamic>> students,
    required List<Map<String, dynamic>> attendance,
    required List<Map<String, dynamic>> subjects,
  }) async {
    final classId = _recordId(classroom);
    final grade = (classroom['acadimic_year'] ?? '').toString();
    final classStudents = students
        .where((student) => (student['class_id'] ?? '').toString() == classId)
        .map((student) => Map<String, dynamic>.from(student))
        .toList();
    final studentIds =
        classStudents.map(_recordId).where((id) => id.isNotEmpty).toSet();
    final subjectLookup = <String, String>{
      for (final subject in subjects)
        _recordId(subject): (subject['name'] ?? _recordId(subject)).toString(),
    };

    final attendanceByStudent = <String, Map<String, int>>{
      for (final studentId in studentIds)
        studentId: {
          'present': 0,
          'total': 0,
        },
    };

    final classAttendance = attendance
        .where((record) => (record['class_id'] ?? '').toString() == classId)
        .toList();
    for (final record in classAttendance) {
      final studentId = (record['student_id'] ?? '').toString();
      if (!attendanceByStudent.containsKey(studentId)) {
        continue;
      }
      attendanceByStudent[studentId]!['total'] =
          (attendanceByStudent[studentId]!['total'] ?? 0) + 1;
      if ((record['status'] ?? '').toString().toLowerCase() == 'present') {
        attendanceByStudent[studentId]!['present'] =
            (attendanceByStudent[studentId]!['present'] ?? 0) + 1;
      }
    }

    final subjectScores = <String, List<double>>{};
    final studentScores = <String, Map<String, List<double>>>{};
    const assessmentCollections = ['tests', 'homeworks', 'exam1', 'exam2'];
    final assessmentSnaps = await Future.wait(
      assessmentCollections.map(
        (collection) => _firestore
            .collection(collection)
            .where('grade', isEqualTo: grade)
            .get(),
      ),
    );

    for (final snap in assessmentSnaps) {
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final studentId = (data['student_id'] ?? '').toString();
        if (!studentIds.contains(studentId)) {
          continue;
        }
        final subjectId = (data['subject_id'] ?? '').toString();
        if (subjectId.isEmpty) {
          continue;
        }
        final mark = _toDouble(data['result']);
        (subjectScores[subjectId] ??= <double>[]).add(mark);
        final studentSubjectScores = studentScores.putIfAbsent(
          studentId,
          () => <String, List<double>>{},
        );
        (studentSubjectScores[subjectId] ??= <double>[]).add(mark);
      }
    }

    final subjectPerformance = subjectScores.entries.map((entry) {
      final total = entry.value.fold<double>(0, (sum, mark) => sum + mark);
      final average = entry.value.isEmpty ? 0.0 : total / entry.value.length;
      return {
        'subjectId': entry.key,
        'subjectName': subjectLookup[entry.key] ?? entry.key,
        'average': average,
        'assessments': entry.value.length,
      };
    }).toList()
      ..sort(
        (a, b) => a['subjectName']
            .toString()
            .toLowerCase()
            .compareTo(b['subjectName'].toString().toLowerCase()),
      );

    final studentPerformance = classStudents.map((student) {
      final studentId = _recordId(student);
      final subjectMap = studentScores[studentId] ?? <String, List<double>>{};
      final subjectAverages = subjectMap.entries.map((entry) {
        final total = entry.value.fold<double>(0, (sum, mark) => sum + mark);
        final average = entry.value.isEmpty ? 0.0 : total / entry.value.length;
        return {
          'subjectId': entry.key,
          'subjectName': subjectLookup[entry.key] ?? entry.key,
          'average': average,
        };
      }).toList()
        ..sort(
          (a, b) => a['subjectName']
              .toString()
              .toLowerCase()
              .compareTo(b['subjectName'].toString().toLowerCase()),
        );
      final allMarks = subjectMap.values.expand((marks) => marks).toList();
      final attendanceStats =
          attendanceByStudent[studentId] ?? const {'present': 0, 'total': 0};
      final attendancePercent = (attendanceStats['total'] ?? 0) == 0
          ? 0.0
          : ((attendanceStats['present'] ?? 0) /
                  (attendanceStats['total'] ?? 1)) *
              100;
      final overallAverage = allMarks.isEmpty
          ? _toDouble(student['grade_average'])
          : allMarks.fold<double>(0, (sum, mark) => sum + mark) /
              allMarks.length;

      return {
        ...student,
        'uid': studentId,
        'studentLabel': (student['student_id'] ?? studentId).toString(),
        'displayName': _personName(student),
        'subjectAverages': subjectAverages,
        'overallAverage': overallAverage,
        'attendancePercent': attendancePercent,
        'presentCount': attendanceStats['present'] ?? 0,
        'attendanceRecords': attendanceStats['total'] ?? 0,
      };
    }).toList()
      ..sort(
        (a, b) => a['displayName']
            .toString()
            .toLowerCase()
            .compareTo(b['displayName'].toString().toLowerCase()),
      );

    final overallMarks = subjectScores.values.expand((marks) => marks).toList();
    final presentCount = classAttendance
        .where((record) =>
            (record['status'] ?? '').toString().toLowerCase() == 'present')
        .length;
    final absentCount = classAttendance
        .where((record) =>
            (record['status'] ?? '').toString().toLowerCase() == 'absent')
        .length;
    final attendancePercent = classAttendance.isEmpty
        ? 0.0
        : (presentCount / classAttendance.length) * 100;
    final overallAverage = overallMarks.isEmpty
        ? (studentPerformance.isEmpty
            ? 0.0
            : studentPerformance.fold<double>(
                  0,
                  (sum, item) => sum + _toDouble(item['overallAverage']),
                ) /
                studentPerformance.length)
        : overallMarks.fold<double>(0, (sum, mark) => sum + mark) /
            overallMarks.length;

    return {
      'label': _classLabel(classroom),
      'students': studentPerformance,
      'subjects': subjectPerformance,
      'studentCount': classStudents.length,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'attendancePercent': attendancePercent,
      'overallAverage': overallAverage,
    };
  }

  Future<void> _openClassInsights({
    required Map<String, dynamic> classSummary,
    required List<Map<String, dynamic>> students,
    required List<Map<String, dynamic>> attendance,
    required List<Map<String, dynamic>> subjects,
  }) async {
    final classroom = Map<String, dynamic>.from(classSummary['class']);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: _adminCanvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _loadClassInsights(
                  classroom: classroom,
                  students: students,
                  attendance: attendance,
                  subjects: subjects,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final insight = snapshot.data ?? <String, dynamic>{};
                  final subjectPerformance = List<Map<String, dynamic>>.from(
                      insight['subjects'] ?? []);
                  final studentPerformance = List<Map<String, dynamic>>.from(
                      insight['students'] ?? []);

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _adminMuted.withOpacity(.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [_adminInk, Color(0xFF285173)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (insight['label'] ?? classSummary['label'])
                                  .toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Overall average ${_toDouble(insight['overallAverage']).toStringAsFixed(1)}%',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _metricPill(
                                  'Students',
                                  '${insight['studentCount'] ?? 0}',
                                  foreground: Colors.white,
                                  background: Colors.white.withOpacity(.12),
                                ),
                                _metricPill(
                                  'Present',
                                  '${insight['presentCount'] ?? 0}',
                                  foreground: Colors.white,
                                  background: Colors.white.withOpacity(.12),
                                ),
                                _metricPill(
                                  'Absent',
                                  '${insight['absentCount'] ?? 0}',
                                  foreground: Colors.white,
                                  background: Colors.white.withOpacity(.12),
                                ),
                                _metricPill(
                                  'Attendance',
                                  '${_toDouble(insight['attendancePercent']).toStringAsFixed(1)}%',
                                  foreground: Colors.white,
                                  background: Colors.white.withOpacity(.12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _sectionTitle('Subject Performance'),
                      if (subjectPerformance.isEmpty)
                        _emptyStateCard(
                            'No subject performance has been recorded for this class yet.')
                      else
                        ...subjectPerformance.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _adminCard,
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: _adminInk.withOpacity(.08)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (item['subjectName'] ?? '-').toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _adminInk,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item['assessments'] ?? 0} assessments',
                                        style:
                                            const TextStyle(color: _adminMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${_toDouble(item['average']).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: _adminInk,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 18),
                      _sectionTitle('Student Performance'),
                      if (studentPerformance.isEmpty)
                        _emptyStateCard(
                            'No students are assigned to this class yet.')
                      else
                        ...studentPerformance.map((item) {
                          final subjectAverages =
                              List<Map<String, dynamic>>.from(
                                  item['subjectAverages'] ?? []);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _adminCard,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: _adminInk.withOpacity(.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (item['displayName'] ?? '-')
                                                .toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: _adminInk,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Student ID: ${(item['studentLabel'] ?? '-').toString()}',
                                            style: const TextStyle(
                                                color: _adminMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${_toDouble(item['overallAverage']).toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                            color: _adminInk,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Overall',
                                          style: TextStyle(
                                              color:
                                                  _adminMuted.withOpacity(.85)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _metricPill(
                                      'Attendance',
                                      '${_toDouble(item['attendancePercent']).toStringAsFixed(1)}%',
                                    ),
                                    _metricPill(
                                      'Present',
                                      '${item['presentCount'] ?? 0}/${item['attendanceRecords'] ?? 0}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (subjectAverages.isEmpty)
                                  const Text(
                                    'No subject marks entered yet.',
                                    style: TextStyle(color: _adminMuted),
                                  )
                                else
                                  ...subjectAverages.map((subject) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (subject['subjectName'] ?? '-')
                                                  .toString(),
                                              style: const TextStyle(
                                                  color: _adminInk),
                                            ),
                                          ),
                                          Text(
                                            '${_toDouble(subject['average']).toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              color: _adminInk,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _countCard(String label, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF7F1E3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _adminInk.withOpacity(.08)),
        boxShadow: [
          BoxShadow(
            color: _adminInk.withOpacity(.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _adminInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: _adminMuted)),
        ],
      ),
    );
  }

  Widget _metricPill(
    String label,
    String value, {
    Color foreground = _adminInk,
    Color background = const Color(0xFFF1F5F9),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: foreground.withOpacity(.75), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _adminCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _adminInk.withOpacity(.08)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: _adminMuted),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _adminInk,
        ),
      ),
    );
  }

  Widget _directoryList(
      List<Map<String, dynamic>> items, String fallbackSubtitle) {
    return Column(
      children: items.map((item) {
        final first = item['first_name']?.toString() ??
            item['name']?.toString() ??
            item['id'].toString();
        final last = item['last_name']?.toString() ?? '';
        final subtitle = item['email']?.toString() ??
            item['section']?.toString() ??
            fallbackSubtitle;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: _adminInk.withOpacity(.12),
            child: Text(
              first.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                  color: _adminInk, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text('$first $last'.trim()),
          subtitle: Text(subtitle),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _adminCanvas,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: _adminInk,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadDashboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};
          final students =
              List<Map<String, dynamic>>.from(data['students'] ?? []);
          final teachers =
              List<Map<String, dynamic>>.from(data['teachers'] ?? []);
          final parents =
              List<Map<String, dynamic>>.from(data['parents'] ?? []);
          final admins = List<Map<String, dynamic>>.from(data['admins'] ?? []);
          final classes =
              List<Map<String, dynamic>>.from(data['classes'] ?? []);
          final subjects =
              List<Map<String, dynamic>>.from(data['subjects'] ?? []);
          final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
          final announcements =
              List<Map<String, dynamic>>.from(data['announcements'] ?? []);
          final relations =
              List<Map<String, dynamic>>.from(data['relations'] ?? []);
          final attendance =
              List<Map<String, dynamic>>.from(data['attendance'] ?? []);
          final feePayments =
              List<Map<String, dynamic>>.from(data['feePayments'] ?? []);
          final feeStructures =
              List<Map<String, dynamic>>.from(data['feeStructures'] ?? []);
          final receipts =
              List<Map<String, dynamic>>.from(data['receipts'] ?? []);
          final complaints =
              List<Map<String, dynamic>>.from(data['complaints'] ?? []);
          final notifications =
              List<Map<String, dynamic>>.from(data['notifications'] ?? []);
          final classSummaries = _buildClassSummaries(
            classes: classes,
            students: students,
            attendance: attendance,
          );

          final totalExpectedFees =
              students.fold<int>(0, (sum, s) => sum + _toInt(s['full_fees']));
          final totalDueFees =
              students.fold<int>(0, (sum, s) => sum + _toInt(s['fees']));
          final totalCollectedFees = feePayments.fold<int>(
            0,
            (sum, p) => sum + _toInt(p['amount']),
          );
          final openComplaints =
              complaints.where((c) => c['resolved'] != true).length;
          final presentCount = attendance
              .where((a) => (a['status'] ?? '').toString() == 'present')
              .length;
          final absentCount = attendance
              .where((a) => (a['status'] ?? '').toString() == 'absent')
              .length;
          final allUsers = [
            ...students.map((e) => {...e, '_collection': 'students'}),
            ...teachers.map((e) => {...e, '_collection': 'teacher'}),
            ...parents.map((e) => {...e, '_collection': 'parents'}),
            ...admins.map((e) => {...e, '_collection': 'admins'}),
          ];

          return DefaultTabController(
            length: 5,
            child: Column(
              children: [
                const TabBar(
                  labelColor: _adminInk,
                  unselectedLabelColor: _adminMuted,
                  indicatorColor: _adminAccent,
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'CRUD'),
                    Tab(text: 'Attendance'),
                    Tab(text: 'Fees & Reports'),
                    Tab(text: 'Exams'),
                  ],
                ),
                if (_loading) const LinearProgressIndicator(),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: const LinearGradient(
                                colors: [_adminInk, Color(0xFF274F72)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Admin Control Center',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Create student profiles, link parents, and inspect each class from one place.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _metricPill(
                                      'Classes',
                                      '${classes.length}',
                                      foreground: Colors.white,
                                      background: Colors.white.withOpacity(.12),
                                    ),
                                    _metricPill(
                                      'Present',
                                      '$presentCount',
                                      foreground: Colors.white,
                                      background: Colors.white.withOpacity(.12),
                                    ),
                                    _metricPill(
                                      'Absent',
                                      '$absentCount',
                                      foreground: Colors.white,
                                      background: Colors.white.withOpacity(.12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                  width: 150,
                                  child:
                                      _countCard('Students', students.length)),
                              SizedBox(
                                  width: 150,
                                  child:
                                      _countCard('Teachers', teachers.length)),
                              SizedBox(
                                  width: 150,
                                  child: _countCard('Parents', parents.length)),
                              SizedBox(
                                  width: 150,
                                  child: _countCard('Classes', classes.length)),
                              SizedBox(
                                  width: 150,
                                  child:
                                      _countCard('Subjects', subjects.length)),
                              SizedBox(
                                  width: 150,
                                  child: _countCard(
                                      'Relations', relations.length)),
                              SizedBox(
                                  width: 150,
                                  child: _countCard('Tasks', tasks.length)),
                              SizedBox(
                                  width: 150,
                                  child: _countCard(
                                      'Announcements', announcements.length)),
                              SizedBox(
                                  width: 150,
                                  child: _countCard('Admins', admins.length)),
                              SizedBox(
                                  width: 150,
                                  child: _countCard(
                                      'Attendance', attendance.length)),
                              SizedBox(
                                  width: 150,
                                  child: _countCard(
                                      'Fee Payments', feePayments.length)),
                              SizedBox(
                                  width: 150,
                                  child: _countCard(
                                      'Complaints', complaints.length)),
                              SizedBox(
                                  width: 150,
                                  child: _countCard(
                                      'Notifications', notifications.length)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _sectionTitle('Classes Overview'),
                          if (classSummaries.isEmpty)
                            _emptyStateCard('No classes found yet.')
                          else
                            ...classSummaries.map((summary) {
                              return InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () => _openClassInsights(
                                  classSummary: summary,
                                  students: students,
                                  attendance: attendance,
                                  subjects: subjects,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: _adminCard,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                        color: _adminInk.withOpacity(.08)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (summary['label'] ?? '-')
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                    color: _adminInk,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Tap to view subject performance, overall scores and attendance.',
                                                  style: TextStyle(
                                                    color: _adminMuted
                                                        .withOpacity(.95),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right,
                                              color: _adminInk),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _metricPill('Students',
                                              '${summary['studentCount'] ?? 0}'),
                                          _metricPill('Present',
                                              '${summary['presentCount'] ?? 0}'),
                                          _metricPill('Absent',
                                              '${summary['absentCount'] ?? 0}'),
                                          _metricPill(
                                            'Attendance',
                                            '${_toDouble(summary['attendancePercent']).toStringAsFixed(1)}%',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(height: 12),
                          _sectionTitle('School Directory'),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _adminCard,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: _adminInk.withOpacity(.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('Teachers'),
                                _directoryList(teachers, 'Teacher'),
                                const SizedBox(height: 12),
                                _sectionTitle('Students'),
                                _directoryList(students, 'Student'),
                                const SizedBox(height: 12),
                                _sectionTitle('Parents'),
                                _directoryList(parents, 'Parent'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _sectionTitle('Create/Update Class'),
                          TextField(
                            controller: _classId,
                            decoration:
                                const InputDecoration(labelText: 'Class UID'),
                          ),
                          TextField(
                            controller: _classGrade,
                            decoration:
                                const InputDecoration(labelText: 'Grade'),
                          ),
                          TextField(
                            controller: _classSection,
                            decoration:
                                const InputDecoration(labelText: 'Section'),
                          ),
                          TextField(
                            controller: _classStudents,
                            decoration: const InputDecoration(
                                labelText: 'Number of students'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loading ? null : _saveClass,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white),
                            child: const Text('Save Class'),
                          ),
                          const Divider(height: 28),
                          _sectionTitle('Create/Update Subject'),
                          TextField(
                            controller: _subjectId,
                            decoration:
                                const InputDecoration(labelText: 'Subject UID'),
                          ),
                          TextField(
                            controller: _subjectName,
                            decoration: const InputDecoration(
                                labelText: 'Subject name'),
                          ),
                          TextField(
                            controller: _subjectGrade,
                            decoration:
                                const InputDecoration(labelText: 'Grade'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loading ? null : _saveSubject,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white),
                            child: const Text('Save Subject'),
                          ),
                          const Divider(height: 28),
                          _sectionTitle('Assign Subject To Teacher'),
                          TextField(
                            controller: _assignTeacherUid,
                            decoration:
                                const InputDecoration(labelText: 'Teacher UID'),
                          ),
                          TextField(
                            controller: _assignSubjectUid,
                            decoration:
                                const InputDecoration(labelText: 'Subject UID'),
                          ),
                          TextField(
                            controller: _assignGrade,
                            decoration: const InputDecoration(
                              labelText: 'Grade (optional)',
                            ),
                          ),
                          TextField(
                            controller: _assignClassIds,
                            decoration: const InputDecoration(
                              labelText: 'Class IDs (comma separated)',
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loading ? null : _assignTeacherSubject,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white),
                            child: const Text('Assign Subject'),
                          ),
                          const Divider(height: 28),
                          _sectionTitle('Create/Update User Profile'),
                          if (_editingUserUid != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _adminCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _adminInk.withOpacity(.15)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Editing user: $_editingUserUid (${_editingUserCollection ?? ''})',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loading ? null : _clearUserForm,
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            ),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            items: const [
                              DropdownMenuItem(
                                  value: 'student', child: Text('Student')),
                              DropdownMenuItem(
                                  value: 'teacher', child: Text('Teacher')),
                              DropdownMenuItem(
                                  value: 'parent', child: Text('Parent')),
                              DropdownMenuItem(
                                  value: 'admin', child: Text('Admin')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedRole = value);
                              }
                            },
                          ),
                          TextField(
                            controller: _userFirstName,
                            decoration:
                                const InputDecoration(labelText: 'First name'),
                          ),
                          TextField(
                            controller: _userLastName,
                            decoration:
                                const InputDecoration(labelText: 'Last name'),
                          ),
                          TextField(
                            controller: _userEmail,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                          TextField(
                            controller: _userPassword,
                            decoration: const InputDecoration(
                                labelText: 'Password (only for new login)'),
                          ),
                          TextField(
                            controller: _userPhone,
                            decoration:
                                const InputDecoration(labelText: 'Phone'),
                          ),
                          if (_selectedRole == 'student') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _userStudentId,
                                    decoration: const InputDecoration(
                                        labelText: 'Student ID'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: _loading
                                      ? null
                                      : () {
                                          setState(() {
                                            _userStudentId.text =
                                                _buildStudentId();
                                          });
                                        },
                                  child: const Text('Generate ID'),
                                ),
                              ],
                            ),
                            TextField(
                              controller: _userClassId,
                              decoration:
                                  const InputDecoration(labelText: 'Class ID'),
                            ),
                            TextField(
                              controller: _userClassName,
                              decoration: const InputDecoration(
                                  labelText: 'Class name'),
                            ),
                            TextField(
                              controller: _userGrade,
                              decoration:
                                  const InputDecoration(labelText: 'Grade'),
                            ),
                          ],
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loading ? null : _saveUser,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _adminInk,
                                foregroundColor: Colors.white),
                            child: const Text('Save User'),
                          ),
                          const Divider(height: 28),
                          _sectionTitle('Link Student To Parent'),
                          TextField(
                            controller: _linkStudentLookup,
                            decoration: const InputDecoration(
                              labelText: 'Student UID or Student ID',
                            ),
                          ),
                          TextField(
                            controller: _linkParentLookup,
                            decoration: const InputDecoration(
                              labelText: 'Parent UID or Parent Email',
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loading ? null : _linkStudentToParent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _adminAccent,
                              foregroundColor: _adminInk,
                            ),
                            child: const Text('Link Parent'),
                          ),
                          const Divider(height: 28),
                          _sectionTitle('Delete Class/Subject/User Profile'),
                          ...classes.map((e) => ListTile(
                                title: Text('Class ${e['id']}'),
                                subtitle: Text(
                                    '${e['acadimic_year']}-${e['section']}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: _loading
                                      ? null
                                      : () => _deleteDoc(
                                          'class-room', e['id'].toString()),
                                ),
                              )),
                          ...subjects.map((e) => ListTile(
                                title: Text('Subject ${e['id']}'),
                                subtitle: Text(e['name'].toString()),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: _loading
                                      ? null
                                      : () => _deleteDoc(
                                          'subject', e['id'].toString()),
                                ),
                              )),
                          ...allUsers.map((e) => ListTile(
                                title: Text(
                                    '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'
                                        .trim()),
                                subtitle:
                                    Text('${e['email']} • ${e['_collection']}'),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: primaryColor),
                                      onPressed: _loading
                                          ? null
                                          : () => _startUserEdit(e),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: _loading
                                          ? null
                                          : () => _deleteDoc(
                                                e['_collection'].toString(),
                                                e['id'].toString(),
                                              ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _sectionTitle('Attendance Overview'),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _adminCard,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: _adminInk.withOpacity(.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Records: ${attendance.length}'),
                                Text('Present: $presentCount'),
                                Text('Absent: $absentCount'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _sectionTitle('Attendance Records'),
                          if (attendance.isEmpty)
                            const Text('No attendance records found')
                          else
                            ...attendance.map((a) {
                              final status = (a['status'] ?? 'absent')
                                  .toString()
                                  .toUpperCase();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: _adminCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _adminInk.withOpacity(.08)),
                                ),
                                child: ListTile(
                                  title: Text(
                                    'Student: ${(a['student_id'] ?? '-').toString()}',
                                  ),
                                  subtitle: Text(
                                    'Class: ${(a['class_id'] ?? '-').toString()} • Date: ${(a['date_key'] ?? '-').toString()}',
                                  ),
                                  trailing: Chip(label: Text(status)),
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _sectionTitle('Fees Management'),
                          TextField(
                            controller: _feeStructureTitle,
                            decoration: const InputDecoration(
                              labelText: 'Fee Structure Title',
                            ),
                          ),
                          TextField(
                            controller: _feeStructureClassId,
                            decoration: const InputDecoration(
                              labelText: 'Class ID',
                            ),
                          ),
                          TextField(
                            controller: _feeStructureGrade,
                            decoration: const InputDecoration(
                              labelText: 'Grade',
                            ),
                          ),
                          TextField(
                            controller: _feeStructureAmount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                            ),
                          ),
                          TextField(
                            controller: _feeAcademicYear,
                            decoration: const InputDecoration(
                              labelText: 'Academic Year',
                            ),
                          ),
                          TextField(
                            controller: _feeTerm,
                            decoration: const InputDecoration(
                              labelText: 'Term',
                            ),
                          ),
                          TextField(
                            controller: _feeNotes,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _pickFeeDueDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(_dateLabel(_feeDueDate)),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loading ? null : _saveFeeStructure,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Create Fee Structure'),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _adminCard,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: _adminInk.withOpacity(.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Fee Structures Created: ${feeStructures.length}'),
                                Text('Receipts Generated: ${receipts.length}'),
                                Text('Online Payments: ${feePayments.length}'),
                              ],
                            ),
                          ),
                          TextField(
                            controller: _feeStudentUid,
                            decoration: const InputDecoration(
                              labelText: 'Student UID (legacy direct override)',
                            ),
                          ),
                          TextField(
                            controller: _feeTotal,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Fees (legacy direct override)',
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loading ? null : _saveStudentFeePlan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save Direct Fee Plan'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _feePaymentAmount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Payment Amount',
                            ),
                          ),
                          TextField(
                            controller: _feePaymentNote,
                            decoration: const InputDecoration(
                              labelText: 'Payment Note',
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loading ? null : _addFeePayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Record Manual Payment'),
                          ),
                          const SizedBox(height: 16),
                          _sectionTitle('Recent Fee Structures'),
                          if (feeStructures.isEmpty)
                            const Text('No fee structures created yet')
                          else
                            ...feeStructures.take(5).map((fee) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: _adminCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _adminInk.withOpacity(.08)),
                                ),
                                child: ListTile(
                                  leading:
                                      const Icon(Icons.request_quote_outlined),
                                  title: Text((fee['title'] ?? '-').toString()),
                                  subtitle: Text(
                                    'Class: ${(fee['class_id'] ?? '-')} · Grade: ${(fee['grade'] ?? '-')} · Amount: ${_toInt(fee['amount'])}',
                                  ),
                                ),
                              );
                            }).toList(),
                          const SizedBox(height: 12),
                          _sectionTitle('Recent Receipts'),
                          if (receipts.isEmpty)
                            const Text('No receipts generated yet')
                          else
                            ...receipts.take(5).map((receipt) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: _adminCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _adminInk.withOpacity(.08)),
                                ),
                                child: ListTile(
                                  leading:
                                      const Icon(Icons.receipt_long_outlined),
                                  title: Text(
                                    (receipt['receipt_number'] ??
                                            receipt['id'] ??
                                            '-')
                                        .toString(),
                                  ),
                                  subtitle: Text(
                                    'Student: ${(receipt['student_name'] ?? receipt['student_id'] ?? '-')} · Amount: ${_toInt(receipt['amount'])}',
                                  ),
                                ),
                              );
                            }).toList(),
                          const Divider(height: 28),
                          _sectionTitle('Broadcast Notification'),
                          DropdownButtonFormField<String>(
                            value: _selectedNotifyTarget,
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All Users'),
                              ),
                              DropdownMenuItem(
                                value: 'role:student',
                                child: Text('Students'),
                              ),
                              DropdownMenuItem(
                                value: 'role:teacher',
                                child: Text('Teachers'),
                              ),
                              DropdownMenuItem(
                                value: 'role:parent',
                                child: Text('Parents'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedNotifyTarget = value);
                              }
                            },
                          ),
                          TextField(
                            controller: _notifyTitle,
                            decoration:
                                const InputDecoration(labelText: 'Title'),
                          ),
                          TextField(
                            controller: _notifyBody,
                            decoration:
                                const InputDecoration(labelText: 'Message'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loading ? null : _broadcastNotification,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Send Notification'),
                          ),
                          const Divider(height: 28),
                          _sectionTitle('Reports Summary'),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _adminCard,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: _adminInk.withOpacity(.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Expected Fees: $totalExpectedFees'),
                                Text(
                                    'Total Collected Fees: $totalCollectedFees'),
                                Text('Total Due Fees: $totalDueFees'),
                                Text(
                                    'Fee Structures Created: ${feeStructures.length}'),
                                Text('Receipts Generated: ${receipts.length}'),
                                Text('Open Complaints: $openComplaints'),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _exportReportCsv(
                                    students: students,
                                    feePayments: feePayments,
                                    complaints: complaints,
                                  ),
                                  icon:
                                      const Icon(Icons.file_download_outlined),
                                  label: const Text('Export CSV'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _sectionTitle('Complaints'),
                          if (complaints.isEmpty)
                            const Text('No complaints found')
                          else
                            ...complaints.map((c) {
                              final resolved = c['resolved'] == true;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: _adminCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _adminInk.withOpacity(.08)),
                                ),
                                child: ListTile(
                                  title: Text((c['title'] ?? '-').toString()),
                                  subtitle:
                                      Text((c['content'] ?? '-').toString()),
                                  trailing: resolved
                                      ? const Chip(label: Text('Resolved'))
                                      : TextButton(
                                          onPressed: _loading
                                              ? null
                                              : () => _resolveComplaint(c),
                                          child: const Text('Resolve'),
                                        ),
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                      // ── Tab 5: Exams ──────────────────────────────────────
                      FutureBuilder<QuerySnapshot>(
                        future: _firestore
                            .collection('exams')
                            .orderBy('created_at', descending: true)
                            .get(),
                        builder: (ctx, examSnap) {
                          final examDocs = examSnap.data?.docs ?? [];
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _sectionTitle('Create Exam'),
                              TextField(
                                controller: _examName,
                                decoration: const InputDecoration(
                                    labelText:
                                        'Exam Name (e.g. Mid-Term Math)'),
                              ),
                              TextField(
                                controller: _examSubjectId,
                                decoration: const InputDecoration(
                                    labelText: 'Subject ID'),
                              ),
                              TextField(
                                controller: _examClassId,
                                decoration: const InputDecoration(
                                    labelText: 'Class ID'),
                              ),
                              TextField(
                                controller: _examGrade,
                                decoration:
                                    const InputDecoration(labelText: 'Grade'),
                              ),
                              TextField(
                                controller: _examMaxMarks,
                                decoration: const InputDecoration(
                                    labelText: 'Max Marks'),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _examType,
                                decoration: const InputDecoration(
                                    labelText: 'Exam Type'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'exam1', child: Text('Exam 1')),
                                  DropdownMenuItem(
                                      value: 'exam2', child: Text('Exam 2')),
                                  DropdownMenuItem(
                                      value: 'tests', child: Text('Test')),
                                  DropdownMenuItem(
                                      value: 'homeworks',
                                      child: Text('Homework')),
                                ],
                                onChanged: _loading
                                    ? null
                                    : (v) => setState(
                                        () => _examType = v ?? 'exam1'),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _loading ? null : _saveExam,
                                icon: const Icon(Icons.add),
                                label: const Text('Create Exam'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _sectionTitle(
                                  'Existing Exams (${examDocs.length})'),
                              if (examDocs.isEmpty)
                                const Text('No exams created yet.')
                              else
                                ...examDocs.map((doc) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            primaryColor.withOpacity(.12),
                                        child: Icon(Icons.assignment_outlined,
                                            color: _adminInk),
                                      ),
                                      title:
                                          Text((d['name'] ?? '-').toString()),
                                      subtitle: Text(
                                          'Type: ${(d['exam_type'] ?? '-').toString().toUpperCase()} · '
                                          'Grade: ${(d['grade'] ?? '-')} · '
                                          'Max: ${(d['max_marks'] ?? 100)}'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: _loading
                                            ? null
                                            : () async {
                                                await _firestore
                                                    .collection('exams')
                                                    .doc(doc.id)
                                                    .delete();
                                                setState(() {});
                                              },
                                      ),
                                    ),
                                  );
                                }).toList(),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
