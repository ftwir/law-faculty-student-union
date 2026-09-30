import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/hub.dart';
import '../theme.dart';

class HubMembershipAdminScreen extends StatefulWidget {
  final Hub hub;
  const HubMembershipAdminScreen({super.key, required this.hub});

  @override
  State<HubMembershipAdminScreen> createState() => _HubMembershipAdminScreenState();
}

class _HubMembershipAdminScreenState extends State<HubMembershipAdminScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<dynamic>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _load();
  }

  Future<List<dynamic>> _load() => _api.getHubMembershipRequests(widget.hub.id);

  Future<void> _refresh() async {
    setState(() => _requests = _load());
    await _requests;
  }

  Future<void> _handle(int userId, bool approve) async {
    try {
      if (approve) {
        await _api.approveHubMember(widget.hub.id, userId);
      } else {
        await _api.rejectHubMember(widget.hub.id, userId);
      }
      if (!mounted) return;
      setState(() => _requests = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'تمت الموافقة على العضو.' : 'تم رفض طلب الانضمام.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('طلبات ' + widget.hub.name)),
      body: FutureBuilder<List<dynamic>>(
        future: _requests,
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
                  const Icon(Icons.error_outline, size: 52, color: AppColors.neonViolet),
                  const SizedBox(height: 16),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  TextButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
                ],
              ),
            );
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.neonViolet),
                  SizedBox(height: 16),
                  Center(child: Text('لا توجد طلبات انضمام معلقة.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final request = Map<String, dynamic>.from(requests[index] as Map);
                final userId = int.tryParse(request['user']?.toString() ?? '') ?? 0;
                final rawName = request['user_name']?.toString() ?? '';
                final name = rawName.trim().isEmpty ? 'عضو #' + userId.toString() : rawName;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryPurple,
                              child: Text(name.characters.first, style: const TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: userId == 0 ? null : () => _handle(userId, false),
                                icon: const Icon(Icons.close),
                                label: const Text('رفض'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: userId == 0 ? null : () => _handle(userId, true),
                                icon: const Icon(Icons.check),
                                label: const Text('موافقة'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
