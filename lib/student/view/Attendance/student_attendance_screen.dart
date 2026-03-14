import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/utils/constant.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('student_id', isEqualTo: UserInformation.User_uId)
          .orderBy('date_key', descending: true)
          .get();

      final records = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        records.add({
          'date_key': (data['date_key'] ?? '').toString(),
          'status': (data['status'] ?? 'absent').toString(),
          'class_id': (data['class_id'] ?? '').toString(),
        });
      }

      setState(() {
        _records = records;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _records.length;
    final present = _records.where((e) => e['status'] == 'present').length;
    final percentage = total == 0 ? 0 : ((present * 100) / total).round();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadAttendance,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text('Present: $present'),
                  Text('Total Classes: $total'),
                  Text('Percentage: $percentage%'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_records.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text('No attendance records yet.'),
                ),
              )
            else
              ..._records.map((record) {
                final rawDate = record['date_key'].toString();
                String label = rawDate;
                try {
                  final parsed = DateTime.parse(rawDate);
                  label = DateFormat('dd MMM yyyy').format(parsed);
                } catch (_) {}

                final isPresent = record['status'] == 'present';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isPresent ? Icons.check_circle : Icons.cancel,
                      color: isPresent ? Colors.green : Colors.red,
                    ),
                    title: Text(label),
                    subtitle: Text('Class: ${record['class_id']}'),
                    trailing: Text(
                      isPresent ? 'Present' : 'Absent',
                      style: TextStyle(
                        color: isPresent ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
