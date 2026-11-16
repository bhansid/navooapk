import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
    MicroAction(id: '${id}2', title: 'Pick your best time of day', description: 'Notice when you usually have more energy.', why: 'Matching it to your energy makes it stick.', minutes: 5),
    MicroAction(id: '${id}3', title: 'Repeat it at that time', description: 'Same Micro-Action, at the time that suits you.', why: 'Repeating it at a set time builds a cue.', minutes: 10),
  ];
}

/// B1: change a Micro-Action. Title and description always end up matching: if the user only
/// changes the title, Navoo rewrites the description and "why" to fit the new Micro-Action.
/// Returns true when the title changed.
Future<bool> editMicroAction(BuildContext context, MicroAction a, {void Function(bool busy)? onBusy}) async {
  final s = AppState.I;
  final t = TextEditingController(text: a.title), d = TextEditingController(text: a.description);
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: NC.bg,
      title: const Text('Change this Micro-Action', style: T.h3),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: t, autofocus: true, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Micro-Action')),
          const SizedBox(height: 10),
          TextField(controller: d, maxLines: 4, minLines: 1, decoration: const InputDecoration(labelText: 'Details', helperText: 'Leave as it is and Navoo will update it to match.')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    ),
  );
  final title = t.text.trim();
  if (ok != true || title.isEmpty) return false;
  final changedTitle = title != a.title;
  final descTouched = d.text.trim() != a.description;
  a.title = title;
  a.description = d.text.trim();
  if (changedTitle) {
    a.codesDone = false; // Brain Cheat Codes are re-checked for the new Micro-Action
    a.thenDo = '';
    if (!descTouched || a.description.isEmpty) {
      a.description = '';
      a.why = '';
      onBusy?.call(true);
      final r = await Coach.task('describe_micro_action', {'title': title, 'focus': s.focus, 'vision': s.visionHeadline});
      a.description = '${r?['description'] ?? ''}'.trim();
      a.why = '${r?['why'] ?? ''}'.trim();
      if (r?['minutes'] is num) a.minutes = (r!['minutes'] as num).toInt();
      onBusy?.call(false);
    }
  }
  await s.save();
  return changedTitle;
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
    if (s.queue.isEmpty) {
      final r = await Coach.task('actions', {
        'focus': s.focus,
        'obstacles': s.obstaclesText,
        'vision': s.visionHeadline,
        'all_previous_micro_actions': s.actions.map((a) => a.title).toList(),
      });
      var list = parseActions(r, 'actions', s.week);
      if (list.isEmpty) list = fallbackActions(s.focus);
      s.actions.addAll(list);
      s.activateNext();
      await s.save();
    }
    if (mounted) setState(() => loading = false);
  }

/// B1: edit title and description together; the Micro-Actions after it are rebuilt to follow on.
  Future<void> _edit(MicroAction a) async {
    final changed = await editMicroAction(context, a, onBusy: (b) => setState(() => loading = b));
    if (changed) await _rebuildAfter(a);
    await s.save();
    if (mounted) setState(() {});
  }

  Future<void> _rebuildAfter(MicroAction edited) async {
    final idx = s.actions.indexOf(edited);
    final later = s.actions.skip(idx + 1).where((x) => x.status == 'locked').toList();
    if (later.isEmpty) return;
    setState(() => loading = true);
    final r = await Coach.task('actions', {
      'focus': s.focus,
      'vision': s.visionHeadline,
      'obstacles': s.obstaclesText,
      'fixed_first_micro_actions': s.actions.take(idx + 1).map((x) => x.title).toList(),
      'how_many': later.length,
      'instruction': 'The user changed a Micro-Action. Write the next ${later.length} so they build directly on the fixed ones above.',
    });
    final list = parseActions(r, 'actions', s.week);
    if (list.isNotEmpty) {
      s.actions.removeWhere((x) => later.contains(x));
      s.actions.addAll(list.take(later.length));
    }
    if (mounted) setState(() => loading = false);
  }

  /// P5: a fresh set if these don't fit.
  Future<void> _suggestDifferent() async {
    setState(() => loading = true);
    final previous = s.queue.map((x) => x.title).toList();
    final r = await Coach.task('actions', {
      'focus': s.focus,
      'vision': s.visionHeadline,
      'obstacles': s.obstaclesText,
      'rejected_suggestions': previous,
      'instruction': 'The user wants different Micro-Actions. Do not reuse or reword the rejected ones.',
    });
    final list = parseActions(r, 'actions', s.week);
    if (list.isNotEmpty) {
      s.actions.removeWhere((x) => x.status == 'locked' || x.status == 'active');
      s.actions.addAll(list);
      s.activateNext();
      await s.save();
    } else if (mounted) {
      toast(context, "Couldn't reach the coach. Try again in a moment.");
    }
    if (mounted) setState(() => loading = false);
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
              const Text('Your first Micro-Actions', style: T.h1),
              const SizedBox(height: 8),
              Text('Towards "${s.focus}". We\'ll start with one simple Micro-Action, then build on it.', style: T.sub),
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
                              Text(q[i].status == 'active' ? 'MICRO-ACTION ${i + 1}' : 'COMING NEXT', style: T.label),
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
              const Text('Tap a Micro-Action to change it.', style: T.small),
              const SizedBox(height: 6),
              SoftButton('Suggest different Micro-Actions', icon: Icons.refresh, onPressed: _suggestDifferent),
              const SizedBox(height: 20),
              const Text('When could you realistically do the first one?', style: T.h3),
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

/// Screen 18 — Brain Cheat Codes (C7–C12): If/Then planning (moment + slip-up) and a Physical Nudge,
/// drafted by the user with Navoo's ideas beside each box. Shown for every Micro-Action, with Skip.
class IfThenScreen extends StatefulWidget {
  final bool fromHome;
  final bool unlocked;
  const IfThenScreen({super.key, this.fromHome = false, this.unlocked = false});
  @override
  State<IfThenScreen> createState() => _IfThenScreenState();
}

String cleanIf(String t) {
  var x = t.trim();
  for (final w in ['if ', 'when ', 'whenever ', 'once ']) {
    if (x.toLowerCase().startsWith(w)) x = x.substring(w.length).trim();
  }
  if (x.endsWith(',') || x.endsWith('.')) x = x.substring(0, x.length - 1);
  return x;
}

String cleanThen(String t) {
  var x = t.trim();
  if (x.toLowerCase().startsWith('then ')) x = x.substring(5).trim();
  if (x.endsWith('.')) x = x.substring(0, x.length - 1);
  // C9: always "THEN I will ...".
  final l = x.toLowerCase();
  if (x.isNotEmpty && !l.startsWith('i will') && !l.startsWith("i'll") && !l.startsWith('i ')) x = 'I will ${x[0].toLowerCase()}${x.substring(1)}';
  if (l.startsWith("i'll ")) x = 'I will ${x.substring(5)}';
  return x;
}

/// "IF I …, THEN I will …" with IF and THEN highlighted (C9).
class IfThenLine extends StatelessWidget {
  final String ifText, thenText;
  final double size;
  const IfThenLine(this.ifText, this.thenText, {super.key, this.size = 15.5});
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(style: TextStyle(fontSize: size, color: NC.navy, height: 1.4), children: [
          const TextSpan(text: 'IF ', style: TextStyle(fontWeight: FontWeight.w800, color: NC.success)),
          TextSpan(text: thenText.isEmpty ? ifText : '$ifText, '),
          if (thenText.isNotEmpty) const TextSpan(text: 'THEN ', style: TextStyle(fontWeight: FontWeight.w800, color: NC.blue)),
          if (thenText.isNotEmpty) TextSpan(text: thenText),
        ]),
      );
}

void showBrainScience(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: NC.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 36),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('The science behind Brain Cheat Codes', style: T.h2),
        const SizedBox(height: 14),
        const Text('If/Then planning', style: T.h3),
        const SizedBox(height: 6),
        const Text(
            'Deciding in advance "IF this happens, THEN I will do that" hands the decision to your brain before the moment arrives. This exercise is scientifically proven to make you 2-3 times more likely to complete the action (Gollwitzer and Sheeran, 2006: a meta-analysis of 94 studies).',
            style: T.body),
        const SizedBox(height: 14),
        const Text('Create a Physical Nudge', style: T.h3),
        const SizedBox(height: 6),
        const Text(
            'Small changes to your surroundings make the right choice the easy one: the cue is visible and the effort is lower when you are tired.',
            style: T.body),
        const SizedBox(height: 14),
        LinkText('Read the study (Gollwitzer & Sheeran, 2006)',
            onTap: () => launchUrl(Uri.parse('https://doi.org/10.1016/S0065-2601(06)38002-1'), mode: LaunchMode.externalApplication)),
      ]),
    ),
  );
}

class _IfThenScreenState extends State<IfThenScreen> {
  final s = AppState.I;
  late final a = s.currentAction!;
  late final mIf = TextEditingController(text: a.ifCue);
  late final mThen = TextEditingController(text: a.thenDo.isNotEmpty ? a.thenDo : _defaultThen());
  late final sIf = TextEditingController(text: a.backupIf);
  late final sThen = TextEditingController(text: a.backupThen);
  late final nudge = TextEditingController(text: a.setup);
  late String reward = s.rewardFor(a);
  late int trigH = a.triggerHour;
  late int trigM = a.triggerMinute;
  bool loading = true;
  String error = '';
  List<Map<String, String>> momentIdeas = [], slipIdeas = [];
  List<String> nudgeIdeas = [];

  String _defaultThen() {
    final t = a.title.trim();
    return t.isEmpty ? '' : 'I will ${t[0].toLowerCase()}${t.substring(1)}';
  }

  List<Map<String, String>> _pairs(dynamic l) => (l is List)
      ? l.whereType<Map>().map((m) => {'if': cleanIf('${m['if'] ?? ''}'), 'then': cleanThen('${m['then'] ?? ''}')}).where((m) => m['if']!.isNotEmpty).take(3).toList()
      : <Map<String, String>>[];

  @override
  void initState() {
    super.initState();
    Coach.task('brain_cheat_codes', {
      'micro_action': a.title,
      'description': a.description,
      'timing': a.timing,
      'thirty_day_focus': s.focus,
      'vision': s.visionHeadline,
      'obstacles': s.obstaclesText,
      'rewards_menu': s.rewards,
    }).then((r) {
      if (!mounted) return;
      setState(() {
        loading = false;
        momentIdeas = _pairs(r?['moment_ideas']);
        slipIdeas = _pairs(r?['slip_up_ideas']);
        nudgeIdeas = (r?['nudge_ideas'] is List) ? (r!['nudge_ideas'] as List).map((e) => '$e').where((e) => e.isNotEmpty).take(3).toList() : [];
        final sug = '${r?['reward_suggestion'] ?? ''}';
        if (a.reward.isEmpty && s.rewards.contains(sug)) reward = sug;
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

  Future<void> lockIn() async {
    final missing = <String>[];
    if (mIf.text.trim().isEmpty || mThen.text.trim().isEmpty) missing.add('your moment');
    if (sIf.text.trim().isEmpty || sThen.text.trim().isEmpty) missing.add('your slip-up plan');
    if (nudge.text.trim().isEmpty) missing.add('your Physical Nudge');
    if (missing.isNotEmpty) {
      setState(() => error = 'Add ${missing.join(', ')} to lock this in. Tap one of Navoo\'s ideas if you\'re stuck, or choose "Skip for now".');
      return;
    }
    a.ifCue = cleanIf(mIf.text);
    a.thenDo = cleanThen(mThen.text);
    a.backupIf = cleanIf(sIf.text);
    a.backupThen = cleanThen(sThen.text);
    a.setup = nudge.text.trim();
    a.reward = reward;
    a.triggerHour = trigH;
    a.triggerMinute = trigM;
    a.codesDone = true;
    await s.save();
    Coach.task('nudges', {'action': a.title, 'if': a.ifCue, 'then': a.thenDo, 'identity': s.identity, 'physical_nudge': a.setup}).then((r) {
      final list = (r?['nudges'] is List) ? (r!['nudges'] as List).whereType<Map>().map((m) => {'type': '${m['type']}', 'text': '${m['text']}'}).toList() : <Map<String, String>>[];
      Device.reschedule(nudges: list);
    });
    _leave();
  }

  Future<void> skip() async {
    a.reward = reward;
    await s.save();
    _leave();
  }

  void _leave() {
    if (!mounted) return;
    if (widget.fromHome) {
      Navigator.pop(context);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadyScreen()));
    }
  }

  Widget _explainer(IconData icon, String title, String body) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: NC.sageTint, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: NC.success, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: NC.navy, fontSize: 15.5)),
              const SizedBox(height: 4),
              Text(body, style: T.small),
            ]),
          ),
        ]),
      );

  Widget _box(String tag, TextEditingController c, String hint, Color color, {Key? k}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Text(tag, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: k,
              controller: c,
              minLines: 1,
              maxLines: null, // B3: grows with the answer
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => error = ''),
              decoration: InputDecoration(hintText: hint),
            ),
          ),
        ]),
      );

  Widget _ideas(List<Map<String, String>> list, TextEditingController ifC, TextEditingController thenC, String keyPrefix) {
    if (loading) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Navoo is thinking of ideas...', style: T.small)]));
    }
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('IDEAS FROM NAVOO (TAP TO USE, THEN MAKE IT YOURS)', style: T.label),
      const SizedBox(height: 6),
      for (var k = 0; k < list.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: Key('${keyPrefix}_$k'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() {
                ifC.text = list[k]['if']!;
                if (list[k]['then']!.isNotEmpty) thenC.text = list[k]['then']!;
                error = '';
              }),
              child: Padding(padding: const EdgeInsets.all(12), child: IfThenLine(list[k]['if']!, list[k]['then']!, size: 14.5)),
            ),
          ),
        ),
    ]);
  }

  Widget _section(String label, Color tint, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: T.label), const SizedBox(height: 10), ...children]),
      );

  @override
  Widget build(BuildContext context) => NavooScaffold(
        step: widget.fromHome ? null : 5,
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
          if (widget.unlocked) ...[
            const Text('NEXT MICRO-ACTION UNLOCKED', style: T.label),
            const SizedBox(height: 6),
          ],
          const Text('Your Brain Cheat Codes', style: T.h1),
          const SizedBox(height: 8),
          Text('For "${a.title}".', style: T.sub),
          const SizedBox(height: 14),
          Material(
            color: NC.blueTint,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => showBrainScience(context),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.psychology_outlined, color: NC.blue, size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("The science! Let's plan some brain shortcuts so you don't just rely on willpower.",
                          style: TextStyle(fontWeight: FontWeight.w600, color: NC.navy, fontSize: 16, height: 1.35)),
                      SizedBox(height: 6),
                      Text('See the science', style: TextStyle(color: NC.blue, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('1. If/Then planning', style: T.h2),
          const SizedBox(height: 8),
          _explainer(Icons.science_outlined, 'Why this works',
              'This exercise, called If/Then planning, is scientifically proven to make you 2-3 times more likely to complete the action. Writing it in your own words is part of what makes it work.'),
          const SizedBox(height: 12),
          _section('LINK IT TO A MOMENT IN YOUR DAY', Colors.white, [
            _box('IF', mIf, 'I have finished eating my lunch', NC.success, k: const Key('if_cue')),
            _box('THEN', mThen, 'I will …', NC.blue, k: const Key('then_do')),
            _ideas(momentIdeas, mIf, mThen, 'idea'),
            const SizedBox(height: 4),
            Material(
              color: NC.bg,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: const Icon(Icons.notifications_active_outlined, color: NC.blue),
                title: Text(trigH >= 0 ? 'Nudge me around ${trigH % 12 == 0 ? 12 : trigH % 12}:${trigM.toString().padLeft(2, '0')} ${trigH < 12 ? 'AM' : 'PM'}' : 'Roughly what time is that? (optional)',
                    style: const TextStyle(color: NC.navy, fontWeight: FontWeight.w500)),
                trailing: trigH >= 0 ? IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => trigH = -1)) : const Icon(Icons.chevron_right),
                onTap: pickTime,
              ),
            ),
          ]),
          _section('PLAN FOR A SLIP-UP', NC.warmTint, [
            const Text('What will you do if your motivation drops or the barrier shows up?', style: T.body),
            const SizedBox(height: 10),
            _box('IF', sIf, 'I am too tired when I get home', NC.success, k: const Key('slip_if')),
            _box('THEN', sThen, 'I will remind myself of my Vision', NC.blue, k: const Key('slip_then')),
            _ideas(slipIdeas, sIf, sThen, 'slip'),
          ]),
          const SizedBox(height: 4),
          const Text('2. Create a Physical Nudge', style: T.h2),
          const SizedBox(height: 8),
          _explainer(Icons.home_work_outlined, 'Why this works',
              'This exercise, called Environment Design, works because your surroundings shape what you do, especially when you\'re tired. One small change to your space makes the right choice the easy, visible one.'),
          const SizedBox(height: 12),
          _section('YOUR PHYSICAL NUDGE', NC.lilacTint, [
            TextField(
              key: const Key('nudge'),
              controller: nudge,
              minLines: 1,
              maxLines: null, // B3: grows with the answer
              onChanged: (_) => setState(() => error = ''),
              decoration: const InputDecoration(hintText: 'e.g. leave the ingredients on the worktop before work'),
            ),
            const SizedBox(height: 8),
            if (nudgeIdeas.isNotEmpty) ...[
              const Text('IDEAS FROM NAVOO', style: T.label),
              const SizedBox(height: 6),
              for (var k = 0; k < nudgeIdeas.length; k++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      key: Key('nudge_$k'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() {
                        nudge.text = nudgeIdeas[k];
                        error = '';
                      }),
                      child: Padding(padding: const EdgeInsets.all(12), child: Text(nudgeIdeas[k], style: const TextStyle(color: NC.navy, fontSize: 14.5, height: 1.35))),
                    ),
                  ),
                ),
            ],
          ]),
          if (s.rewards.isNotEmpty)
            _section('YOUR REWARD FOR THIS MICRO-ACTION', NC.sageTint, [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in s.rewards)
                  ChoiceChip(
                    label: Text(r),
                    selected: reward == r,
                    showCheckmark: false,
                    selectedColor: NC.success,
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    labelStyle: TextStyle(color: reward == r ? Colors.white : NC.navy, fontSize: 14),
                    onSelected: (_) => setState(() => reward = r),
                  ),
              ]),
            ]),
          if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error, style: const TextStyle(color: NC.error))),
          PrimaryButton('Lock in my Brain Cheat Codes', trailingArrow: true, onPressed: lockIn, testKey: const Key('ifthen_lock')),
          const SizedBox(height: 6),
          Center(child: LinkText('Skip for now', onTap: skip)),
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
              Text("You've done the thinking. Now it's one small Micro-Action.", style: T.sub),
            ]),
          ),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/images/hero_ready.jpg', width: 120, height: 190, fit: BoxFit.cover)),
        ]),
        const SizedBox(height: 18),
        const InfoCard(
            icon: Icons.track_changes,
            tint: NC.sageTint,
            iconColor: NC.success,
            title: 'One Micro-Action at a time.',
            subtitle: "When you complete it, the next one unlocks. If things change, we'll adapt together."),
        const SizedBox(height: 12),
        if (a != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: NC.blueTint, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR NEXT MICRO-ACTION', style: T.label),
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

Widget _codeCard(String label, String ifT, String thenT, Color tint) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: T.label),
        const SizedBox(height: 6),
        IfThenLine(ifT, thenT, size: 16.5),
      ]),
    );

/// Screen 21 — Micro-Action detail with the big 3D Done button.
class ActionDetailScreen extends StatelessWidget {
  const ActionDetailScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final a = s.currentAction;
    if (a == null) return const NavooScaffold(body: Center(child: Text('No active Micro-Action right now.', style: T.sub)));
    return NavooScaffold(
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
        Text(a.title, style: T.h1),
        if (a.description.isNotEmpty) ...[const SizedBox(height: 8), Text(a.description, style: T.sub)],
        const SizedBox(height: 18),
        if (a.why.isNotEmpty) ...[InfoCard(icon: Icons.lightbulb_outline, tint: NC.sageTint, iconColor: NC.success, label: 'Why this matters', title: a.why), const SizedBox(height: 10)],
        if (a.ifCue.isNotEmpty) ...[
          _codeCard('Your Brain Cheat Code', a.ifCue, a.thenDo, NC.lilacTint),
          const SizedBox(height: 10),
        ],
        if (a.backupThen.isNotEmpty) ...[
          _codeCard('If you slip', a.backupIf, a.backupThen, NC.warmTint),
          const SizedBox(height: 10),
        ],
        if (a.setup.isNotEmpty) ...[InfoCard(icon: Icons.home_work_outlined, label: 'Your Physical Nudge', title: a.setup), const SizedBox(height: 10)],
        if (s.rewardFor(a).isNotEmpty) InfoCard(icon: Icons.card_giftcard, tint: NC.sageTint, iconColor: NC.success, label: 'Your reward', title: s.rewardFor(a)),
        const SizedBox(height: 22),
        PrimaryButton('Done', icon: Icons.check_circle, pressable3d: true, testKey: const Key('detail_done'), onPressed: () => completeAction(context)),
        const SizedBox(height: 12),
        SoftButton(a.codesDone ? 'Edit my Brain Cheat Codes' : 'Set up my Brain Cheat Codes', icon: Icons.psychology_outlined,
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
    Coach.task('insights', {
      'just_completed': widget.done.title,
      'felt': feel,
      'hour_of_day': widget.done.doneAt?.hour,
      'if_then_used': widget.done.ifCue.isEmpty ? null : 'IF ${widget.done.ifCue}, THEN ${widget.done.thenDo}',
      'physical_nudge': widget.done.setup,
    }).then((r) async {
      if (r?['insights'] is List) {
        s.addLearnings((r!['insights'] as List).map((e) => '$e').toList());
        await s.save();
      }
    });
    if (!mounted) return;
    if (s.rewardFor(widget.done).isNotEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RewardClaimScreen(action: widget.done)));
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
      final nextA = s.currentAction;
      if (nextA != null && !nextA.codesDone) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IfThenScreen(fromHome: true, unlocked: true)));
      }
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
          const Center(child: Text('That Micro-Action counts.', style: T.sub)),
          const SizedBox(height: 20),
          InfoCard(icon: Icons.check, tint: NC.sageTint, iconColor: NC.success, label: 'Completed', title: widget.done.title, subtitle: 'One Micro-Action closer to your 30-Day Focus.'),
          const SizedBox(height: 10),
          if (nextA != null)
            InfoCard(icon: iconFor(nextA.title), tint: NC.warmTint, iconColor: NC.warning, label: 'Next Micro-Action unlocked', title: nextA.title, subtitle: 'Ready when you are.')
          else
            const InfoCard(icon: Icons.event_note, tint: NC.warmTint, iconColor: NC.warning, label: 'Coming up', title: 'Your weekly check-in', subtitle: "We'll choose your next Micro-Actions together."),
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

/// Screen 24 — reward ready. B4: easy ways off the page.
class RewardClaimScreen extends StatefulWidget {
  final MicroAction? action;
  const RewardClaimScreen({super.key, this.action});
  @override
  State<RewardClaimScreen> createState() => _RewardClaimScreenState();
}

class _RewardClaimScreenState extends State<RewardClaimScreen> with SingleTickerProviderStateMixin {
  final s = AppState.I;
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  late final parts = List.generate(60, (i) => _Part(Random(11 + i)));
  bool leaving = false;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  /// B4: every choice (claim, well done, skip) gets a confetti burst, then the app moves on.
  Future<void> _next(String msg) async {
    if (leaving) return;
    leaving = true;
    toast(context, msg);
    await c.forward(from: 0);
    if (!mounted) return;
    final nextA = s.currentAction;
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (nextA != null && !nextA.codesDone) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IfThenScreen(fromHome: true, unlocked: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reward = s.rewardFor(widget.action);
    return NavooScaffold(
      back: false,
      body: Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
        ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/images/reward_tea.jpg', height: 220, width: double.infinity, fit: BoxFit.cover)),
        const SizedBox(height: 20),
        const Center(child: Text('Micro-Action complete.', textAlign: TextAlign.center, style: T.h1)),
        const SizedBox(height: 6),
        const Center(child: Text('Your reward is ready.', style: TextStyle(fontSize: 22, color: NC.slate))),
        const SizedBox(height: 18),
        InfoCard(icon: Icons.card_giftcard, tint: NC.sageTint, iconColor: NC.success, label: 'Your reward', title: reward),
        const SizedBox(height: 20),
        PrimaryButton('Claim reward', trailingArrow: true, testKey: const Key('claim_reward'), onPressed: () => _next('Enjoy it. You followed through.')),
        const SizedBox(height: 10),
        SoftButton('Just telling myself well done is enough this time', icon: Icons.favorite_border, onPressed: () => _next('Well done. That counts.')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: SoftButton('Change reward', outlined: true, onPressed: () async {
              final pick = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: NC.bg,
                builder: (_) => SafeArea(
                  child: ListView(shrinkWrap: true, children: [
                    const Padding(padding: EdgeInsets.all(20), child: Text('Choose a reward', style: T.h3)),
                    for (final r in s.rewards) ListTile(leading: const Icon(Icons.card_giftcard, color: NC.success), title: Text(r), onTap: () => Navigator.pop(context, r)),
                  ]),
                ),
              );
              if (pick != null) {
                setState(() => widget.action?.reward = pick);
                await s.save();
              }
            }),
          ),
          const SizedBox(width: 10),
          Expanded(child: SoftButton('Skip', outlined: true, onPressed: () => _next('Nice work.'))),
        ]),
      ]),
        IgnorePointer(
          child: AnimatedBuilder(
              animation: c, builder: (_, __) => c.value == 0 ? const SizedBox.shrink() : CustomPaint(size: MediaQuery.of(context).size, painter: _Confetti(parts, c.value))),
        ),
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
        // Scrolls on small screens or large text instead of overflowing.
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 28),
              child: IntrinsicHeight(
          child: Column(children: [
            Row(children: [const NavooLogo(height: 26), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
            const Spacer(),
            if (a != null) ...[
              Container(width: 140, height: 140, decoration: const BoxDecoration(color: NC.sageTint, shape: BoxShape.circle), child: Icon(iconFor(a.title), size: 70, color: NC.success)),
              const SizedBox(height: 24),
              if (a.ifCue.isNotEmpty) IfThenLine(a.ifCue, a.thenDo, size: 20) else Text(a.title, textAlign: TextAlign.center, style: T.h2),
              const SizedBox(height: 10),
              if (a.ifCue.isNotEmpty) const Text('Your Brain Cheat Code, in your own words.', style: T.sub),
              const SizedBox(height: 22),
              InfoCard(icon: iconFor(a.title), tint: NC.sageTint, iconColor: NC.success, label: 'Your next Micro-Action', title: a.title, subtitle: 'One Micro-Action closer to your 30-Day Focus.'),
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
          ),
        ),
      ),
    );
  }
}
