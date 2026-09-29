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
  final _api = ApiClient();
  late Future<List<Hub>> _hubsFuture;

  @override
  void initState() {
    super.initState();
    _hubsFuture = _loadHubs();
  }

  Future<List<Hub>> _loadHubs() async {
    final raw = await _api.getHubs();
    return raw.map((e) => Hub.fromJson(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأقسام')),
      body: FutureBuilder<List<Hub>>(
        future: _hubsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          final hubs = snapshot.data ?? [];
          if (hubs.isEmpty) {
            return const Center(child: Text('لا توجد أقسام بعد'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: hubs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final hub = hubs[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryPurple,
                    child: Icon(Icons.groups, color: Colors.white),
                  ),
                  title: Text(hub.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${hub.memberCount} عضو'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HubDetailScreen(hub: hub)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
