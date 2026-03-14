import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/fees/fee_flow_service.dart';
import 'package:school_management_system/public/utils/constant.dart';

class StudentFeesScreen extends StatefulWidget {
  const StudentFeesScreen({Key? key}) : super(key: key);

  @override
  State<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends State<StudentFeesScreen> {
  bool _loading = true;
  Map<String, dynamic> _student = {};
  List<Map<String, dynamic>> _feeItems = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _receipts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _toInt(dynamic v) => int.tryParse((v ?? '0').toString()) ?? 0;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final studentSnap = await FirebaseFirestore.instance
          .collection('students')
          .doc(UserInformation.User_uId)
          .get();

      final student = Map<String, dynamic>.from(studentSnap.data() ?? {});
      final feeItems = await FeeFlowService.listStudentFeeItems(
        UserInformation.User_uId,
      );
      final payments = await FeeFlowService.listStudentPayments(
        UserInformation.User_uId,
      );
      final receipts = await FeeFlowService.listStudentReceipts(
        UserInformation.User_uId,
      );

      setState(() {
        _student = student;
        _feeItems = feeItems;
        _payments = payments;
        _receipts = receipts;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) {
      return '-';
    }
    try {
      return DateFormat('dd MMM yyyy').format(ts.toDate());
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = _toInt(_student['full_fees']);
    final due = _toInt(_student['fees']);
    final paid = full > 0 ? (full - due) : _toInt(_student['paid_fees']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fee Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Total Fees: $full'),
                        Text('Paid: $paid'),
                        Text(
                          'Due: $due',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Generated Fees',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_feeItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('No fee structures generated yet.'),
                    )
                  else
                    ..._feeItems.map((item) {
                      final amount = _toInt(item['amount']);
                      final itemPaid = _toInt(item['paid_amount']);
                      final itemDue = _toInt(item['due_amount']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.request_quote_outlined),
                          title: Text((item['title'] ?? 'Fee').toString()),
                          subtitle: Text(
                            'Amount: $amount | Paid: $itemPaid | Due: $itemDue\nDue Date: ${_formatDate(item['due_date'])}',
                          ),
                          trailing: Chip(
                            label: Text((item['status'] ?? 'due').toString()),
                          ),
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 12),
                  const Text(
                    'Payment History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_payments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(child: Text('No payment records yet.')),
                    )
                  else
                    ..._payments.map((p) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: Text('Amount: ${_toInt(p['amount'])}'),
                          subtitle: Text(
                            'Date: ${_formatDate(p['created_at'])}\nMethod: ${(p['payment_method'] ?? '-').toString()}\nGateway: ${(p['gateway_status'] ?? '-').toString()}\nNote: ${(p['note'] ?? '-').toString()}',
                          ),
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 12),
                  const Text(
                    'Receipts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_receipts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No receipts generated yet.'),
                    )
                  else
                    ..._receipts.map((receipt) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text(
                            (receipt['receipt_number'] ?? receipt['id'] ?? '-')
                                .toString(),
                          ),
                          subtitle: Text(
                            'Amount: ${_toInt(receipt['amount'])}\nGenerated: ${_formatDate(receipt['generated_at'])}\nGateway Ref: ${(receipt['gateway_reference'] ?? '-').toString()}',
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
