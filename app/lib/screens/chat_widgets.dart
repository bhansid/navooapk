import 'package:flutter/material.dart';
import '../theme.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool fromCoach;
  final bool showAvatar;
  const ChatBubble(this.text, {super.key, required this.fromCoach, this.showAvatar = true});
  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: fromCoach ? const Color(0xFFEAF1EE) : NC.blue,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(fromCoach ? 6 : 20),
          bottomRight: Radius.circular(fromCoach ? 20 : 6),
        ),
      ),
      child: Text(text, style: TextStyle(fontSize: 16, height: 1.42, color: fromCoach ? NC.text : Colors.white)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: fromCoach ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (fromCoach) ...[showAvatar ? const CoachAvatar(size: 36) : const SizedBox(width: 36), const SizedBox(width: 8)],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});
  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const CoachAvatar(size: 36),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFFEAF1EE), borderRadius: BorderRadius.circular(18)),
            child: AnimatedBuilder(
              animation: c,
              builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final v = ((c.value * 3 - i) % 3);
                    final o = v < 1 ? 1.0 : 0.35;
                    return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(color: NC.slate.withValues(alpha: o), shape: BoxShape.circle));
                  })),
            ),
          ),
        ]),
      );
}

class QuickChoice {
  final String label;
  final IconData? icon;
  final Color? color;
  const QuickChoice(this.label, {this.icon, this.color});
}

class QuickChoices extends StatelessWidget {
  final List<QuickChoice> choices;
  final ValueChanged<String> onPick;
  final bool grid;
  const QuickChoices(this.choices, {super.key, required this.onPick, this.grid = false});
  @override
  Widget build(BuildContext context) {
    Widget chip(QuickChoice q) => Material(
          color: NC.blueTint,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => onPick(q.label),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(mainAxisSize: grid ? MainAxisSize.max : MainAxisSize.min, children: [
                if (q.icon != null) ...[Icon(q.icon, color: q.color ?? NC.blue, size: 22), const SizedBox(width: 12)],
                Flexible(child: Text(q.label, style: const TextStyle(fontSize: 15.5, color: NC.navy, fontWeight: FontWeight.w500))),
              ]),
            ),
          ),
        );
    if (grid) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.9,
        children: choices.map(chip).toList(),
      );
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: choices.map((q) => Padding(padding: const EdgeInsets.only(bottom: 10), child: chip(q))).toList());
  }
}

class ChatInput extends StatefulWidget {
  final ValueChanged<String> onSend;
  final String hint;
  final bool enabled;
  final TextEditingController? controller;
  const ChatInput({super.key, required this.onSend, this.hint = 'Type a message...', this.enabled = true, this.controller});
  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late final TextEditingController c = widget.controller ?? TextEditingController();
  void send() {
    final t = c.text.trim();
    if (t.isEmpty || !widget.enabled) return;
    c.clear();
    widget.onSend(t);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: NC.border)),
            padding: const EdgeInsets.only(left: 20, right: 6),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('chat_input'),
                  controller: c,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => send(),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: IconButton.filled(
                  key: const Key('chat_send'),
                  tooltip: 'Send',
                  style: IconButton.styleFrom(backgroundColor: NC.blue, fixedSize: const Size(48, 48)),
                  onPressed: widget.enabled ? send : null,
                  icon: const Icon(Icons.arrow_upward, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      );
}
