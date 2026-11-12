import 'dart:math';
import 'package:flutter/material.dart';
import '../api.dart';
import '../device.dart';
import '../state.dart';
import '../theme.dart';
import 'shell.dart';
import 'start.dart';

IconData iconFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('recipe') || t.contains('dinner') || t.contains('meal') || t.contains('cook') || t.contains('eat')) return Icons.restaurant;
  if (t.contains('shop') || t.contains('grocer') || t.contains('cart') || t.contains('order') || t.contains('buy')) return Icons.shopping_cart_outlined;
  if (t.contains('walk') || t.contains('move') || t.contains('run') || t.contains('exercise') || t.contains('stretch')) return Icons.directions_walk;
  if (t.contains('sleep') || t.contains('bed')) return Icons.bedtime_outlined;
  if (t.contains('water') || t.contains('drink')) return Icons.water_drop_outlined;
  if (t.contains('prep') || t.contains('prepare')) return Icons.kitchen_outlined;
  return Icons.check_circle_outline;
}

List<MicroAction> fallbackActions(String focus) {
  final f = focus.toLowerCase();
  final id = DateTime.now().microsecondsSinceEpoch;
  if (f.contains('dinner') || f.contains('eat') || f.contains('food') || f.contains('meal') || f.contains('snack')) {
    return [
      MicroAction(id: '${id}1', title: 'Save 3 healthy dinner recipes', description: 'Pick three simple recipes you would enjoy.', why: 'Easy options ready for tired evenings make takeaway less likely.', minutes: 10),
      MicroAction(id: '${id}2', title: "Shop for tomorrow's dinner", description: 'Get the ingredients in-store or online.', why: 'Having the food at home removes the biggest barrier.', minutes: 15),
      MicroAction(id: '${id}3', title: 'Make my first healthy dinner', description: 'Cook one of your saved recipes.', why: 'Doing it once shows you it fits your evening.', minutes: 30),
    ];
  }
  return [
    MicroAction(id: '${id}1', title: 'Take a 10-minute walk', description: 'Any pace, anywhere.', why: 'Short is easier to start and easier to repeat.', minutes: 10),
    MicroAction(id: '${id}2', title: 'Pick your best time of day', description: 'Notice when you usually have more energy.', why: 'Matching the action to your energy makes it stick.', minutes: 5),
    MicroAction(id: '${id}3', title: 'Repeat it at that time', description: 'Same action, at the time that suits you.', why: 'Repeating it at a set time builds a cue.', minutes: 10),
  ];
}

List<MicroAction> parseActions(Map<String, dynamic>? r, String key, int week) {
  final list = (r?[key] is List) ? (r![key] as List) : [];
  final id = DateTime.now().microsecondsSinceEpoch;
  var i = 0;
  return list.whereType<Map>().map((m) {
    i++;
    return MicroAction(
      id: '$id$i',
      title: '${m['title'] ?? ''}',
      description: '${m['description'] ?? ''}',
      why: '${m['why'] ?? ''}',
      minutes: (m['minutes'] is num) ? (m['minutes'] as num).toInt() : 10,
      week: week,
    );
  }).where((a) => a.title.isNotEmpty).take(3).toList();
}

/// Screen 17 — first steps + timing.
class FirstStepsScreen extends StatefulWidget {
  const FirstStepsScreen({super.key});
  @override
  State<FirstStepsScreen> createState() => _FirstStepsScreenState();
}

class _FirstStepsScreenState extends State<FirstStepsScreen> {
  final s = AppState.I;
  bool loading = true;
  String timing = 'hour';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (s.actions.where((a) => a.status != 'done').isEmpty) {
      final r = await Coach.task('actions', {
        'focus': s.focus,
        'obstacles': s.obstaclesText,
        'vision': s.visionHeadline,
        'reward': s.reward,
      });
      var list = parseActions(r, 'actions', s.week);
      if (list.isEmpty) list = fallbackActions(s.focus);
      s.actions.addAll(list);
      s.activateNext();
      await s.save();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _edit(MicroAction a) async {
    final c = TextEditingController(text: a.title);
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NC.bg,
        title: const Text('Change this step', style: T.h3),
        content: TextField(controller: c, autofocus: true, maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (r != null && r.trim().isNotEmpty) {
      setState(() => a.title = r.trim());
      await s.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = s.queue;
    return NavooScaffold(
      step: 5,
      body: loading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Choosing your first steps...', style: T.sub)]))
          : ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
              const NavooLogo(height: 28),
              const SizedBox(height: 16),
              const Text('Your first steps', style: T.h1),
              const SizedBox(height: 8),
              Text('Towards "${s.focus}". We\'ll start with one simple step, then build on it.', style: T.sub),
              const SizedBox(height: 18),
              for (var i = 0; i < q.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: q[i].status == 'active' ? NC.blueTint : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _edit(q[i]),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(color: q[i].status == 'active' ? NC.warmTint : NC.bg, shape: BoxShape.circle),
                            child: Icon(iconFor(q[i].title), color: q[i].status == 'active' ? NC.warning : NC.slate),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(q[i].status == 'active' ? 'STEP ${i + 1}' : 'COMING NEXT', style: T.label),
                              const SizedBox(height: 4),
                              Text(q[i].title, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: q[i].status == 'active' ? NC.navy : NC.slate)),
                              if (q[i].description.isNotEmpty) Text(q[i].description, style: T.small),
                            ]),
                          ),
                          Icon(q[i].status == 'active' ? Icons.edit_outlined : Icons.lock_outline, color: NC.slate, size: 20),
                        ]),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              const Text('Tap a step to change it.', style: T.small),
              const SizedBox(height: 20),
              const Text('When could you realistically do this first step?', style: T.h3),
              const SizedBox(height: 12),
              _timingTile('hour', Icons.schedule, NC.blueTint, NC.blue, 'In the next hour', 'Get it done while it is fresh.'),
              _timingTile('today', Icons.today_outlined, NC.sageTint, NC.success, 'Today', 'Find a time that works for you.'),
              _timingTile('days', Icons.date_range_outlined, NC.lilacTint, const Color(0xFF7A62B8), 'In the next few days', 'No rush. Pick a moment.'),
              const SizedBox(height: 16),
              PrimaryButton("I'll do this",
                  trailingArrow: true,
                  testKey: const Key('steps_continue'),
                  onPressed: () async {
                    final a = s.currentAction;
                    if (a != null) a.timing = timing;
                    await s.save();
                    if (!context.mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const IfThenScreen()));
                  }),
            ]),
    );
  }

  Widget _timingTile(String v, IconData icon, Color tint, Color c, String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: timing == v ? NC.blueTint : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => timing = v),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(timing == v ? Icons.radio_button_checked : Icons.radio_button_off, color: timing == v ? NC.blue : NC.slate),
                const SizedBox(width: 12),
                Container(width: 42, height: 42, decoration: BoxDecoration(color: tint, shape: BoxShape.circle), child: Icon(icon, color: c, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: NC.navy)),
                    Text(sub, style: T.small),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// Screen 18 — If/Then. The user drafts first; the coach only tightens it.
class IfThenScreen extends StatefulWidget {
  final bool fromHome;
  const IfThenScreen({super.key, this.fromHome = false});
  @override
  State<IfThenScreen> createState() => _IfThenScreenState();
}

class _IfThenScreenState extends State<IfThenScreen> {
  final s = AppState.I;
  late final a = s.currentAction!;
  late final ifC = TextEditingController(text: a.ifCue);
  late final thenC = TextEditingController(text: a.thenDo);
  late final bIfC = TextEditingController(text: a.backupIf);
  late final bThenC = TextEditingController(text: a.backupThen);
  late final setupC = TextEditingController(text: a.setup);
  bool busy = false;
  String comment = '';

  Future<void> improve() async {
    if (ifC.text.trim().isEmpty || thenC.text.trim().isEmpty) {
      toast(context, 'Have a go at your own IF and THEN first. I\'ll help tidy it up.');
      return;
    }
    setState(() => busy = true);
    final r = await Coach.task('improve_ifthen', {
      'action': a.title,
      'if': ifC.text,
      'then': thenC.text,
      'backup_if': bIfC.text,
      'backup_then': bThenC.text,
      'setup': setupC.text,
      'obstacles': s.obstaclesText,
    });
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r != null) {
        if ('${r['if'] ?? ''}'.isNotEmpty) ifC.text = '${r['if']}';
        if ('${r['then'] ?? ''}'.isNotEmpty) thenC.text = '${r['then']}';
        if ('${r['backup_if'] ?? ''}'.isNotEmpty) bIfC.text = '${r['backup_if']}';
        if ('${r['backup_then'] ?? ''}'.isNotEmpty) bThenC.text = '${r['backup_then']}';
        if (setupC.text.trim().isEmpty && '${r['setup'] ?? ''}'.isNotEmpty) setupC.text = '${r['setup']}';
        comment = '${r['comment'] ?? ''}';
      } else {
        comment = "I couldn't reach the coach just now, but your plan is saved as you wrote it.";
      }
    });
  }

  Future<void> lockIn() async {
    if (ifC.text.trim().isEmpty || thenC.text.trim().isEmpty) {
      toast(context, 'Add your IF and THEN so we can lock this in.');
      return;
    }
    a.ifCue = _clean(ifC.text, 'if');
    a.thenDo = _clean(thenC.text, 'then');
    a.backupIf = _clean(bIfC.text, 'if');
    a.backupThen = _clean(bThenC.text, 'then');
    a.setup = setupC.text.trim();
    await s.save();
    Coach.task('nudges', {'action': a.title, 'if': a.ifCue, 'then': a.thenDo, 'identity': s.identity}).then((r) {
      final list = (r?['nudges'] is List) ? (r!['nudges'] as List).whereType<Map>().map((m) => {'type': '${m['type']}', 'text': '${m['text']}'}).toList() : <Map<String, String>>[];
      Device.reschedule(nudges: list);
    });
    if (!mounted) return;
    if (widget.fromHome) {
      Navigator.pop(context);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadyScreen()));
    }
  }

  String _clean(String t, String word) {
    var x = t.trim();
    if (x.toLowerCase().startsWith('$word ')) x = x.substring(word.length + 1);
    return x;
  }

  Widget _pair(String title, Color tint, TextEditingController a1, String h1, TextEditingController a2, String h2, {Key? k1, Key? k2}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.label),
          const SizedBox(height: 12),
          _line('IF', a1, h1, k1),
          const SizedBox(height: 10),
          _line('THEN', a2, h2, k2),
        ]),
      );

  Widget _line(String tag, TextEditingController c, String hint, Key? k) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: tag == 'IF' ? NC.sageTint : NC.blueTint, borderRadius: BorderRadius.circular(14)),
          child: Text(tag, style: TextStyle(fontWeight: FontWeight.w700, color: tag == 'IF' ? NC.success : NC.blue)),
        ),
        const SizedBox(width: 10),
        Expanded(child: TextField(key: k, controller: c, minLines: 1, maxLines: 3, decoration: InputDecoration(hintText: hint))),
      ]);

  @override
  Widget build(BuildContext context) => NavooScaffold(
        step: widget.fromHome ? null : 5,
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
          const Text('Plan the moment', style: T.h1),
          const SizedBox(height: 8),
          Text('For "${a.title}". Decide now what you\'ll do when the moment comes, in your own words.', style: T.sub),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: NC.sageTint, borderRadius: BorderRadius.circular(16)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.science_outlined, color: NC.success),
              SizedBox(width: 10),
              Expanded(child: Text('People who decide "if this happens, then I\'ll do that" in advance follow through more often.', style: T.body)),
            ]),
          ),
          const SizedBox(height: 10),
          const Text('Example: IF I finish my morning coffee, THEN I\'ll save 3 healthy recipes.', style: T.small),
          const SizedBox(height: 16),
          _pair('YOUR ACTION PLAN', Colors.white, ifC, 'e.g. I finish my morning coffee', thenC, 'e.g. I\'ll save 3 healthy recipes',
              k1: const Key('if_cue'), k2: const Key('then_do')),
          const SizedBox(height: 12),
          _pair('YOUR BACKUP PLAN (FOR WHEN LIFE GETS IN THE WAY)', NC.warmTint, bIfC, 'e.g. I get distracted or run out of time', bThenC,
              'e.g. I\'ll use my one go-to recipe'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: NC.lilacTint, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SET UP YOUR SURROUNDINGS', style: T.label),
              const SizedBox(height: 6),
              const Text('What could you set up around you to make this easier?', style: T.body),
              const SizedBox(height: 10),
              TextField(controller: setupC, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'e.g. a note on the fridge, recipes app on my home screen')),
            ]),
          ),
          const SizedBox(height: 12),
          if (s.reward.isNotEmpty)
            InfoCard(icon: Icons.card_giftcard, tint: NC.sageTint, iconColor: NC.success, label: 'Straight after, your reward', title: s.reward),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: NC.blueTint, borderRadius: BorderRadius.circular(16)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CoachAvatar(size: 32),
                const SizedBox(width: 10),
                Expanded(child: Text(comment, style: T.body)),
              ]),
            ),
          ],
          const SizedBox(height: 18),
          SoftButton(busy ? 'Thinking...' : 'Help me tighten this', icon: Icons.auto_awesome_outlined, onPressed: busy ? null : improve),
          const SizedBox(height: 12),
          PrimaryButton('Lock this in', trailingArrow: true, onPressed: lockIn, testKey: const Key('ifthen_lock')),
        ]),
      );
}

/// Screen 19 — You're ready.
class ReadyScreen extends StatelessWidget {
  const ReadyScreen({super.key});
  Future<void> _finish(BuildContext context) async {
    final s = AppState.I;
    s.onboarded = true;
    await s.save();
    Device.askNotificationPermission();
    if (context.mounted) goReplaceAll(context, MainShell());
  }

  @override
  Widget build(BuildContext context) {
    final a = AppState.I.currentAction;
    return NavooScaffold(
      step: 5,
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NavooLogo(height: 28),
              SizedBox(height: 18),
              Text("You're ready to get started.", style: T.h1),
              SizedBox(height: 10),
              Text("You've done the thinking. Now it's one small action.", style: T.sub),
            ]),
          ),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/images/hero_ready.jpg', width: 120, height: 190, fit: BoxFit.cover)),
        ]),
        const SizedBox(height: 18),
        const InfoCard(
            icon: Icons.track_changes,
            tint: NC.sageTint,
            iconColor: NC.success,
            title: 'One action at a time.',
            subtitle: "When you complete it, the next one unlocks. If things change, we'll adapt together."),
        const SizedBox(height: 12),
        if (a != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: NC.blueTint, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR NEXT ACTION', style: T.label),
                  const SizedBox(height: 6),
                  Text(a.title, style: T.h2),
                  if (a.description.isNotEmpty) ...[const SizedBox(height: 6), Text(a.description, style: T.small)],
                ]),
              ),
              Container(
                  width: 56, height: 56, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(iconFor(a.title), color: NC.blue)),
            ]),
          ),
        const SizedBox(height: 20),
        PrimaryButton('Go to my home', trailingArrow: true, testKey: const Key('ready_home'), onPressed: () => _finish(context)),
      ]),
    );
  }
}

/// Screen 21 — action detail with the big 3D Done button.
class ActionDetailScreen extends StatelessWidget {
  const ActionDetailScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final a = s.currentAction;
    if (a == null) return const NavooScaffold(body: Center(child: Text('No active action right now.', style: T.sub)));
    return NavooScaffold(
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
        Text(a.title, style: T.h1),
        if (a.description.isNotEmpty) ...[const SizedBox(height: 8), Text(a.description, style: T.sub)],
        const SizedBox(height: 18),
        if (a.why.isNotEmpty) ...[InfoCard(icon: Icons.lightbulb_outline, tint: NC.sageTint, iconColor: NC.success, label: 'Why this matters', title: a.why), const SizedBox(height: 10)],
        if (a.ifCue.isNotEmpty) ...[
          InfoCard(icon: Icons.track_changes, tint: NC.lilacTint, iconColor: const Color(0xFF7A62B8), label: 'Your trigger', title: 'If ${a.ifCue}'),
          const SizedBox(height: 10),
          InfoCard(icon: Icons.bolt, tint: NC.warmTint, iconColor: NC.warning, label: 'Your action', title: 'Then ${a.thenDo}'),
          const SizedBox(height: 10),
        ],
        if (a.backupThen.isNotEmpty) ...[
          InfoCard(icon: Icons.sync, tint: NC.roseTint, iconColor: NC.error, label: 'Your backup', title: 'If ${a.backupIf}, then ${a.backupThen}'),
          const SizedBox(height: 10),
        ],
        if (a.setup.isNotEmpty) ...[InfoCard(icon: Icons.home_outlined, label: 'Your setup', title: a.setup), const SizedBox(height: 10)],
        if (s.reward.isNotEmpty) InfoCard(icon: Icons.card_giftcard, tint: NC.sageTint, iconColor: NC.success, label: 'Your reward', title: s.reward),
        const SizedBox(height: 22),
        PrimaryButton('Done', icon: Icons.check_circle, pressable3d: true, testKey: const Key('detail_done'), onPressed: () => completeAction(context)),
        const SizedBox(height: 12),
        SoftButton('Plan the moment (If/Then)', icon: Icons.edit_outlined,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IfThenScreen(fromHome: true)))),
        const SizedBox(height: 10),
        SoftButton('Talk to Navoo', icon: Icons.chat_bubble_outline, outlined: true, onPressed: () => openCoach(context, preset: "I'm working on: ${a.title}. ")),
      ]),
    );
  }
}

Future<void> completeAction(BuildContext context) async {
  final s = AppState.I;
  final a = s.currentAction;
  if (a == null) return;
  a.status = 'done';
  a.doneAt = DateTime.now();
  s.activateNext();
  await s.save();
  Device.reschedule();
  if (!context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => CelebrationScreen(done: a)));
}

/// Screen 23 — "You did it." with a short confetti burst.
class CelebrationScreen extends StatefulWidget {
  final MicroAction done;
  const CelebrationScreen({super.key, required this.done});
  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  String? feel;
  final rnd = Random(7);
  late final parts = List.generate(70, (i) => _Part(rnd));

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> next() async {
    final s = AppState.I;
    widget.done.feeling = feel;
    await s.save();
    if (!mounted) return;
    if (s.reward.isNotEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RewardClaimScreen()));
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextA = AppState.I.currentAction;
    const faces = [
      ['Hard', Icons.sentiment_very_dissatisfied],
      ['A bit hard', Icons.sentiment_dissatisfied],
      ['Okay', Icons.sentiment_neutral],
      ['Good', Icons.sentiment_satisfied],
      ['Great', Icons.sentiment_very_satisfied],
    ];
    return NavooScaffold(
      back: false,
      body: Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
          SizedBox(height: 170, child: Center(child: Image.asset('assets/images/celebrate.jpg', height: 170))),
          const SizedBox(height: 10),
          const Center(child: Text('You did it.', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: NC.navy))),
          const Center(child: Text('That small step counts.', style: T.sub)),
          const SizedBox(height: 20),
          InfoCard(icon: Icons.check, tint: NC.sageTint, iconColor: NC.success, label: 'Completed', title: widget.done.title, subtitle: 'A small step towards your 30-day focus.'),
          const SizedBox(height: 10),
          if (nextA != null)
            InfoCard(icon: iconFor(nextA.title), tint: NC.warmTint, iconColor: NC.warning, label: 'Next action unlocked', title: nextA.title, subtitle: 'Ready when you are.')
          else
            const InfoCard(icon: Icons.event_note, tint: NC.warmTint, iconColor: NC.warning, label: 'Coming up', title: 'Your weekly check-in', subtitle: "We'll choose your next steps together."),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: NC.lilacTint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('HOW DID THAT FEEL?', style: T.label),
              const SizedBox(height: 12),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: faces
                      .map((f) => GestureDetector(
                            key: Key('feel_${f[0]}'),
                            onTap: () => setState(() => feel = f[0] as String),
                            child: Column(children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: feel == f[0] ? NC.blue : Colors.white,
                                child: Icon(f[1] as IconData, color: feel == f[0] ? Colors.white : NC.slate, size: 30),
                              ),
                              const SizedBox(height: 6),
                              Text(f[0] as String, style: const TextStyle(fontSize: 12.5, color: NC.slate)),
                            ]),
                          ))
                      .toList()),
            ]),
          ),
          const SizedBox(height: 20),
          PrimaryButton('Continue', trailingArrow: true, onPressed: next, testKey: const Key('celebrate_continue')),
          const SizedBox(height: 10),
          SoftButton('Talk to Navoo', icon: Icons.chat_bubble_outline, outlined: true,
              onPressed: () => openCoach(context, preset: 'I just finished "${widget.done.title}". ')),
        ]),
        IgnorePointer(
          child: AnimatedBuilder(animation: c, builder: (_, __) => CustomPaint(size: MediaQuery.of(context).size, painter: _Confetti(parts, c.value))),
        ),
      ]),
    );
  }
}

class _Part {
  final double x, speed, size, drift, spin;
  final Color color;
  _Part(Random r)
      : x = r.nextDouble(),
        speed = 0.6 + r.nextDouble() * 0.8,
        size = 5 + r.nextDouble() * 7,
        drift = (r.nextDouble() - 0.5) * 0.3,
        spin = r.nextDouble() * 6,
        color = [NC.sage, NC.blue, const Color(0xFFF2C14E), NC.success, const Color(0xFF7A62B8)][r.nextInt(5)];
}

class _Confetti extends CustomPainter {
  final List<_Part> parts;
  final double t;
  _Confetti(this.parts, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final p = Paint();
    for (final q in parts) {
      final y = -20 + t * q.speed * size.height * 1.1;
      final x = (q.x + q.drift * t) * size.width;
      p.color = q.color.withValues(alpha: (1 - t).clamp(0.0, 1.0).toDouble());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(q.spin * t * 3);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: q.size, height: q.size * 0.55), const Radius.circular(2)), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _Confetti old) => old.t != t;
}

/// Screen 24 — reward ready.
class RewardClaimScreen extends StatelessWidget {
  const RewardClaimScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return NavooScaffold(
      back: false,
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
        ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/images/reward_tea.jpg', height: 240, width: double.infinity, fit: BoxFit.cover)),
        const SizedBox(height: 22),
        const Center(child: Text('Action complete.', style: T.h1)),
        const SizedBox(height: 6),
        const Center(child: Text('Your reward is ready.', style: TextStyle(fontSize: 22, color: NC.slate))),
        const SizedBox(height: 10),
        Center(child: Text('Go and enjoy it: ${s.reward.toLowerCase()}.', textAlign: TextAlign.center, style: T.sub)),
        const SizedBox(height: 20),
        InfoCard(icon: Icons.card_giftcard, tint: NC.sageTint, iconColor: NC.success, label: 'Your reward', title: s.reward),
        const SizedBox(height: 22),
        PrimaryButton('Claim reward', trailingArrow: true, testKey: const Key('claim_reward'), onPressed: () {
          toast(context, 'Enjoy it. You followed through.');
          Navigator.of(context).popUntil((r) => r.isFirst);
        }),
        const SizedBox(height: 12),
        SoftButton('Change my reward', onPressed: () async {
          final c = TextEditingController(text: s.reward);
          final r = await showDialog<String>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: NC.bg,
              title: const Text('Your reward', style: T.h3),
              content: TextField(controller: c, autofocus: true),
              actions: [FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save'))],
            ),
          );
          if (r != null && r.trim().isNotEmpty) {
            s.reward = r.trim();
            await s.save();
            if (context.mounted) (context as Element).markNeedsBuild();
          }
        }),
      ]),
    );
  }
}

/// Reminder state shown when the app is opened from a nudge.
class NudgeScreen extends StatelessWidget {
  const NudgeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final a = AppState.I.currentAction;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(children: [
            Row(children: [const NavooLogo(height: 26), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
            const Spacer(),
            if (a != null) ...[
              Container(width: 140, height: 140, decoration: const BoxDecoration(color: NC.sageTint, shape: BoxShape.circle), child: Icon(iconFor(a.title), size: 70, color: NC.success)),
              const SizedBox(height: 24),
              Text(a.ifCue.isNotEmpty ? 'If ${a.ifCue}, then ${a.thenDo}.' : a.title, textAlign: TextAlign.center, style: T.h2),
              const SizedBox(height: 10),
              const Text('Your own plan, in your own words.', style: T.sub),
              const SizedBox(height: 22),
              InfoCard(icon: iconFor(a.title), tint: NC.sageTint, iconColor: NC.success, label: 'Your next step', title: a.title, subtitle: 'A small step towards your 30-day focus.'),
            ],
            const Spacer(),
            PrimaryButton('Do it now', trailingArrow: true,
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ActionDetailScreen()))),
            const SizedBox(height: 10),
            SoftButton('Not now', onPressed: () => Navigator.pop(context)),
            LinkText('Change this', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const IfThenScreen(fromHome: true)))),
          ]),
        ),
      ),
    );
  }
}
