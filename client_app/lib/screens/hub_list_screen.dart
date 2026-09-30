import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/hub.dart';
import '../theme.dart';
import 'hub_detail_screen.dart';

class HubListScreen extends StatefulWidget {
  const HubListScreen({super.key});
  @override
  State<HubListScreen> createState() => _HubListScreenState();
}

class _HubListScreenState extends State<HubListScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<Hub>> _hubsFuture;

  @override
  void initState() {
    super.initState();
    _hubsFuture = _loadHubs();
  }

  Future<List<Hub>> _loadHubs() async {
    final raw = await _api.getHubs();
    return raw.map((item) => Hub.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<void> _refresh() async {
    setState(() => _hubsFuture = _loadHubs());
    await _hubsFuture;
  }

  String _statusLabel(Hub hub) {
    switch (hub.membershipStatus) {
      case 'approved':
        return 'تمت الموافقة';
      case 'pending':
        return 'بانتظار موافقة الأدمن';
      case 'rejected':
        return 'تم رفض الطلب - اضغط لإعادة الطلب';
      default:
        return 'طلب الانضمام';
    }
  }

  Future<void> _openHub(Hub hub) async {
    if (hub.membershipStatus == 'approved' || hub.isHubAdmin) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => HubDetailScreen(hub: hub)));
      return;
    }

    try {
      final status = await _api.requestHubMembership(hub.id);
      if (!mounted) return;
      setState(() => _hubsFuture = _loadHubs());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'pending'
                ? 'تم إرسال طلب الانضمام. انتظر موافقة أدمن القسم.'
                : 'أنت عضو بالفعل في هذا القسم.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('السنوات والأقسام')),
      body: FutureBuilder<List<Hub>>(
        future: _hubsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  const Icon(Icons.cloud_off, size: 48, color: AppColors.neonViolet),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      snapshot.error.toString().replaceFirst('ApiException: ', ''),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
                ],
              ),
            );
          }

          final hubs = snapshot.data ?? [];
          if (hubs.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Icon(Icons.account_tree_outlined, size: 56, color: AppColors.neonViolet),
                  SizedBox(height: 16),
                  Center(child: Text('لا توجد سنوات أو أقسام حالياً')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: hubs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final hub = hubs[index];
                final approved = hub.membershipStatus == 'approved' || hub.isHubAdmin;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryPurple,
                      child: Icon(
                        hub.slug == 'general' ? Icons.public : Icons.school,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(hub.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        hub.description + '\n' + hub.memberCount.toString() + ' عضو • ' + _statusLabel(hub),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: Icon(
                      approved
                          ? Icons.arrow_forward_ios
                          : hub.membershipStatus == 'pending'
                              ? Icons.hourglass_top
                              : Icons.lock_outline,
                      size: 18,
                    ),
                    onTap: () => _openHub(hub),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
