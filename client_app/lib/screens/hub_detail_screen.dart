import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/hub.dart';
import '../theme.dart';


class HubDetailScreen extends StatefulWidget {
  final Hub hub;

  const HubDetailScreen({
    super.key,
    required this.hub,
  });


  @override
  State<HubDetailScreen> createState() =>
      _HubDetailScreenState();
}


class _HubDetailScreenState
    extends State<HubDetailScreen> {

  final ApiClient _api = ApiClient();

  final TextEditingController _postCtrl =
      TextEditingController();

  late Future<List<dynamic>> _postsFuture;

  bool _publishing = false;


  bool get _isArabic =>
      Localizations.localeOf(context).languageCode ==
      'ar';


  String _text(
    String ar,
    String en,
  ) {
    return _isArabic ? ar : en;
  }


  @override
  void initState() {
    super.initState();

    _postsFuture =
        _api.getPosts(widget.hub.id);
  }


  Future<void> _refresh() async {
    setState(() {
      _postsFuture =
          _api.getPosts(widget.hub.id);
    });

    await _postsFuture;
  }


  Future<void> _publish() async {
    final body =
        _postCtrl.text.trim();

    if (body.isEmpty || _publishing) {
      return;
    }


    setState(() {
      _publishing = true;
    });


    try {
      await _api.createPost(
        widget.hub.id,
        body,
      );

      _postCtrl.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _postsFuture =
            _api.getPosts(widget.hub.id);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
        });
      }
    }
  }


  @override
  void dispose() {
    _postCtrl.dispose();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hub.name),
      ),

      body: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              8,
            ),

            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end,

              children: [
                Expanded(
                  child: TextField(
                    controller:
                        _postCtrl,

                    minLines: 1,
                    maxLines: 5,

                    decoration:
                        InputDecoration(
                      hintText: _text(
                        'اكتب منشوراً...',
                        'Write a post...',
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                IconButton.filled(
                  onPressed:
                      _publishing
                          ? null
                          : _publish,

                  icon: _publishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,

                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send,
                        ),
                ),
              ],
            ),
          ),

          Expanded(
            child:
                FutureBuilder<List<dynamic>>(
              future: _postsFuture,

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
                        const SizedBox(
                          height: 160,
                        ),

                        Padding(
                          padding:
                              const EdgeInsets.all(
                            24,
                          ),

                          child: Text(
                            snapshot.error
                                .toString(),

                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final posts =
                    snapshot.data ?? [];


                if (posts.isEmpty) {
                  return RefreshIndicator(
                    onRefresh:
                        _refresh,

                    child: ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),

                      children: [
                        const SizedBox(
                          height: 180,
                        ),

                        const Icon(
                          Icons
                              .article_outlined,
                          size: 52,
                          color: AppColors
                              .neonViolet,
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        Text(
                          _text(
                            'لا توجد منشورات بعد',
                            'No posts yet',
                          ),

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
                      12,
                    ),

                    itemCount:
                        posts.length,

                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                          height: 10,
                        ),

                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final post =
                          Map<String, dynamic>.from(
                        posts[index] as Map,
                      );

                      return Card(
                        child:
                            Padding(
                          padding:
                              const EdgeInsets.all(
                            16,
                          ),

                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              Text(
                                post[
                                        'author_name'] ??
                                    '',

                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              Text(
                                post['body'] ??
                                    '',
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
          ),
        ],
      ),
    );
  }
}
