import 'package:flutter/material.dart';
import '../api.dart';
import '../device.dart';
import '../state.dart';
import '../theme.dart';
import 'actions.dart';
import 'shell.dart';

Map<String, dynamic> weekData() {
  final s = AppState.I;
  final since = s.lastReview ?? s.focusStart ?? DateTime.now().subtract(const Duration(days: 7));
  return {
    'focus': s.focus,
    'week': s.week,
    'completed': s.done.where((a) => a.doneAt != null && a.doneAt!.isAfter(since)).map((a) => {'title': a.title, 'felt': a.feeling, 'if': a.ifCue, 'then': a.thenDo, 'done_at': a.doneAt!.toIso8601String()}).toList(),
    'not_done': s.actions.where((a) => a.status != 'done').map((a) => {'title': a.title, 'status': a.status, 'if': a.ifCue}).toList(),
    'obstacles': s.obstaclesText,
    'learned_before': s.learnings,
  };
}

/// Screen 26a — weekly review intro.
class WeeklyReviewIntro extends StatelessWidget {
  const WeeklyReviewIntro({super.key});
  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
          Center(child: Image.asset('assets/images/weekly.jpg', height: 220)),
          const SizedBox(height: 18),
          const Text("Let's see how your week went.", textAlign: TextAlign.center, style: T.h1),
          const SizedBox(height: 10),
          const Text('A quick look at what worked, what got in the way, and what to try next. Slip-ups are useful information here, not failures.',
              textAlign: TextAlign.center, style: T.sub),
          const SizedBox(height: 20),
          const InfoCard(icon: Icons.bar_chart_rounded, tint: NC.sageTint, iconColor: NC.success, label: 'What went well', title: 'Notice what helped.'),
          const SizedBox(height: 10),
          const InfoCard(icon: Icons.lightbulb_outline, tint: NC.warmTint, iconColor: NC.warning, label: 'What felt hard', title: 'Spot what got in the way.'),
          const SizedBox(height: 10),
          const InfoCard(icon: Icons.sync, tint: NC.lilacTint, iconColor: Color(0xFF7A62B8), label: 'What to try next', title: 'Choose one small adjustment.'),
          const SizedBox(height: 22),
          PrimaryButton('See my week', trailingArrow: true, testKey: const Key('review_start'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatWorkedScreen()))),
        ]),
      );
}

/// Screen 26b — what worked.
class WhatWorkedScreen extends StatefulWidget {
  const WhatWorkedScreen({super.key});
  @override
  State<WhatWorkedScreen> createState() => _WhatWorkedScreenState();
}

class _WhatWorkedScreenState extends State<WhatWorkedScreen> {
  Map<String, dynamic>? r;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    Coach.task('weekly_review', weekData()).then((v) {
      if (mounted) setState(() {
        r = v;
        loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final went = (r?['went_well'] is List) ? (r!['went_well'] as List).whereType<Map>().toList() : <Map>[];
    final noticed = (r?['noticed'] is List) ? (r!['noticed'] as List).map((e) => '$e').toList() : <String>[];
    return NavooScaffold(
      body: loading
          ? const NavooThinking(lines: ['Looking at your week...', 'Noticing what helped...', 'Spotting patterns...'])
          : ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
              const Text('WEEKLY REVIEW', style: T.label),
              const SizedBox(height: 6),
              const Text('What worked this week?', style: T.h1),
              const SizedBox(height: 8),
              const Text("Let's start with what went well. It tells us what to keep.", style: T.sub),
              const SizedBox(height: 18),
              if (went.isEmpty && s.done.isEmpty)
                const InfoCard(icon: Icons.spa_outlined, tint: NC.sageTint, iconColor: NC.success, title: 'A quiet week', subtitle: "That's okay. We'll work from where you are now.")
              else ...[
                const Text('You did well with:', style: T.h3),
                const SizedBox(height: 10),
                if (went.isEmpty)
                  ...s.done.reversed.take(3).map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InfoCard(icon: Icons.check, tint: NC.sageTint, iconColor: NC.success, title: a.title)))
                else
                  ...went.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InfoCard(icon: Icons.wb_sunny_outlined, tint: NC.sageTint, iconColor: NC.success, title: '${w['title']}', subtitle: '${w['detail'] ?? ''}'))),
              ],
              if (noticed.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Navoo noticed:', style: T.h3),
                const SizedBox(height: 10),
                ...noticed.map((n) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InfoCard(icon: Icons.insights, title: n))),
              ],
              const SizedBox(height: 14),
              PrimaryButton('Continue', trailingArrow: true, testKey: const Key('worked_continue'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InTheWayScreen(review: r)))),
            ]),
    );
  }
}

/// Screen 26c — what got in the way.
class InTheWayScreen extends StatefulWidget {
  final Map<String, dynamic>? review;
  const InTheWayScreen({super.key, this.review});
  @override
  State<InTheWayScreen> createState() => _InTheWayScreenState();
}

class _InTheWayScreenState extends State<InTheWayScreen> {
  final c = TextEditingController();
  final factors = <String>{};
  static const all = ['Energy', 'Time', 'Environment', 'Emotional trigger', 'Preparation', 'Motivation'];
  static const icons = [Icons.bolt, Icons.schedule, Icons.home_work_outlined, Icons.favorite_border, Icons.description_outlined, Icons.track_changes];

  @override
  void initState() {
    super.initState();
    final f = widget.review?['factors'];
    if (f is List) factors.addAll(f.map((e) => '$e').where(all.contains));
  }

  @override
  Widget build(BuildContext context) {
    final learned = (widget.review?['learned'] is List) ? (widget.review!['learned'] as List).map((e) => '$e').toList() : <String>[];
    return NavooScaffold(
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
        const Text('WEEKLY REVIEW', style: T.label),
        const SizedBox(height: 6),
        const Text('What got in the way?', style: T.h1),
        const SizedBox(height: 8),
        const Text("Let's look at the harder moments. They show us what to change.", style: T.sub),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: NC.blueTint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(18)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CoachAvatar(size: 36),
            SizedBox(width: 12),
            Expanded(child: Text('Was there a moment this week when things didn\'t go the way you hoped? What happened?', style: T.body)),
          ]),
        ),
        const SizedBox(height: 12),
        TextField(key: const Key('review_inway'), controller: c, minLines: 2, maxLines: 5, decoration: const InputDecoration(hintText: 'e.g. I got home exhausted on Wednesday and ordered takeaway')),
        const SizedBox(height: 16),
        const Text('LIKELY FACTORS', style: T.label),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < all.length; i++)
            FilterChip(
              avatar: Icon(icons[i], size: 18, color: factors.contains(all[i]) ? NC.error : NC.slate),
              label: Text(all[i]),
              selected: factors.contains(all[i]),
              showCheckmark: false,
              selectedColor: NC.roseTint,
              backgroundColor: Colors.white,
              side: const BorderSide(color: NC.border),
              shape: const StadiumBorder(),
              onSelected: (v) => setState(() => v ? factors.add(all[i]) : factors.remove(all[i])),
            ),
        ]),
        if (learned.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('What we learned', style: T.h3),
          const SizedBox(height: 10),
          ...learned.map((l) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InfoCard(icon: Icons.lightbulb_outline, tint: NC.warmTint, iconColor: NC.warning, title: l))),
        ],
        const SizedBox(height: 16),
        PrimaryButton('Continue', trailingArrow: true, testKey: const Key('inway_continue'), onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => NextWeekScreen(said: c.text.trim(), factors: factors.toList())));
        }),
      ]),
    );
  }
}

/// Screen 26d — change the approach, not the goal.
class NextWeekScreen extends StatefulWidget {
  final String said;
  final List<String> factors;
  const NextWeekScreen({super.key, required this.said, required this.factors});
  @override
  State<NextWeekScreen> createState() => _NextWeekScreenState();
}

class _NextWeekScreenState extends State<NextWeekScreen> {
  final s = AppState.I;
  bool loading = true;
  String headline = '';
  List<MicroAction> next = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Coach.task('weekly_review', {...weekData(), 'user_said_got_in_the_way': widget.said, 'factors_chosen': widget.factors});
    headline = '${r?['headline_learning'] ?? ''}';
    final learned = (r?['learned'] is List) ? (r!['learned'] as List).map((e) => '$e').toList() : <String>[];
    s.addLearnings(learned);
    next = parseActions(r, 'next_actions', s.week + 1);
    if (next.isEmpty) next = fallbackActions(s.focus).map((a) => a..week = s.week + 1).toList();
    if (headline.isEmpty) headline = widget.said.isEmpty ? 'Keep what worked, and make the next steps a little easier.' : 'We\'ll design around what got in the way.';
    if (mounted) setState(() => loading = false);
  }

  Future<void> accept() async {
    s.actions.removeWhere((a) => a.status != 'done');
    s.week += 1;
    for (final a in next) {
      a.week = s.week;
      a.status = 'locked';
    }
    s.actions.addAll(next);
    s.activateNext();
    s.lastReview = DateTime.now();
    await s.save();
    Device.reschedule();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    toast(context, 'Your next steps are ready.');
  }

  Future<void> edit(int i) async {
    final c = TextEditingController(text: next[i].title);
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NC.bg,
        title: const Text('Change this step', style: T.h3),
        content: TextField(controller: c, autofocus: true),
        actions: [FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save'))],
      ),
    );
    if (r != null && r.trim().isNotEmpty) setState(() => next[i].title = r.trim());
  }

  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: loading
            ? const NavooThinking(lines: ['Learning from this week...', 'Adjusting the approach, not the goal...', 'Choosing your next small steps...'])
            : ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
                const Text('NEXT WEEK', style: T.label),
                const SizedBox(height: 6),
                const Text("Let's change the approach, not the goal.", style: T.h1),
                const SizedBox(height: 8),
                const Text('Same goal. A different approach.', style: T.sub),
                const SizedBox(height: 14),
                ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/images/meal_prep.jpg', height: 150, width: double.infinity, fit: BoxFit.cover)),
                const SizedBox(height: 14),
                InfoCard(icon: Icons.lightbulb_outline, tint: NC.roseTint, iconColor: NC.error, label: 'What we learned', title: headline),
                const SizedBox(height: 18),
                const Text('YOUR NEXT ACTIONS', style: T.label),
                const SizedBox(height: 10),
                for (var i = 0; i < next.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InfoCard(
                      icon: iconFor(next[i].title),
                      tint: [NC.sageTint, NC.warmTint, NC.lilacTint][i % 3],
                      iconColor: [NC.success, NC.warning, const Color(0xFF7A62B8)][i % 3],
                      label: '${i + 1}',
                      title: next[i].title,
                      subtitle: next[i].description,
                      trailing: const Icon(Icons.edit_outlined, color: NC.slate, size: 20),
                      onTap: () => edit(i),
                    ),
                  ),
                const SizedBox(height: 10),
                PrimaryButton('Looks good', trailingArrow: true, onPressed: accept, testKey: const Key('nextweek_accept')),
                const SizedBox(height: 10),
                SoftButton('Change these', onPressed: () => edit(0)),
                const SizedBox(height: 10),
                SoftButton('Ask Navoo', icon: Icons.chat_bubble_outline, outlined: true,
                    onPressed: () => openCoach(context, preset: 'For next week, I\'d like to change my steps. ')),
              ]),
      );
}

/// Screen 27 — 30 days complete.
class FocusCompleteScreen extends StatefulWidget {
  const FocusCompleteScreen({super.key});
  @override
  State<FocusCompleteScreen> createState() => _FocusCompleteScreenState();
}

class _FocusCompleteScreenState extends State<FocusCompleteScreen> {
  final s = AppState.I;
  bool loading = true;
  String summary = '';
  List<Map<String, String>> options = [];
  String? satisfied;

  @override
  void initState() {
    super.initState();
    Coach.task('completion', {...weekData(), 'vision': s.visionHeadline, 'all_completed': s.done.map((a) => a.title).toList()}).then((r) {
      summary = '${r?['summary'] ?? ''}';
      options = (r?['options'] is List)
          ? (r!['options'] as List).whereType<Map>().map((m) => {'title': '${m['title']}', 'why': '${m['why'] ?? ''}'}).take(3).toList()
          : [];
      if (mounted) setState(() => loading = false);
    });
  }

  Future<void> choose(String focus) async {
    if (satisfied != null) Coach.feedback({'satisfaction': satisfied, 'focus': s.focus, 'actions_done': s.done.length});
    s.satisfaction = satisfied;
    s.focus = focus;
    s.focusStart = DateTime.now();
    s.actions.removeWhere((a) => a.status != 'done');
    s.lastReview = DateTime.now();
    await s.save();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FirstStepsScreen()));
  }

  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
          Center(child: Image.asset('assets/images/celebrate.jpg', height: 150)),
          const Center(child: Text('You did it.', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: NC.navy))),
          const SizedBox(height: 6),
          Center(child: Text('30 days of "${s.focus}".', textAlign: TextAlign.center, style: T.sub)),
          const SizedBox(height: 16),
          InfoCard(icon: Icons.check_circle_outline, tint: NC.sageTint, iconColor: NC.success, label: 'Completed', title: '${s.done.length} actions'),
          if (summary.isNotEmpty) ...[const SizedBox(height: 10), InfoCard(icon: Icons.lightbulb_outline, tint: NC.warmTint, iconColor: NC.warning, label: 'What helped', title: summary)],
          const SizedBox(height: 18),
          const Text('How satisfied are you with your progress towards your goal?', style: T.h3),
          const SizedBox(height: 10),
          Row(children: [
            for (final o in ['Not satisfied', 'Satisfied', 'Very satisfied'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(o, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                    selected: satisfied == o,
                    showCheckmark: false,
                    selectedColor: NC.blueTint,
                    onSelected: (_) => setState(() => satisfied = o),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 22),
          Text('Your next 30-day focus, under the same vision: ${s.visionHeadline}', style: T.h3),
          const SizedBox(height: 10),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else ...[
            for (final o in options)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InfoCard(icon: Icons.track_changes, title: o['title']!, subtitle: o['why'], onTap: () => choose(o['title']!))),
            SoftButton('Keep my current focus', onPressed: () => choose(s.focus)),
            const SizedBox(height: 10),
            SoftButton('Suggest my own', outlined: true, onPressed: () async {
              final c = TextEditingController();
              final r = await showDialog<String>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: NC.bg,
                  title: const Text('Your next focus', style: T.h3),
                  content: TextField(controller: c, autofocus: true, maxLines: 2),
                  actions: [FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Use this'))],
                ),
              );
              if (r != null && r.trim().isNotEmpty) choose(r.trim());
            }),
          ],
        ]),
      );
}
