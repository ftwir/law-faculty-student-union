import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';

class WikiScreen extends StatefulWidget {
  final int hubId;
  const WikiScreen({super.key, required this.hubId});
  @override State<WikiScreen> createState() => _WikiScreenState();
}

class _WikiScreenState extends State<WikiScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() => _api.getWiki(widget.hubId);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _editPage([Map<String, dynamic>? page]) async {
    final title = TextEditingController(text: page?['title']?.toString() ?? '');
    final summary = TextEditingController(text: page?['summary']?.toString() ?? '');
    final body = TextEditingController(text: page?['content']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(page == null ? 'صفحة ويكي جديدة' : 'تعديل صفحة الويكي'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: 10),
              TextField(controller: summary, maxLines: 2, decoration: const InputDecoration(labelText: 'ملخص مختصر')),
              const SizedBox(height: 10),
              TextField(controller: body, minLines: 7, maxLines: 14, decoration: const InputDecoration(labelText: 'محتوى الصفحة')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );

    final titleText = title.text.trim();
    final summaryText = summary.text.trim();
    final bodyText = body.text.trim();
    title.dispose();
    summary.dispose();
    body.dispose();
    if (saved != true || titleText.isEmpty || bodyText.isEmpty) return;

    try {
      if (page == null) {
        await _api.createWiki(hubId: widget.hubId, title: titleText, content: bodyText);
      } else {
        await _api.updateWiki(
          pageId: page['id'] as int,
          title: titleText,
          content: bodyText,
          summary: summaryText,
        );
      }
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deletePage(Map<String, dynamic> page) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الصفحة'),
        content: Text('هل تريد حذف صفحة «' + (page['title'] ?? '').toString() + '»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteWiki(page['id'] as int);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _openPage(Map<String, dynamic> page) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(page['title']?.toString() ?? ''),
        content: SingleChildScrollView(child: Text(page['content']?.toString() ?? '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الويكي'),
        actions: [
          IconButton(tooltip: 'تحديث', onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'إضافة صفحة', onPressed: () => _editPage(), icon: const Icon(Icons.add)),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  const Icon(Icons.cloud_off, size: 52),
                  const SizedBox(height: 16),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  TextButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
                ],
              ),
            );
          }

          final pages = snapshot.data ?? [];
          if (pages.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 190),
                  Icon(Icons.menu_book_outlined, size: 58, color: AppColors.neonViolet),
                  SizedBox(height: 16),
                  Center(child: Text('لا توجد صفحات ويكي بعد.')),
                  SizedBox(height: 8),
                  Center(child: Text('أنشئ أول صفحة معرفية للقسم.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: pages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final page = Map<String, dynamic>.from(pages[index] as Map);
                final summary = page['summary']?.toString().trim();
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                    title: Text(page['title']?.toString() ?? ''),
                    subtitle: Text(
                      summary != null && summary.isNotEmpty ? summary : (page['content']?.toString() ?? ''),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _openPage(page),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _editPage(page);
                        if (value == 'delete') _deletePage(page);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
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
