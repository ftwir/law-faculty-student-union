import 'package:flutter/material.dart';
import '../api/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String _kind(String value) {
    switch (value) {
      case 'chat_message':
        return 'رسالة جديدة';
      case 'badge_awarded':
        return 'شارة جديدة';
      case 'announcement':
        return 'إعلان';
      case 'mention':
        return 'إشارة إليك';
      default:
        return 'إشعار';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 180),
                            Center(child: Text('لا توجد إشعارات حالياً')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final item = Map<String, dynamic>.from(_items[index] as Map);
                            final payload = item['payload'];
                            final payloadMap = payload is Map
                                ? Map<String, dynamic>.from(payload)
                                : <String, dynamic>{};
                            final read = item['is_read'] == true;
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(read
                                      ? Icons.notifications_none
                                      : Icons.notifications_active),
                                ),
                                title: Text(_kind(item['kind']?.toString() ?? '')),
                                subtitle: Text(
                                  payloadMap['message']?.toString() ??
                                      payloadMap['body']?.toString() ??
                                      'لديك إشعار جديد.',
                                ),
                                trailing: read
                                    ? null
                                    : const Icon(Icons.circle, size: 10),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
