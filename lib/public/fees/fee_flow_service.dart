import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_management_system/public/notifications/notification_service.dart';

class FeePaymentResult {
  final String paymentId;
  final String receiptId;
  final String receiptNumber;
  final String gatewayReference;
  final int amount;

  const FeePaymentResult({
    required this.paymentId,
    required this.receiptId,
    required this.receiptNumber,
    required this.gatewayReference,
    required this.amount,
  });
}

class FeeFlowService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static int toInt(dynamic value) =>
      int.tryParse((value ?? '0').toString()) ?? 0;

  static Future<List<Map<String, dynamic>>> listStudentFeeItems(
    String studentUid,
  ) async {
    final snap = await _firestore
        .collection('student-fees')
        .where('student_id', isEqualTo: studentUid)
        .get();

    final items = snap.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = data['id'] ?? doc.id;
          return data;
        })
        .toList();

    items.sort((a, b) => _dateValue(a['due_date']).compareTo(_dateValue(b['due_date'])));
    return items;
  }

  static Future<List<Map<String, dynamic>>> listStudentPayments(
    String studentUid,
  ) async {
    final snap = await _firestore
        .collection('fee-payments')
        .where('student_id', isEqualTo: studentUid)
        .get();

    final rows = snap.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = data['id'] ?? doc.id;
          return data;
        })
        .toList();

    rows.sort(
      (a, b) => _dateValue(b['created_at']).compareTo(_dateValue(a['created_at'])),
    );
    return rows;
  }

  static Future<List<Map<String, dynamic>>> listStudentReceipts(
    String studentUid,
  ) async {
    final snap = await _firestore
        .collection('receipts')
        .where('student_id', isEqualTo: studentUid)
        .get();

    final rows = snap.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = data['id'] ?? doc.id;
          return data;
        })
        .toList();

    rows.sort(
      (a, b) => _dateValue(b['generated_at']).compareTo(_dateValue(a['generated_at'])),
    );
    return rows;
  }

  static Future<List<Map<String, dynamic>>> listFeeStructures() async {
    final snap = await _firestore.collection('fee-structures').get();
    final rows = snap.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = data['id'] ?? doc.id;
          return data;
        })
        .toList();
    rows.sort(
      (a, b) => _dateValue(b['created_at']).compareTo(_dateValue(a['created_at'])),
    );
    return rows;
  }

  static Future<int> createFeeStructure({
    required String title,
    required String classId,
    required String grade,
    required int amount,
    required String academicYear,
    required String term,
    String notes = '',
    DateTime? dueDate,
    required String createdBy,
  }) async {
    final structureId = _firestore.collection('fee-structures').doc().id;
    final due = dueDate ?? DateTime.now().add(const Duration(days: 14));

    await _firestore.collection('fee-structures').doc(structureId).set({
      'id': structureId,
      'title': title,
      'class_id': classId,
      'grade': grade,
      'amount': amount,
      'academic_year': academicYear,
      'term': term,
      'notes': notes,
      'due_date': Timestamp.fromDate(due),
      'created_at': Timestamp.now(),
      'created_by': createdBy,
      'status': 'active',
    }, const SetOptions(merge: true));

    final studentSnap = await _firestore
        .collection('students')
        .where('class_id', isEqualTo: classId)
        .get();

    final studentDocs = studentSnap.docs.where((doc) {
      if (grade.trim().isEmpty) {
        return true;
      }
      return (doc.data()['grade'] ?? '').toString() == grade;
    }).toList();

    final studentUids = <String>[];
    final parentUids = <String>[];

    for (final studentDoc in studentDocs) {
      final studentData = Map<String, dynamic>.from(studentDoc.data());
      final studentUid = (studentData['uid'] ?? studentDoc.id).toString();
      final itemId = 'fee_${structureId}_$studentUid';
      final className = (studentData['class_name'] ?? classId).toString();

      await _firestore.collection('student-fees').doc(itemId).set({
        'id': itemId,
        'structure_id': structureId,
        'student_id': studentUid,
        'class_id': classId,
        'class_name': className,
        'grade': grade,
        'title': title,
        'amount': amount,
        'paid_amount': 0,
        'due_amount': amount,
        'term': term,
        'academic_year': academicYear,
        'notes': notes,
        'due_date': Timestamp.fromDate(due),
        'generated_at': Timestamp.now(),
        'status': 'due',
      }, const SetOptions(merge: true));

      studentUids.add(studentUid);
      final parentUid = await _resolveParentUidFromStudentData(studentData);
      if (parentUid != null && !parentUids.contains(parentUid)) {
        parentUids.add(parentUid);
      }
      await syncStudentFeeSummary(studentUid);
    }

    if (studentUids.isNotEmpty) {
      final dueLabel = _dateLabel(due);
      await NotificationService.createNotification(
        title: 'New Fee Structure Added',
        body: '$title of $amount has been generated for class $classId. Due by $dueLabel.',
        targets: [
          'role:admin',
          ...studentUids,
          ...parentUids,
        ],
        type: 'fees',
        data: {
          'structure_id': structureId,
          'class_id': classId,
          'grade': grade,
          'amount': amount,
          'term': term,
        },
      );
    }

    return studentUids.length;
  }

  static Future<FeePaymentResult> processParentPayment({
    required String studentUid,
    required String parentUid,
    required int amount,
    required String paymentMethod,
    String note = 'Parent online payment',
  }) async {
    await _ensureLegacyFeeItem(studentUid);

    final studentRef = _firestore.collection('students').doc(studentUid);
    final studentSnap = await studentRef.get();
    final studentData = Map<String, dynamic>.from(studentSnap.data() ?? {});
    final studentName = _studentName(studentData);

    final items = await listStudentFeeItems(studentUid);
    final openItems = items.where((item) => toInt(item['due_amount']) > 0).toList();
    final totalDue = openItems.fold<int>(0, (sum, item) => sum + toInt(item['due_amount']));
    if (totalDue <= 0) {
      throw Exception('No due fees available for payment');
    }

    final chargedAmount = amount > totalDue ? totalDue : amount;
    var remaining = chargedAmount;
    final paymentItems = <Map<String, dynamic>>[];

    for (final item in openItems) {
      if (remaining <= 0) {
        break;
      }
      final itemDue = toInt(item['due_amount']);
      final itemPaid = toInt(item['paid_amount']);
      final applied = remaining > itemDue ? itemDue : remaining;
      remaining -= applied;
      final nextPaid = itemPaid + applied;
      final nextDue = itemDue - applied;

      await _firestore.collection('student-fees').doc(item['id'].toString()).set({
        'paid_amount': nextPaid,
        'due_amount': nextDue,
        'status': nextDue == 0 ? 'paid' : 'partial',
        'last_payment_at': Timestamp.now(),
      }, const SetOptions(merge: true));

      paymentItems.add({
        'fee_item_id': item['id'],
        'title': item['title'],
        'applied_amount': applied,
      });
    }

    final gatewayReference = 'GW${DateTime.now().millisecondsSinceEpoch}';
    final paymentId = _firestore.collection('fee-payments').doc().id;
    await _firestore.collection('fee-payments').doc(paymentId).set({
      'id': paymentId,
      'student_id': studentUid,
      'parent_id': parentUid,
      'amount': chargedAmount,
      'note': note,
      'payment_method': paymentMethod,
      'gateway': 'SchoolMate Demo Gateway',
      'gateway_status': 'success',
      'gateway_reference': gatewayReference,
      'status': 'success',
      'payment_items': paymentItems,
      'created_at': Timestamp.now(),
      'recorded_by': parentUid,
    }, const SetOptions(merge: true));

    final summary = await syncStudentFeeSummary(studentUid);
    final receiptId = _firestore.collection('receipts').doc().id;
    final receiptNumber = _receiptNumber();
    await _firestore.collection('receipts').doc(receiptId).set({
      'id': receiptId,
      'receipt_number': receiptNumber,
      'payment_id': paymentId,
      'student_id': studentUid,
      'student_name': studentName,
      'parent_id': parentUid,
      'amount': chargedAmount,
      'payment_method': paymentMethod,
      'gateway_reference': gatewayReference,
      'generated_at': Timestamp.now(),
      'status': 'generated',
      'payment_items': paymentItems,
      'remaining_due': summary['due'],
    }, const SetOptions(merge: true));

    await NotificationService.createNotification(
      title: 'Fee Payment Success',
      body: 'Payment of $chargedAmount succeeded. Receipt $receiptNumber is ready.',
      targets: ['role:admin', parentUid, studentUid],
      type: 'fees',
      data: {
        'payment_id': paymentId,
        'receipt_id': receiptId,
        'receipt_number': receiptNumber,
        'student_id': studentUid,
      },
    );

    return FeePaymentResult(
      paymentId: paymentId,
      receiptId: receiptId,
      receiptNumber: receiptNumber,
      gatewayReference: gatewayReference,
      amount: chargedAmount,
    );
  }

  static Future<Map<String, int>> syncStudentFeeSummary(String studentUid) async {
    final items = await listStudentFeeItems(studentUid);
    final total = items.fold<int>(0, (sum, item) => sum + toInt(item['amount']));
    final paid = items.fold<int>(0, (sum, item) => sum + toInt(item['paid_amount']));
    final due = items.fold<int>(0, (sum, item) => sum + toInt(item['due_amount']));

    await _firestore.collection('students').doc(studentUid).set({
      'full_fees': total.toString(),
      'paid_fees': paid.toString(),
      'fees': due.toString(),
    }, const SetOptions(merge: true));

    return {
      'total': total,
      'paid': paid,
      'due': due,
    };
  }

  static Future<void> _ensureLegacyFeeItem(String studentUid) async {
    final items = await listStudentFeeItems(studentUid);
    if (items.isNotEmpty) {
      return;
    }

    final snap = await _firestore.collection('students').doc(studentUid).get();
    final data = Map<String, dynamic>.from(snap.data() ?? {});
    final due = toInt(data['fees']);
    final full = toInt(data['full_fees']) == 0 ? due : toInt(data['full_fees']);
    final paid = full - due < 0 ? 0 : full - due;

    if (full <= 0 && due <= 0) {
      return;
    }

    final legacyId = 'legacy_fee_$studentUid';
    await _firestore.collection('student-fees').doc(legacyId).set({
      'id': legacyId,
      'structure_id': 'legacy',
      'student_id': studentUid,
      'class_id': (data['class_id'] ?? '').toString(),
      'class_name': (data['class_name'] ?? '').toString(),
      'grade': (data['grade'] ?? '').toString(),
      'title': 'Existing Fee Balance',
      'amount': full,
      'paid_amount': paid,
      'due_amount': due,
      'term': 'legacy',
      'academic_year': 'legacy',
      'notes': 'Migrated from existing student fee summary',
      'due_date': Timestamp.now(),
      'generated_at': Timestamp.now(),
      'status': due == 0 ? 'paid' : (paid > 0 ? 'partial' : 'due'),
    }, const SetOptions(merge: true));
  }

  static Future<String?> _resolveParentUidFromStudentData(
    Map<String, dynamic> studentData,
  ) async {
    final parentEmail = (studentData['parent_email'] ?? '').toString();
    if (parentEmail.isEmpty) {
      return null;
    }

    final parentSnap = await _firestore
        .collection('parents')
        .where('email', isEqualTo: parentEmail)
        .limit(1)
        .get();
    if (parentSnap.docs.isEmpty) {
      return null;
    }
    final parentData = parentSnap.docs.first.data();
    return (parentData['uid'] ?? parentSnap.docs.first.id).toString();
  }

  static DateTime _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  static String _receiptNumber() {
    final now = DateTime.now();
    final yyyy = now.year.toString();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final tail = (now.microsecondsSinceEpoch % 100000).toString().padLeft(5, '0');
    return 'RCPT-$yyyy$mm$dd-$tail';
  }

  static String _studentName(Map<String, dynamic> studentData) {
    final first = (studentData['first_name'] ?? '').toString().trim();
    final last = (studentData['last_name'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Student' : full;
  }
}