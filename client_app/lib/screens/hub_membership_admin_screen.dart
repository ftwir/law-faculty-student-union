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

class _HubMembershipAdminScreenState extends State<HubMembershipAdminScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabs;
  late Future<List<dynamic>> _requests;
  late Future<List<dynamic>> _members;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _requests = _api.getHubMembershipRequests(widget.hub.id);
    _members = _api.getHubMembers(widget.hub.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _requests = _api.getHubMembershipRequests(widget.hub.id);
      _members = _api.getHubMembers(widget.hub.id);
    });
    await Future.wait([_requests, _members]);
  }

  Future<void> _handle(int userId, bool approve) async {
    try {
      if (approve) {
        await _api.approveHubMember(widget.hub.id, userId);
      } else {
        await _api.rejectHubMember(widget.hub.id, userId);
      }
      if (!mounted) return;
      setState(() => _requests = _api.getHubMembershipRequests(widget.hub.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'تمت الموافقة على العضو.' : 'تم رفض طلب الانضمام.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _requestsView() {
    return FutureBuilder<List<dynamic>>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            children: [
              const SizedBox(height: 180),
              const Icon(Icons.error_outline, size: 52, color: AppColors.neonViolet),
              const SizedBox(height: 16),
              Text(snapshot.error.toString(), textAlign: TextAlign.center),
              TextButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
            ],
          );
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 200),
              Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.neonViolet),
              SizedBox(height: 16),
              Center(child: Text('لا توجد طلبات انضمام معلقة.')),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final request = Map<String, dynamic>.from(requests[index] as Map);
            final userId = int.tryParse(request['user']?.toString() ?? '') ?? 0;
            final name = (request['user_name']?.toString() ?? '').trim().isEmpty
                ? 'عضو #' + userId.toString()
                : request['user_name'].toString();

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
                          child: Text(
                            name.characters.first,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
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
        );
      },
    );
  }

  Widget _membersView() {
    return FutureBuilder<List<dynamic>>(
      future: _members,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            children: [
              const SizedBox(height: 180),
              Text(snapshot.error.toString(), textAlign: TextAlign.center),
              TextButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
            ],
          );
        }

        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return const Center(child: Text('لا يوجد أعضاء مقبولون في هذا القسم.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, index) {
            final member = Map<String, dynamic>.from(members[index] as Map);
            final role = member['user_role']?.toString() ?? 'member';
            final hubRole = member['role']?.toString() ?? 'member';
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(member['user_name']?.toString() ?? 'عضو'),
                subtitle: Text(
                  'الحساب: ' + role + ' • دور القسم: ' + hubRole,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة ' + widget.hub.name),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'طلبات الانضمام', icon: Icon(Icons.person_add)),
            Tab(text: 'الأعضاء', icon: Icon(Icons.groups)),
          ],
        ),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _requestsView(),
          _membersView(),
        ],
      ),
    );
  }
}
