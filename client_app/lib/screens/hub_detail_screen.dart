import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/hub.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'hub_membership_admin_screen.dart';
import 'wiki_screen.dart';

class HubDetailScreen extends StatefulWidget {
  final Hub hub;
  const HubDetailScreen({super.key, required this.hub});

  @override
  State<HubDetailScreen> createState() => _HubDetailScreenState();
}

class _HubDetailScreenState extends State<HubDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabs;
  late Hub _hub;

  List<dynamic> _posts = [];
  List<dynamic> _rooms = [];
  List<dynamic> _flashcards = [];
  List<dynamic> _polls = [];
  List<dynamic> _quizzes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hub = widget.hub;
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait<dynamic>([
        _api.getPosts(_hub.id),
        _api.getChatRooms(),
        _api.getFlashcards(_hub.id),
        _api.getPolls(_hub.id),
        _api.getQuizzes(_hub.id),
      ]);

      final rooms = (r[1] as List).where((item) {
        final room = Map<String, dynamic>.from(item as Map);
        final h = room['hub'];
        if (h is Map) return h['id'].toString() == _hub.id.toString();
        return h?.toString() == _hub.id.toString();
      }).toList();

      if (!mounted) return;
      setState(() {
        _posts = r[0] as List;
        _rooms = rooms;
        _flashcards = r[2] as List;
        _polls = r[3] as List;
        _quizzes = r[4] as List;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _publishPost() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('منشور جديد'),
        content: TextField(
          controller: c,
          minLines: 4,
          maxLines: 8,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اكتب ما تريد مشاركته مع هذا القسم...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نشر'),
          ),
        ],
      ),
    );

    final body = c.text.trim();
    c.dispose();
    if (ok != true || body.isEmpty) return;

    try {
      await _api.createPost(_hub.id, body);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _commentOnPost(int postId) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة تعليق'),
        content: TextField(
          controller: c,
          minLines: 2,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اكتب تعليقك...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال')),
        ],
      ),
    );
    final body = c.text.trim();
    c.dispose();
    if (ok != true || body.isEmpty) return;
    try {
      await _api.createComment(postId: postId, body: body);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _createPoll() async {
    final body = TextEditingController();
    final question = TextEditingController();
    final options = List.generate(2, (_) => TextEditingController());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setDialog) {
        return AlertDialog(
          title: const Text('استطلاع جديد'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: body, decoration: const InputDecoration(labelText: 'وصف المنشور')),
              TextField(controller: question, decoration: const InputDecoration(labelText: 'السؤال')),
              const SizedBox(height: 8),
              ...options.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextField(controller: e.value, decoration: InputDecoration(labelText: 'الخيار ' + (e.key + 1).toString())),
              )),
              if (options.length < 6)
                TextButton.icon(
                  onPressed: () => setDialog(() => options.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة خيار'),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('نشر')),
          ],
        );
      }),
    );
    final values = options.map((x) => x.text.trim()).where((x) => x.isNotEmpty).toList();
    final b = body.text.trim(), q = question.text.trim();
    for (final x in options) x.dispose();
    body.dispose(); question.dispose();
    if (ok != true || b.isEmpty || q.isEmpty || values.length < 2) return;
    try {
      // The backend currently creates the poll shell; option creation will be wired
      // through the poll management endpoint in the next backend pass.
      await _api.createPoll(hubId: _hub.id, body: b, question: q, options: values);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _createRoom() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('غرفة دردشة جديدة'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم الغرفة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    final name = c.text.trim();
    c.dispose();
    if (ok != true || name.isEmpty) return;

    try {
      final room = await _api.createChatRoom(hubId: _hub.id, name: name);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _createFlashcard() async {
    final front = TextEditingController();
    final back = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('بطاقة تعليمية جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: front,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'السؤال أو الوجه الأمامي',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: back,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'الإجابة أو الوجه الخلفي',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    final f = front.text.trim();
    final b = back.text.trim();
    front.dispose();
    back.dispose();
    if (ok != true || f.isEmpty || b.isEmpty) return;

    try {
      await _api.createFlashcard(
        hubId: _hub.id,
        frontText: f,
        backText: b,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _vote(int optionId) async {
    try {
      await _api.votePoll(optionId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل تصويتك.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
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
        title: Text(_hub.name),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          if (_hub.isHubAdmin)
            IconButton(
              tooltip: 'إدارة القسم',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HubMembershipAdminScreen(hub: _hub),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dynamic_feed), text: 'الخلاصة'),
            Tab(icon: Icon(Icons.menu_book), text: 'الويكي'),
            Tab(icon: Icon(Icons.chat), text: 'الدردشة'),
            Tab(icon: Icon(Icons.school), text: 'الدراسة'),
            Tab(icon: Icon(Icons.poll), text: 'الاستطلاعات'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 180),
                      const Icon(Icons.cloud_off, size: 54),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _feed(),
                    WikiScreen(hubId: _hub.id),
                    _chat(),
                    _study(),
                    _pollsView(),
                  ],
                ),
    );
  }

  Widget _feed() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: [
          _hubHeader(),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.edit)),
              title: const Text('شارك مع القسم'),
              subtitle: const Text('منشور عادي'),
              onTap: _publishPost,
            ))),
            const SizedBox(width: 8),
            Card(child: IconButton(
              tooltip: 'استطلاع جديد',
              onPressed: _createPoll,
              icon: const Icon(Icons.poll),
            )),
          ]),
          const SizedBox(height: 10),
          if (_posts.isEmpty)
            const _EmptyBox(
              icon: Icons.dynamic_feed_outlined,
              text: 'لا توجد منشورات في هذا القسم حتى الآن.',
            )
          else
            ..._posts.map(
              (raw) => _postCard(Map<String, dynamic>.from(raw as Map)),
            ),
        ],
      ),
    );
  }

  Widget _hubHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primaryPurple,
              child: Icon(
                _hub.slug == 'general' ? Icons.public : Icons.school,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hub.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_hub.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(_hub.description),
                    ),
                  const SizedBox(height: 6),
                  Text(_hub.memberCount.toString() + ' عضو'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final poll = post['poll'];
    final quiz = post['quiz'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.person, size: 18),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    post['author_name']?.toString() ?? 'عضو',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (post['is_pinned'] == true)
                  const Icon(Icons.push_pin, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(post['body']?.toString() ?? ''),
            if (poll is Map)
              _pollCard(Map<String, dynamic>.from(poll)),
            if (quiz is Map)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Chip(
                  avatar: const Icon(Icons.quiz, size: 18),
                  label: Text('اختبار: ' + (quiz['title'] ?? '').toString()),
                ),
              ),
            if ((post['comments'] as List?)?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  (post['comments'] as List).length.toString() + ' تعليق',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pollCard(Map<String, dynamic> poll) {
    final options = (poll['options'] as List?) ?? const [];

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              poll['question']?.toString() ?? 'استطلاع',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ...options.map((raw) {
              final option = Map<String, dynamic>.from(raw as Map);
              return ListTile(
                dense: true,
                title: Text(option['text']?.toString() ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.how_to_vote_outlined),
                  onPressed: () => _vote(option['id'] as int),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _chat() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _rooms.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return FilledButton.icon(
              onPressed: _createRoom,
              icon: const Icon(Icons.add),
              label: const Text('غرفة دردشة جديدة'),
            );
          }

          final room = Map<String, dynamic>.from(_rooms[i - 1] as Map);
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.chat)),
              title: Text(room['name']?.toString() ?? 'محادثة'),
              subtitle: Text(
                (room['participant_count'] ?? 0).toString() + ' مشارك',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _study() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _sectionTitle(
            'البطاقات التعليمية',
            'أنشئ بطاقات للمراجعة والحفظ.',
            Icons.style,
            _createFlashcard,
          ),
          if (_flashcards.isEmpty)
            const _EmptyBox(
              icon: Icons.style_outlined,
              text: 'لا توجد بطاقات تعليمية بعد.',
            )
          else
            ..._flashcards.map((raw) {
              final card = Map<String, dynamic>.from(raw as Map);
              return Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.style),
                  title: Text(card['front_text']?.toString() ?? ''),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(card['back_text']?.toString() ?? ''),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 16),
          _sectionTitle(
            'الاختبارات',
            'اختبارات مرتبطة بمحتوى هذا القسم.',
            Icons.quiz,
            null,
          ),
          if (_quizzes.isEmpty)
            const _EmptyBox(
              icon: Icons.quiz_outlined,
              text: 'لا توجد اختبارات منشورة في هذا القسم بعد.',
            )
          else
            ..._quizzes.map((raw) {
              final q = Map<String, dynamic>.from(raw as Map);
              final questions = (q['questions'] as List?) ?? const [];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.quiz),
                  title: Text(q['title']?.toString() ?? 'اختبار'),
                  subtitle: Text(questions.length.toString() + ' سؤال'),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _pollsView() {
    if (_polls.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            _EmptyBox(
              icon: Icons.poll_outlined,
              text: 'لا توجد استطلاعات في هذا القسم حالياً.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: _polls.map((raw) {
          final poll = Map<String, dynamic>.from(raw as Map);
          final options = (poll['options'] as List?) ?? const [];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poll['question']?.toString() ?? 'استطلاع',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...options.map((rawOption) {
                    final option =
                        Map<String, dynamic>.from(rawOption as Map);
                    return ListTile(
                      title: Text(option['text']?.toString() ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.how_to_vote),
                        onPressed: () => _vote(option['id'] as int),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? action,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryPurple),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: action == null
            ? null
            : IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: action,
              ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.neonViolet),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
