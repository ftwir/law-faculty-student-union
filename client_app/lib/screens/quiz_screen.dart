import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';

class QuizScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;
  const QuizScreen({super.key, required this.quiz});
  @override State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final ApiClient _api = ApiClient();
  late final List<dynamic> _questions;
  late final List<int?> _answers;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _questions = (widget.quiz['questions'] as List?) ?? const [];
    _answers = List<int?>.filled(_questions.length, null);
  }

  Future<void> _submit() async {
    if (_questions.isEmpty || _answers.any((answer) => answer == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أجب عن جميع الأسئلة أولاً.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await _api.attemptQuiz(
        quizId: widget.quiz['id'] as int,
        answers: _answers.cast<int>(),
      );
      if (!mounted) return;
      final score = result['score'] ?? 0;
      final total = result['total'] ?? _questions.length;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('نتيجة الاختبار'),
          content: Text(
            'حصلت على ' + score.toString() + ' من ' + total.toString() + '.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تم'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz['title']?.toString() ?? 'اختبار'),
      ),
      body: _questions.isEmpty
          ? const Center(child: Text('هذا الاختبار لا يحتوي على أسئلة.'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryPurple,
                          child: Icon(Icons.quiz, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'أجب عن جميع الأسئلة ثم أرسل الاختبار.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question =
                      Map<String, dynamic>.from(entry.value as Map);
                  final options = (question['options'] as List?) ?? const [];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (index + 1).toString() +
                                '. ' +
                                (question['prompt'] ?? '').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...options.asMap().entries.map(
                            (optionEntry) => RadioListTile<int>(
                              value: optionEntry.key,
                              groupValue: _answers[index],
                              title: Text(optionEntry.value.toString()),
                              onChanged: _submitting
                                  ? null
                                  : (value) => setState(
                                        () => _answers[index] = value,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('إرسال الإجابات'),
                ),
              ],
            ),
    );
  }
}
