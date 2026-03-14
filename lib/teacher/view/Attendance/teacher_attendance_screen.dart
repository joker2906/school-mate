import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/teacher/resources/AttendanceServices/TAttendanceServices.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  final TAttendanceServices _service = TAttendanceServices();

  bool _loading = true;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, String>> _classes = [];
  String? _selectedClassId;
  List<Map<String, dynamic>> _students = [];
  Map<String, String> _statusByStudent = {};

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _loading = true);
    try {
      final classes = await _service.getTeacherClasses(UserInformation.User_uId);
      String? selected = _selectedClassId;
      if (classes.isNotEmpty) {
        selected ??= classes.first['id'];
      }
      setState(() {
        _classes = classes;
        _selectedClassId = selected;
      });
      await _loadClassData();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadClassData() async {
    final classId = _selectedClassId;
    if (classId == null || classId.isEmpty) {
      setState(() {
        _students = [];
        _statusByStudent = {};
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final students = await _service.getStudentsForClass(classId);
      final status = await _service.getAttendanceForDate(classId, _dateKey);

      for (final student in students) {
        final uid = student['uid'].toString();
        status.putIfAbsent(uid, () => 'absent');
      }

      setState(() {
        _students = students;
        _statusByStudent = status;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
    await _loadClassData();
  }

  Widget _statusChip(String status, String uid, String current) {
    final isSelected = current == status;
    return GestureDetector(
      onTap: () => setState(() => _statusByStudent[uid] = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (status == 'present' ? Colors.green : Colors.red)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (status == 'present'
                    ? Colors.green.shade700
                    : Colors.red.shade700)
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          status == 'present' ? 'P' : 'A',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAttendance() async {
    final classId = _selectedClassId;
    if (classId == null || classId.isEmpty || _students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No class/students selected')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.saveAttendance(
        classId: classId,
        dateKey: _dateKey,
        teacherId: UserInformation.User_uId,
        statusByStudent: _statusByStudent,
        students: _students,
      );
      if (!mounted) return;
      final presentCount =
          _statusByStudent.values.where((s) => s == 'present').length;
      final absentCount = _statusByStudent.length - presentCount;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Attendance Saved'),
          content: Text(
            '$presentCount present · $absentCount absent\n\nParents have been notified.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd MMM yyyy').format(_selectedDate);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedClassId,
                        isExpanded: true,
                        hint: const Text('Select class'),
                        items: _classes
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item['id'],
                                child: Text(item['label'] ?? item['id'] ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          setState(() => _selectedClassId = value);
                          await _loadClassData();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(dateLabel),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_classes.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No assigned classes found for this teacher.'),
                ),
              )
            else if (_students.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No students found in selected class.'),
                ),
              )
            else ...[  
              Builder(builder: (_) {
                final presentCount = _statusByStudent.values
                    .where((s) => s == 'present')
                    .length;
                final absentCount =
                    _statusByStudent.length - presentCount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      _summaryChip(Icons.check_circle,
                          '$presentCount Present', Colors.green),
                      const SizedBox(width: 8),
                      _summaryChip(
                          Icons.cancel, '$absentCount Absent', Colors.red),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          for (final k
                              in _statusByStudent.keys.toList()) {
                            _statusByStudent[k] = 'present';
                          }
                        }),
                        child: const Text('All Present'),
                      ),
                    ],
                  ),
                );
              }),
              Expanded(
                child: ListView.separated(
                  itemCount: _students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final uid = student['uid'].toString();
                    final name = student['name'].toString();
                    final value = _statusByStudent[uid] ?? 'absent';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(name.isEmpty ? uid : name),
                        subtitle: Text(uid),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _statusChip('present', uid, value),
                            const SizedBox(width: 6),
                            _statusChip('absent', uid, value),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Save Attendance'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
