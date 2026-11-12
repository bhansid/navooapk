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
          ? const NavooThinking()
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

/// Screen 18 — If/Then, made easy: tap a moment, the action is pre-filled, everything else is optional.
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
  late final thenC = TextEditingController(text: a.thenDo.isNotEmpty ? a.thenDo : _defaultThen());
  late final bIfC = TextEditingController(text: a.backupIf);
  late final bThenC = TextEditingController(text: a.backupThen);
  late final setupC = TextEditingController(text: a.setup);
  bool busy = false;
  String comment = '';
  List<Map<String, String>> ideas = [];
  bool ideasLoading = true;
  late int trigH = a.triggerHour;
  late int trigM = a.triggerMinute;

  @override
  void initState() {
    super.initState();
    Coach.task('ifthen_suggestions', {
      'action': a.title,
      'timing': a.timing,
      'obstacles': s.obstaclesText,
      'routine_and_life': s.coachProfile()['basics'],
      'learned': s.learnings,
    }).then((r) {
      final l = (r?['suggestions'] is List) ? (r!['suggestions'] as List).whereType<Map>().map((m) => {'if': _clean('${m['if'] ?? ''}', 'if'), 'then': _clean('${m['then'] ?? ''}', 'then')}).where((m) => m['if']!.isNotEmpty).take(3).toList() : <Map<String, String>>[];
      if (mounted) setState(() {
        ideas = l;
        ideasLoading = false;
      });
    });
  }

  Future<void> pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: trigH >= 0 ? trigH : 18, minute: trigM), helpText: 'ROUGHLY WHAT TIME IS THAT?');
    if (t != null) setState(() {
      trigH = t.hour;
      trigM = t.minute;
    });
  }

  static const moments = [
    'I finish my morning coffee',
    'I sit down for lunch',
    'I get home from work',
    'I finish dinner',
    'I put the kids to bed',
    'I sit down on the sofa',
  ];

  String _defaultThen() {
    final t = a.title.trim();
    if (t.isEmpty) return '';
    return "I'll ${t[0].toLowerCase()}${t.substring(1)}";
  }

  String _defaultIf() => switch (a.timing) {
        'hour' => 'I finish what I\'m doing now',
        'today' => 'I get a free moment today',
        _ => 'I have a quiet moment in the next few days',
      };

  Future<void> suggest() async {
    setState(() => busy = true);
    final r = await Coach.task('improve_ifthen', {
      'action': a.title,
      'if': ifC.text,
      'then': thenC.text,
      'note': ifC.text.trim().isEmpty ? 'The user has not picked a moment yet. Suggest a realistic one from what you know about them.' : '',
      'obstacles': s.obstaclesText,
    });
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r != null) {
        if ('${r['if'] ?? ''}'.isNotEmpty) ifC.text = _clean('${r['if']}', 'if');
        if ('${r['then'] ?? ''}'.isNotEmpty) thenC.text = _clean('${r['then']}', 'then');
        if ('${r['backup_if'] ?? ''}'.isNotEmpty) bIfC.text = _clean('${r['backup_if']}', 'if');
        if ('${r['backup_then'] ?? ''}'.isNotEmpty) bThenC.text = _clean('${r['backup_then']}', 'then');
        if (setupC.text.trim().isEmpty && '${r['setup'] ?? ''}'.isNotEmpty) setupC.text = '${r['setup']}';
        comment = '${r['comment'] ?? ''}';
      } else {
        comment = "I couldn't reach the coach just now. Pick a moment above and you're set.";
      }
    });
  }

  Future<void> lockIn() async {
    a.ifCue = ifC.text.trim().isEmpty ? _defaultIf() : _clean(ifC.text, 'if');
    a.thenDo = thenC.text.trim().isEmpty ? _defaultThen() : _clean(thenC.text, 'then');
    a.backupIf = _clean(bIfC.text, 'if');
    a.backupThen = _clean(bThenC.text, 'then');
    a.setup = setupC.text.trim();
    a.triggerHour = trigH;
    a.triggerMinute = trigM;
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
    if (x.endsWith('.')) x = x.substring(0, x.length - 1);
    return x;
  }

  Widget _optional(String title, IconData icon, Color tint, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(18)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(icon, color: NC.navy),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: NC.navy, fontSize: 15.5)),
            subtitle: const Text('Optional', style: T.small),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: children,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => NavooScaffold(
        step: widget.fromHome ? null : 5,
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
          const Text('When will you do it?', style: T.h1),
          const SizedBox(height: 8),
          Text('Link "${a.title}" to a moment that already happens in your day. Pick one of my ideas, or write your own.', style: T.sub),
          const SizedBox(height: 16),
          const Text('IDEAS BASED ON WHAT YOU TOLD ME', style: T.label),
          const SizedBox(height: 10),
          if (ideasLoading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 12), Text('Thinking of ideas that fit your day...', style: T.small)]))
          else if (ideas.isNotEmpty)
            for (var k = 0; k < ideas.length; k++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: ifC.text == ideas[k]['if'] ? NC.blueTint : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    key: Key('idea_$k'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() {
                      ifC.text = ideas[k]['if']!;
                      thenC.text = ideas[k]['then']!.isNotEmpty ? ideas[k]['then']! : thenC.text;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        const Icon(Icons.auto_awesome_outlined, color: NC.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text('If ${ideas[k]['if']}, then ${ideas[k]['then']}.', style: const TextStyle(fontSize: 15.5, color: NC.navy, height: 1.35))),
                      ]),
                    ),
                  ),
                ),
              )
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in moments)
                ActionChip(
                  label: Text(m),
                  backgroundColor: NC.blueTint,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle: const TextStyle(color: NC.navy, fontSize: 14.5),
                  onPressed: () => setState(() => ifC.text = m),
                ),
            ]),
          const SizedBox(height: 10),
          const Text('YOUR OWN WORDS (EDIT FREELY)', style: T.label),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: NC.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('IF', style: TextStyle(fontWeight: FontWeight.w700, color: NC.success, letterSpacing: 1.2)),
              TextField(
                key: const Key('if_cue'),
                controller: ifC,
                onChanged: (_) => setState(() {}),
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Pick a moment above or type your own', filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                style: const TextStyle(fontSize: 17, color: NC.navy),
              ),
              const Divider(color: NC.border),
              const Text('THEN', style: TextStyle(fontWeight: FontWeight.w700, color: NC.blue, letterSpacing: 1.2)),
              TextField(
                key: const Key('then_do'),
                controller: thenC,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                style: const TextStyle(fontSize: 17, color: NC.navy),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: NC.border)),
              leading: const Icon(Icons.notifications_active_outlined, color: NC.blue),
              title: Text(trigH >= 0 ? 'Nudge me around ${trigH % 12 == 0 ? 12 : trigH % 12}:${trigM.toString().padLeft(2, '0')} ${trigH < 12 ? 'AM' : 'PM'}' : 'Roughly what time is that?', style: const TextStyle(color: NC.navy, fontWeight: FontWeight.w500)),
              subtitle: const Text('Optional. I\'ll send your own words at that moment.', style: T.small),
              trailing: trigH >= 0 ? IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => trigH = -1)) : const Icon(Icons.chevron_right),
              onTap: pickTime,
            ),
          ),
          const SizedBox(height: 10),
          SoftButton(busy ? 'Thinking...' : 'Tidy it up for me', icon: Icons.auto_awesome_outlined, onPressed: busy ? null : suggest),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
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
          const SizedBox(height: 16),
          _optional('Add a backup option', Icons.sync, NC.warmTint, [
            const Text('For when life gets in the way.', style: T.small),
            const SizedBox(height: 10),
            TextField(controller: bIfC, decoration: const InputDecoration(labelText: 'If...', hintText: 'I run out of time or energy')),
            const SizedBox(height: 10),
            TextField(controller: bThenC, decoration: const InputDecoration(labelText: 'Then...', hintText: 'I\'ll do a 2-minute version')),
          ]),
          _optional('Make it easier around you', Icons.home_outlined, NC.lilacTint, [
            const Text('A small change to your surroundings, like a note on the fridge.', style: T.small),
            const SizedBox(height: 10),
            TextField(controller: setupC, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'e.g. trainers by the door')),
          ]),
          const SizedBox(height: 4),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.science_outlined, color: NC.success, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Linking an action to a moment you already have makes it far easier to remember and do.', style: T.small)),
          ]),
          const SizedBox(height: 16),
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
        SoftButton('Change when I do it', icon: Icons.edit_outlined,
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
              const Text('In your own words.', style: T.sub),
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
