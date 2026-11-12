import 'package:flutter/material.dart';
import '../api.dart';
import '../state.dart';
import '../theme.dart';
import 'chat_widgets.dart';

/// Screen 22 — the coach. Full conversation with memory.
class CoachScreen extends StatefulWidget {
  final String preset;
  final bool autoSend;
  final bool standalone;
  const CoachScreen({super.key, this.preset = '', this.autoSend = false, this.standalone = false});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final s = AppState.I;
  final scroll = ScrollController();
  late final input = TextEditingController(text: widget.autoSend ? '' : widget.preset);
  bool thinking = false;

  static const quick = ["I'm struggling today", 'I missed yesterday', 'What should I do right now?', 'I completed it', 'Can we change my focus?'];

  @override
  void initState() {
    super.initState();
    if (s.chat.isEmpty) {
      final name = s.firstName.isEmpty ? '' : ' ${s.firstName}';
      s.chat.add(ChatMsg('assistant', 'Hi$name. How are things going right now?'));
      s.save();
    }
    if (widget.autoSend && widget.preset.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => send(widget.preset));
    }
    _jump();
  }

  void _jump() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent + 300, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> send(String text) async {
    if (thinking) return;
    setState(() {
      s.chat.add(ChatMsg('user', text));
      thinking = true;
    });
    _jump();
    final history = s.chat.length > 24 ? s.chat.sublist(s.chat.length - 24) : List<ChatMsg>.from(s.chat);
    final r = await Coach.chat(history);
    if (!mounted) return;
    setState(() {
      thinking = false;
      if (r.failed) {
        s.chat.removeLast();
        input.text = text;
        toast(context, r.reply);
      } else {
        s.chat.add(ChatMsg('assistant', r.reply));
        if (s.personalisedCoaching) s.addLearnings(r.learnings);
      }
    });
    await s.save();
    _jump();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NC.bg,
        title: const Text('Clear this conversation?', style: T.h3),
        content: const Text("Navoo will still remember what it has learned about you. You can manage that in Me → Privacy & AI.", style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => s.chat.clear());
      await s.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
        child: Row(children: [
          if (widget.standalone) IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          const CoachAvatar(size: 46),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Navoo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: NC.navy)),
              Text('Your coach', style: T.small),
            ]),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: NC.navy),
            onSelected: (v) => _clear(),
            itemBuilder: (_) => const [PopupMenuItem(value: 'clear', child: Text('Clear conversation'))],
          ),
        ]),
      ),
      const Divider(height: 1, color: NC.border),
      Expanded(
        child: ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: s.chat.length + (thinking ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= s.chat.length) return const TypingBubble();
            final m = s.chat[i];
            final coach = m.role == 'assistant';
            return ChatBubble(m.text, fromCoach: coach, showAvatar: coach && (i == 0 || s.chat[i - 1].role != 'assistant'));
          },
        ),
      ),
      SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: quick.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ActionChip(
            label: Text(quick[i]),
            backgroundColor: NC.blueTint,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            labelStyle: const TextStyle(color: NC.navy, fontSize: 14),
            onPressed: thinking ? null : () => send(quick[i]),
          ),
        ),
      ),
      ChatInput(onSend: send, enabled: !thinking, controller: input, hint: 'Message Navoo...'),
    ]);
    return widget.standalone ? Scaffold(body: SafeArea(child: body)) : SafeArea(child: body);
  }
}
