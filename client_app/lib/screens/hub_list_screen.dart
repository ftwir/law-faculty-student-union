import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/hub.dart';
import '../theme.dart';
import 'hub_detail_screen.dart';


class HubListScreen extends StatefulWidget {
  const HubListScreen({
    super.key,
  });


  @override
  State<HubListScreen> createState() =>
      _HubListScreenState();
}


class _HubListScreenState
    extends State<HubListScreen> {

  final ApiClient _api = ApiClient();

  late Future<List<Hub>> _hubsFuture;


  @override
  void initState() {
    super.initState();

    _hubsFuture = _loadHubs();
  }


  Future<List<Hub>> _loadHubs() async {
    final raw = await _api.getHubs();

    return raw
        .map(
          (item) => Hub.fromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
        .toList();
  }


  Future<void> _refresh() async {
    setState(() {
      _hubsFuture = _loadHubs();
    });

    await _hubsFuture;
  }


  @override
  Widget build(BuildContext context) {
    final isArabic =
        Localizations.localeOf(context)
                .languageCode ==
            'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic
              ? 'المجتمعات'
              : 'Communities',
        ),
      ),

      body: FutureBuilder<List<Hub>>(
        future: _hubsFuture,

        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,

              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),

                children: [
                  const SizedBox(height: 180),

                  const Icon(
                    Icons.cloud_off,
                    size: 48,
                    color:
                        AppColors.neonViolet,
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding:
                        const EdgeInsets.all(
                      24,
                    ),

                    child: Text(
                      snapshot.error
                          .toString()
                          .replaceFirst(
                            'ApiException: ',
                            '',
                          ),

                      textAlign:
                          TextAlign.center,
                    ),
                  ),

                  TextButton(
                    onPressed: _refresh,

                    child: Text(
                      isArabic
                          ? 'إعادة المحاولة'
                          : 'Try again',
                    ),
                  ),
                ],
              ),
            );
          }

          final hubs =
              snapshot.data ?? [];


          if (hubs.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,

              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),

                children: [
                  const SizedBox(height: 200),

                  const Icon(
                    Icons.groups_outlined,
                    size: 56,
                    color:
                        AppColors.neonViolet,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    isArabic
                        ? 'لا توجد مجتمعات بعد'
                        : 'No communities yet',

                    textAlign:
                        TextAlign.center,
                  ),
                ],
              ),
            );
          }


          return RefreshIndicator(
            onRefresh: _refresh,

            child:
                ListView.separated(
              physics:
                  const AlwaysScrollableScrollPhysics(),

              padding:
                  const EdgeInsets.all(
                16,
              ),

              itemCount:
                  hubs.length,

              separatorBuilder:
                  (_, __) =>
                      const SizedBox(
                    height: 12,
                  ),

              itemBuilder: (
                context,
                index,
              ) {
                final hub =
                    hubs[index];

                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.all(
                      16,
                    ),

                    leading:
                        const CircleAvatar(
                      backgroundColor:
                          AppColors
                              .primaryPurple,

                      child: Icon(
                        Icons.groups,
                        color:
                            Colors.white,
                      ),
                    ),

                    title: Text(
                      hub.name,

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    subtitle:
                        Text(
                      isArabic
                          ? '${hub.memberCount} عضو'
                          : '${hub.memberCount} members',
                    ),

                    trailing:
                        const Icon(
                      Icons
                          .arrow_forward_ios,
                      size: 16,
                    ),

                    onTap: () {
                      Navigator.of(
                        context,
                      ).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              HubDetailScreen(
                            hub: hub,
                          ),
                        ),
                      );
                    },
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
