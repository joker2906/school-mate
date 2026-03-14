import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/notifications/notification_service.dart';
import 'package:school_management_system/public/utils/constant.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  String get _role => (GetStorage().read('role') ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await NotificationService.listFor(
        uid: UserInformation.User_uId,
        role: _role,
        classId: UserInformation.classid.toString(),
      );
      setState(() {
        _items = rows;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) {
      return;
    }
    await NotificationService.markRead(
      notificationId: id,
      uid: UserInformation.User_uId,
    );
    await _load();
  }

  bool _isRead(Map<String, dynamic> item) {
    final readBy = (item['read_by'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return readBy.contains(UserInformation.User_uId);
  }

  String _formatDate(Map<String, dynamic> item) {
    final ts = item['created_at'];
    if (ts == null) {
      return '-';
    }
    try {
      final dt = ts.toDate();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: 220),
                      Center(child: Text('No notifications yet.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isRead = _isRead(item);
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRead ? Colors.transparent : primaryColor,
                            width: isRead ? 0 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _markAsRead(item),
                          leading: Icon(
                            isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: isRead ? Colors.grey : primaryColor,
                          ),
                          title: Text(
                            (item['title'] ?? '').toString(),
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text((item['body'] ?? '').toString()),
                              const SizedBox(height: 6),
                              Text(
                                _formatDate(item),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: _items.length,
                  ),
      ),
    );
  }
}
