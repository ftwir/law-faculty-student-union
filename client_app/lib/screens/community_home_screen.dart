import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/hub.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'hub_detail_screen.dart';
import 'hub_list_screen.dart';
import 'notifications_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'wiki_screen.dart';

class CommunityHomeScreen extends StatefulWidget {
  const CommunityHomeScreen({super.key});
  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  final ApiClient api = ApiClient();
  int index = 0;
  List<dynamic> hubs = [];
  List<dynamic> rooms = [];
  Map<String, dynamic>? profile;
  Hub? selectedHub;
  bool loading = true;
  String? loadError;

  bool get ar => Localizations.localeOf(context).languageCode == 'ar';
  String t(String a, String e) => a;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });

    // Chat is optional: a temporary chat failure must never block the feed.
    final results = await Future.wait<dynamic>([
      api.getHubs().catchError((_) => <dynamic>[]),
      api.getChatRooms().catchError((_) => <dynamic>[]),
      api.me().catchError((error) => error),
    ]);

    if (!mounted) return;

    final meResult = results[2];
    final profileLoaded = meResult is Map<String, dynamic>;

    setState(() {
      hubs = results[0] as List<dynamic>;
      rooms = results[1] as List<dynamic>;
      if (selectedHub != null) {
        final refreshed = hubs
            .map((item) => Hub.fromJson(Map<String, dynamic>.from(item as Map)))
            .where((item) => item.id == selectedHub!.id)
            .cast<Hub>()
            .toList();
        if (refreshed.isNotEmpty) selectedHub = refreshed.first;
      }
      if (profileLoaded) {
        profile = meResult;
      }
      loading = false;
      // Authentication/profile failure is the only fatal condition.
      loadError = profileLoaded
          ? null
          : meResult.toString().replaceFirst('ApiException: ', '');
    });
  }

  Hub? get hub => selectedHub;

  void _selectHub(Hub value) {
    setState(() => selectedHub = value);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(), const SizedBox(height: 16),
        Text(t('جارٍ تحميل المجتمع...', 'Loading community...')),
      ])));
    }

    if (loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(t('اتحاد طلبة كلية القانون', 'Law Faculty Student Union'))),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 140),
              const Icon(Icons.cloud_off, size: 56, color: AppColors.neonViolet),
              const SizedBox(height: 18),
              Text(loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Center(child: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(t('إعادة المحاولة', 'Try again')))),
            ],
          ),
        ),
      );
    }

    final current = hub;
    return Scaffold(
      appBar: AppBar(
        title: Text(index == 0
            ? (current == null ? 'السنوات والأقسام' : current.name)
            : index == 1 ? 'ويكي ${current?.name ?? ''}' : 'دردشة ${current?.name ?? ''}'),
        actions: [
          IconButton(
            tooltip: t('الملف الشخصي', 'Profile'),
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      drawer: _buildDrawer(current),
      body: IndexedStack(index: index, children: [
        HubListScreen(onHubSelected: _selectHub),
        current == null ? const Center(child: Text('اختر قسماً أولاً')) : WikiScreen(hubId: current.id),
        _chatList(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dynamic_feed_outlined), selectedIcon: const Icon(Icons.dynamic_feed), label: t('الخلاصة', 'Feed')),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book), label: t('ويكي', 'Wiki')),
          NavigationDestination(icon: const Icon(Icons.chat_bubble_outline), selectedIcon: const Icon(Icons.chat_bubble), label: t('الدردشة', 'Chat')),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildDrawer(Hub? current) {
    final displayName = (profile?['display_name'] ?? '').toString();
    final username = (profile?['username'] ?? '').toString();
    final role = (profile?['role'] ?? '').toString();
    return Drawer(
      child: SafeArea(
        child: ListView(padding: EdgeInsets.zero, children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.surface),
            accountName: Text(displayName.isEmpty ? username : displayName),
            accountEmail: username.isEmpty ? '' : '@$username',
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppColors.primaryPurple,
              child: Text(displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase()),
            ),
          ),
          ListTile(leading: const Icon(Icons.person), title: Text(t('الملف الشخصي', 'Profile')), onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
          }),
          ListTile(leading: const Icon(Icons.groups), title: const Text('السنوات والأقسام'), onTap: () {
            Navigator.pop(context); setState(() => index = 0);
          }),
          ListTile(leading: const Icon(Icons.menu_book), title: Text('الويكي'), onTap: () {
            Navigator.pop(context);
            if (current != null) Navigator.push(context, MaterialPageRoute(builder: (_) => WikiScreen(hubId: current.id)));
          }),
          ListTile(leading: const Icon(Icons.chat), title: const Text('المحادثات'), onTap: () {
            Navigator.pop(context); setState(() => index = 2);
          }),
          ListTile(leading: const Icon(Icons.notifications_none), title: const Text('الإشعارات'), onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          }),
          ListTile(leading: const Icon(Icons.emoji_events), title: Text(t('النقاط والشارات', 'Gamification')), onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
          }),
          if (role == 'agent' || role == 'admin')
            ListTile(leading: const Icon(Icons.shield_outlined), title: Text(t('الإشراف', 'Moderation')), onTap: () {
              Navigator.pop(context); _moderation();
            }),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: Text(t('تسجيل الخروج', 'Sign out')), onTap: () async {
            await api.logout();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }),
        ]),
      ),
    );
  }

  Widget _chatList() {
    final visibleRooms = hub == null
        ? <dynamic>[]
        : rooms.where((item) {
            final room = Map<String, dynamic>.from(item as Map);
            final roomHub = room['hub'];
            if (roomHub is Map) return roomHub['id'].toString() == hub!.id.toString();
            return roomHub?.toString() == hub!.id.toString();
          }).toList();

    if (hub == null) {
      return const Center(child: Text('اختر سنة أو قسماً أولاً'));
    }
    if (visibleRooms.isEmpty) {
      return Center(child: FilledButton.icon(onPressed: _createRoom, icon: const Icon(Icons.add_comment), label: Text(t('إنشاء غرفة دردشة', 'Create chat room'))));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visibleRooms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final room = Map<String, dynamic>.from(visibleRooms[i] as Map);
          return Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.chat)),
            title: Text(room['name']?.toString() ?? t('محادثة', 'Chat')),
            subtitle: Text('${room['participant_count'] ?? 0} ${t('مشارك', 'participants')}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
          ));
        },
      ),
    );
  }

  Future<void> _createRoom() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('غرفة جديدة', 'New room')),
        content: TextField(controller: name, autofocus: true, decoration: InputDecoration(hintText: t('اسم الغرفة', 'Room name'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('إلغاء', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('إنشاء', 'Create'))),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) { name.dispose(); return; }
    try {
      final room = await api.createChatRoom(hubId: hub?.id, name: name.text.trim());
      if (!mounted) return;
      setState(() => rooms = [...rooms, room]);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally { name.dispose(); }
  }

  Future<void> _showCreateMenu(Hub current) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Wrap(runSpacing: 8, children: [
            ListTile(leading: const CircleAvatar(child: Icon(Icons.post_add)), title: Text(t('منشور', 'Post')), subtitle: Text(t('مشاركة نص مع المجتمع', 'Share text with the community')), onTap: () => Navigator.pop(context, 'post')),
            ListTile(leading: const CircleAvatar(child: Icon(Icons.menu_book)), title: Text(t('مقالة', 'Article')), subtitle: Text(t('إنشاء محتوى أطول', 'Create long-form content')), onTap: () => Navigator.pop(context, 'article')),
            ListTile(leading: const CircleAvatar(child: Icon(Icons.poll)), title: Text(t('استطلاع', 'Poll')), subtitle: Text(t('اسأل المجتمع وصوّت', 'Ask the community and vote')), onTap: () => Navigator.pop(context, 'poll')),
            ListTile(leading: const CircleAvatar(child: Icon(Icons.chat)), title: Text(t('دردشة', 'Chat')), subtitle: Text(t('إنشاء غرفة محادثة', 'Create a chat room')), onTap: () => Navigator.pop(context, 'chat')),
          ]),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'chat') { await _createRoom(); return; }
    if (choice == 'post') { await _showPostComposer(current); return; }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(choice == 'article'
        ? t('محرر المقالات سيُفعّل في المرحلة التالية.', 'The article editor is next.')
        : t('نظام الاستطلاعات سيُفعّل في المرحلة التالية.', 'The poll system is next.'))));
  }

  Future<void> _showPostComposer(Hub current) async {
    final controller = TextEditingController();
    final published = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('منشور جديد', 'New post')),
        content: TextField(controller: controller, autofocus: true, minLines: 4, maxLines: 8, decoration: InputDecoration(hintText: t('ماذا تريد أن تشارك؟', 'What do you want to share?'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('إلغاء', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('نشر', 'Publish'))),
        ],
      ),
    );
    final body = controller.text.trim();
    controller.dispose();
    if (published != true || body.isEmpty) return;
    try {
      await api.createPost(current.id, body);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('تم نشر المنشور.', 'Post published.'))));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _moderation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('الإشراف', 'Moderation')),
        content: Text(t(
          'سيتم ربط لوحة الأعضاء والصلاحيات والتقارير مباشرة بواجهات RBAC في الخادم.',
          'The member, permissions and reports dashboard will use the server RBAC APIs.',
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t('إغلاق', 'Close')))],
      ),
    );
  }
}
