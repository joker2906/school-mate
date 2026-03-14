import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/fees/fee_flow_service.dart';
import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/student/resources/Parent/parentApi.dart';
import 'package:school_management_system/student/resources/Parent/stparentmodel.dart';

class ParentFeePaymentScreen extends StatefulWidget {
  const ParentFeePaymentScreen({Key? key}) : super(key: key);

  @override
  State<ParentFeePaymentScreen> createState() => _ParentFeePaymentScreenState();
}

class _ParentFeePaymentScreenState extends State<ParentFeePaymentScreen> {
  bool _loading = true;
  List<StudentP> _children = [];
  Map<String, List<Map<String, dynamic>>> _openFeeItemsByStudent = {};
  Map<String, Map<String, dynamic>> _latestReceiptByStudent = {};

  int _toInt(dynamic v) => int.tryParse((v ?? '0').toString()) ?? 0;

  String _formatDate(dynamic ts) {
    try {
      if (ts is Timestamp) {
        return DateFormat('dd MMM yyyy').format(ts.toDate());
      }
    } catch (_) {}
    return '-';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ParentApi.getStudents(UserInformation.email);
      final children = List<StudentP>.from(list ?? []);
      final openFeeItemsByStudent = <String, List<Map<String, dynamic>>>{};
      final latestReceiptByStudent = <String, Map<String, dynamic>>{};

      for (final child in children) {
        final studentUid = child.id.toString();
        final items = await FeeFlowService.listStudentFeeItems(studentUid);
        final openItems = items
            .where((item) => FeeFlowService.toInt(item['due_amount']) > 0)
            .take(3)
            .toList();
        final receipts = await FeeFlowService.listStudentReceipts(studentUid);
        openFeeItemsByStudent[studentUid] = openItems;
        if (receipts.isNotEmpty) {
          latestReceiptByStudent[studentUid] = receipts.first;
        }
      }

      setState(() {
        _children = children;
        _openFeeItemsByStudent = openFeeItemsByStudent;
        _latestReceiptByStudent = latestReceiptByStudent;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _payNow(StudentP child) async {
    final due = _toInt(child.fees);
    if (due <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No due fees for this student.')),
      );
      return;
    }

    final studentUid = child.id.toString();
    final feeItems = _openFeeItemsByStudent[studentUid] ?? const [];
    final amountController = TextEditingController(text: due.toString());
    String paymentMethod = 'UPI';
    final paymentData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Pay Fees'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${child.firstName} ${child.lastName}'),
                    const SizedBox(height: 8),
                    Text('Outstanding due: $due'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(labelText: 'Payment Method'),
                      items: const [
                        DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                        DropdownMenuItem(value: 'Card', child: Text('Card')),
                        DropdownMenuItem(value: 'Net Banking', child: Text('Net Banking')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => paymentMethod = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pending Fee Items',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (feeItems.isEmpty)
                      const Text('Existing balance will be applied automatically.')
                    else
                      ...feeItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${(item['title'] ?? 'Fee').toString()} • Due ${FeeFlowService.toInt(item['due_amount'])}',
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amount = int.tryParse(amountController.text.trim()) ?? 0;
                    Navigator.pop(ctx, {
                      'amount': amount,
                      'method': paymentMethod,
                    });
                  },
                  child: const Text('Open Gateway'),
                ),
              ],
            );
          },
        );
      },
    );

    final paidAmount = paymentData?['amount'] as int?;
    final method = (paymentData?['method'] ?? 'UPI').toString();
    if (paidAmount == null || paidAmount <= 0) {
      return;
    }

    final clamped = paidAmount > due ? due : paidAmount;

    setState(() => _loading = true);
    try {
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 14),
                Expanded(
                  child: Text('Processing payment on SchoolMate Demo Gateway...'),
                ),
              ],
            ),
          ),
        );
      }

      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final result = await FeeFlowService.processParentPayment(
        studentUid: studentUid,
        parentUid: UserInformation.User_uId,
        amount: clamped,
        paymentMethod: method,
      );

      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Payment Gateway Success'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount paid: ${result.amount}'),
                Text('Gateway ref: ${result.gatewayReference}'),
                Text('Receipt: ${result.receiptNumber}'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      await _load();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Fee Payment'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _children.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 220),
                      Center(child: Text('No linked students found.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _children.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final child = _children[index];
                      final studentUid = child.id.toString();
                      final due = _toInt(child.fees);
                      final full = _toInt(child.fullfees);
                      final paid = _toInt(child.paidfees);
                      final openItems = _openFeeItemsByStudent[studentUid] ?? const [];
                      final latestReceipt = _latestReceiptByStudent[studentUid];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${child.firstName} ${child.lastName}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Total: $full | Paid: $paid | Due: $due'),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: due <= 0 ? null : () => _payNow(child),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Pay'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Generated Fees',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              if (openItems.isEmpty)
                                const Text('No open fee items. Any legacy balance will still be payable.')
                              else
                                ...openItems.map((item) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '${(item['title'] ?? 'Fee').toString()} • Due ${FeeFlowService.toInt(item['due_amount'])} • ${_formatDate(item['due_date'])}',
                                    ),
                                  );
                                }).toList(),
                              if (latestReceipt != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Latest Receipt: ${(latestReceipt['receipt_number'] ?? latestReceipt['id'] ?? '-').toString()}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Generated on ${_formatDate(latestReceipt['generated_at'])}',
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
