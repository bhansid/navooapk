import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../api.dart';
import '../device.dart';
import '../state.dart';
import '../theme.dart';
import 'actions.dart';
import 'coach.dart';
import 'me.dart';
import 'progress.dart';
import 'review.dart';
import 'vision.dart';

final shellKey = GlobalKey<_MainShellState>();

void openCoach(BuildContext context, {String preset = '', bool send = false}) {
  // R7/R17: from inside a flow, open the coach on top so Back returns to the same place.
  if (Navigator.of(context).canPop()) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CoachScreen(standalone: true, preset: preset, autoSend: send)));
    return;
  }
  final st = shellKey.currentState;
  if (st != null && st.mounted) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    st.openCoach(preset: preset, send: send);
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CoachScreen(standalone: true, preset: preset, autoSend: send)));
  }
}

class MainShell extends StatefulWidget {
  MainShell({Key? key}) : super(key: key ?? shellKey);
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  String preset = '';
  bool autoSend = false;
  int coachNonce = 0;

  void openCoach({String preset = '', bool send = false}) => setState(() {
        tab = 1;
        this.preset = preset;
        autoSend = send;
        coachNonce++;
      });

  @override
  void initState() {
    super.initState();
    Device.reschedule();
    _launchedFromNudge();
  }

  Future<void> _launchedFromNudge() async {
    try {
      final d = await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp == true && AppState.I.currentAction != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NudgeScreen()));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(onCoach: openCoach),
      CoachScreen(key: ValueKey('coach$coachNonce'), preset: preset, autoSend: autoSend),
      const ProgressTab(),
      const MeTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: Colors.white,
        indicatorColor: NC.blueTint,
        onDestinationSelected: (i) => setState(() {
          tab = i;
          if (i != 1) preset = '';
        }),
        destinations: const [
          NavigationDestination(key: Key('tab_home'), icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: NC.blue), label: 'Home'),
          NavigationDestination(key: Key('tab_coach'), icon: CoachTabIcon(), selectedIcon: CoachTabIcon(selected: true), label: 'Coach'),
          NavigationDestination(key: Key('tab_progress'), icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart, color: NC.blue), label: 'Progress'),
          NavigationDestination(key: Key('tab_me'), icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: NC.blue), label: 'Me'),
        ],
      ),
    );
  }
}

/// Screen 20 — Home. Answers one question: what should I do right now?
class HomeTab extends StatefulWidget {
  final void Function({String preset, bool send}) onCoach;
  const HomeTab({super.key, required this.onCoach});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final s = AppState.I;
  bool adding = false;

  @override
  void initState() {
    super.initState();
    s.addListener(_changed);
    _loadTip();
  }

  @override
  void dispose() {
    s.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTip() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (s.dailyTipDate == today && s.dailyTip.isNotEmpty) return;
    final r = await Coach.task('daily_tip', {'current_action': s.currentAction?.title, 'focus': s.focus, 'day_of_focus': s.focusDay});
    final t = '${r?['text'] ?? ''}';
    if (t.isNotEmpty) {
      s.dailyTip = t;
      s.dailyTipDate = today;
      await s.save();
    }
  }

  String get greeting {
    final h = DateTime.now().hour;
    final part = h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
    return s.firstName.isEmpty ? part : '$part, ${s.firstName}';
  }

  bool get reviewDue {
    if (!s.onboarded) return false;
    final now = DateTime.now();
    final since = s.lastReview ?? s.focusStart ?? now;
    final days = now.difference(since).inDays;
    return days >= 6 || (now.weekday == s.reviewWeekday && days >= 1) || (s.currentAction == null && s.actions.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final a = s.currentAction;
    final week = ((s.focusDay - 1) ~/ 7 + 1).clamp(1, 5);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          s.dailyTipDate = '';
          await _loadTip();
        },
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 28), children: [
          Row(children: [
            const NavooLogo(height: 40),
            const Spacer(),
            IconButton(
                tooltip: 'Nudges',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NudgeSettingsScreen())),
                icon: const Icon(Icons.notifications_none, color: NC.navy)),
          ]),
          const SizedBox(height: 14),
          Text(greeting, style: T.h1),
          const SizedBox(height: 18),
          if (s.focusComplete)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InfoCard(
                  icon: Icons.emoji_events_outlined,
                  tint: NC.sageTint,
                  iconColor: NC.success,
                  label: '30 days complete',
                  title: 'Look back and choose your next focus',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusCompleteScreen()))),
            )
          else if (s.reviewDraft.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InfoCard(
                  icon: Icons.event_note,
                  tint: NC.warmTint,
                  iconColor: NC.warning,
                  label: 'Your weekly check-in',
                  title: 'Continue your check-in',
                  subtitle: "Pick up where you left off. Your answers are saved.",
                  onTap: () => resumeReview(context)),
            )
          else if (reviewDue)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InfoCard(
                  icon: Icons.event_note,
                  tint: NC.warmTint,
                  iconColor: NC.warning,
                  label: 'Your weekly check-in',
                  title: "Let's see how your week went",
                  subtitle: '10 minutes. What worked, what got in the way, what to adjust.',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyReviewIntro()))),
            ),
          // Your focus right now
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: NC.border)),
            child: a == null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('YOUR FOCUS RIGHT NOW', style: T.label),
                    const SizedBox(height: 8),
                    const Text("You've completed this week's Micro-Actions.", style: T.h2),
                    const SizedBox(height: 8),
                    const Text("Want to keep going this week? Add more, or do your check-in and we'll choose next week's together.", style: T.sub),
                    const SizedBox(height: 16),
                    PrimaryButton(adding ? 'Choosing...' : 'Add more Micro-Actions', icon: Icons.add, busy: adding, onPressed: () async {
                      setState(() => adding = true);
                      final list = await suggestMoreMicroActions();
                      if (!mounted) return;
                      setState(() => adding = false);
                      if (list.isEmpty) {
                        toast(context, "Couldn't reach the coach. Try again in a moment.");
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmMicroActionsScreen(suggested: list)));
                      }
                    }),
                    const SizedBox(height: 10),
                    SoftButton('Start my check-in', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyReviewIntro()))),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('YOUR MICRO-ACTION RIGHT NOW', style: T.label),
                          const SizedBox(height: 8),
                          Text(a.title, key: const Key('home_action_title'), style: T.h2),
                          const SizedBox(height: 6),
                          if (a.ifCue.isNotEmpty) IfThenLine(a.ifCue, a.thenDo, size: 14) else const Text('One small Micro-Action towards your 30-Day Focus.', style: T.small),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                              switch (iconFor(a.title)) {
                                Icons.restaurant => 'assets/images/food_bowl.jpg',
                                Icons.kitchen_outlined || Icons.shopping_cart_outlined => 'assets/images/meal_prep.jpg',
                                _ => 'assets/images/vision_3.jpg',
                              },
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover)),
                    ]),
                    const SizedBox(height: 16),
                    PrimaryButton('Do it now',
                        trailingArrow: true,
                        testKey: const Key('home_do_it'),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActionDetailScreen()))),
                    const SizedBox(height: 10),
                    PrimaryButton('Done', icon: Icons.check_circle, pressable3d: true, testKey: const Key('home_done'), onPressed: () => completeAction(context)),
                    if (!a.codesDone) ...[
                      const SizedBox(height: 10),
                      SoftButton('Set up my Brain Cheat Codes', icon: Icons.psychology_outlined,
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IfThenScreen(fromHome: true)))),
                    ],
                  ]),
          ),
          if (a != null) ...[
            const SizedBox(height: 14),
            _AdaptCard(onPick: (msg, send) => widget.onCoach(preset: msg, send: send), title: a.title),
          ],
          if (s.queue.length > 1) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: NC.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text("THIS WEEK'S MICRO-ACTIONS", style: T.label)),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen())), child: const Text('See & edit')),
                ]),
                for (final q in s.queue.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(q.status == 'active' ? Icons.radio_button_checked : Icons.lock_outline, size: 20, color: q.status == 'active' ? NC.blue : NC.slate),
                      const SizedBox(width: 12),
                      Expanded(child: Text(q.title, style: TextStyle(fontSize: 15.5, color: q.status == 'active' ? NC.navy : NC.slate, fontWeight: q.status == 'active' ? FontWeight.w600 : FontWeight.w400))),
                      if (q.status != 'active') const Text('Coming next', style: T.small),
                    ]),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          CoachSignpost(onTap: () => widget.onCoach(preset: "I'm struggling with my 30-Day Focus. ", send: false)),
          const SizedBox(height: 14),
          // Daily coach slot
          Material(
            color: NC.blueTint,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () async {
                final tip = s.dailyTip.isNotEmpty ? s.dailyTip : 'What would make your next Micro-Action easier right now?';
                if (s.chat.isEmpty || s.chat.last.text != tip) {
                  s.chat.add(ChatMsg('assistant', tip));
                  await s.save();
                }
                widget.onCoach(preset: '', send: false);
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const CoachAvatar(size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('FROM YOUR COACH', style: T.label),
                      const SizedBox(height: 6),
                      Text(s.dailyTip.isNotEmpty ? s.dailyTip : 'What would make your next Micro-Action easier right now?',
                          style: const TextStyle(fontSize: 16.5, height: 1.4, color: NC.navy, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      const Text('Reply to navoo', style: TextStyle(color: NC.blue, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          InfoCard(
              icon: Icons.event_available,
              label: 'Your 30-Day Focus · week $week',
              title: s.focus,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()))),
          const SizedBox(height: 10),
          InfoCard(
              icon: Icons.favorite_border,
              tint: NC.lilacTint,
              iconColor: const Color(0xFF7A62B8),
              label: 'Your Vision',
              title: s.visionHeadline,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisionCardScreen()))),
        ]),
      ),
    );
  }
}

/// 30-Day Focus: this week's Micro-Actions (tap to change), earlier weeks as history (P3).
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final s = AppState.I;
  bool busy = false;

  Future<void> _edit(MicroAction a) async {
    final changed = await editMicroAction(context, a, onBusy: (b) => setState(() => busy = b));
    if (!mounted) return;
    setState(() {});
    if (changed && a.status == 'active') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const IfThenScreen(fromHome: true)));
    }
  }

  Future<void> _different() async {
    setState(() => busy = true);
    final list = await suggestMoreMicroActions(rejected: s.queue.map((a) => a.title).toList(), replaceQueue: true);
    if (!mounted) return;
    setState(() => busy = false);
    if (list.isEmpty) {
      toast(context, "Couldn't reach the coach. Try again in a moment.");
    } else {
      // R16: show the new set with a Confirm button first.
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmMicroActionsScreen(suggested: list, replaceQueue: true)));
      if (mounted) setState(() {});
    }
  }

  Widget _row(MicroAction a, {bool editable = false}) {
    final done = a.status == 'done', skipped = a.status == 'skipped', active = a.status == 'active';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InfoCard(
        icon: done ? Icons.check : (skipped ? Icons.remove : (active ? iconFor(a.title) : Icons.lock_outline)),
        tint: done ? NC.sageTint : (active ? NC.warmTint : NC.bg),
        iconColor: done ? NC.success : (active ? NC.warning : NC.slate),
        label: done ? 'Done' : (skipped ? 'Not done' : (active ? 'Right now' : 'Coming next')),
        title: a.title,
        subtitle: a.description.isEmpty ? null : a.description,
        trailing: editable ? const Icon(Icons.edit_outlined, color: NC.slate, size: 20) : null,
        onTap: editable ? () => _edit(a) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thisWeek = s.actions.where((a) => a.week == s.week).toList();
    final earlier = s.weeksWithActions.where((w) => w < s.week).toList();
    return NavooScaffold(
      body: busy
          ? const NavooThinking()
          : ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
              const Text('Your 30-Day Focus', style: T.h1),
              const SizedBox(height: 12),
              Text(s.focus, style: T.h2),
              const SizedBox(height: 8),
              Text('Under your Vision: ${s.visionHeadline}', style: T.sub),
              const SizedBox(height: 22),
              Text("THIS WEEK'S MICRO-ACTIONS · WEEK ${s.week}", style: T.label),
              const SizedBox(height: 10),
              for (final a in thisWeek.where((a) => a.status == 'done')) _row(a),
              for (final a in s.queue) _row(a, editable: true),
              if (s.queue.isNotEmpty) ...[
                const Text('Tap a Micro-Action to change it.', style: T.small),
                const SizedBox(height: 10),
                SoftButton('Suggest different Micro-Actions', icon: Icons.refresh, onPressed: _different),
              ] else
                const Text("You've done this week's Micro-Actions. Add more from Home, or do your check-in.", style: T.small),
              for (final w in earlier) ...[
                const SizedBox(height: 22),
                Text('WEEK $w', style: T.label),
                const SizedBox(height: 10),
                for (final a in s.actions.where((a) => a.week == w)) _row(a),
              ],
              const SizedBox(height: 18),
              SoftButton('Edit my focus', icon: Icons.edit_outlined, outlined: true, onPressed: () async {
                final c = TextEditingController(text: s.focus);
                final r = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: NC.bg,
                    title: const Text('Your 30-Day Focus', style: T.h3),
                    content: TextField(controller: c, maxLines: 3, autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save')),
                    ],
                  ),
                );
                if (r != null && r.trim().isNotEmpty) {
                  setState(() => s.focus = r.trim());
                  await s.save();
                }
              }),
              const SizedBox(height: 10),
              SoftButton('Talk it through with navoo', icon: Icons.chat_bubble_outline, outlined: true,
                  onPressed: () => openCoach(context, preset: 'Can we talk about my 30-Day Focus? ')),
            ]),
    );
  }
}

/// P1 "make it harder": Navoo proposes a slightly harder next version; the user decides.
Future<void> makeItHarder(BuildContext context) async {
  final s = AppState.I;
  final a = s.currentAction;
  if (a == null) return;
  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  final r = await Coach.task('adapt', {
    'current_micro_action': a.title,
    'description': a.description,
    'focus': s.focus,
    'vision': s.visionHeadline,
    'all_previous_micro_actions': s.actions.map((x) => x.title).toList(),
  });
  if (!context.mounted) return;
  Navigator.pop(context);
  final title = '${r?['title'] ?? ''}'.trim();
  if (title.isEmpty) {
    openCoach(context, preset: 'I\'m nailing "${a.title}". Can we make it a bit harder?', send: true);
    return;
  }
  final use = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: NC.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const CoachAvatar(size: 36), const SizedBox(width: 10), Expanded(child: Text('${r?['message'] ?? 'Nice work. Here is a small step up.'}', style: T.body))]),
          const SizedBox(height: 16),
          InfoCard(icon: Icons.trending_up, tint: NC.sageTint, iconColor: NC.success, label: 'Your new Micro-Action', title: title, subtitle: '${r?['description'] ?? ''}'),
          const SizedBox(height: 16),
          PrimaryButton('Use this Micro-Action', trailingArrow: true, onPressed: () => Navigator.pop(context, true)),
          const SizedBox(height: 8),
          SoftButton('Keep my current one', outlined: true, onPressed: () => Navigator.pop(context, false)),
        ]),
      ),
    ),
  );
  if (use != true || !context.mounted) return;
  final n = MicroAction(
    id: '${DateTime.now().microsecondsSinceEpoch}',
    title: title,
    description: '${r?['description'] ?? ''}',
    why: '${r?['why'] ?? ''}',
    minutes: (r?['minutes'] is num) ? (r!['minutes'] as num).toInt() : 10,
    week: s.week,
    status: 'active',
    reward: a.reward,
  );
  a.status = 'skipped';
  s.actions.insert(s.actions.indexOf(a) + 1, n);
  await s.save();
  if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const IfThenScreen(fromHome: true)));
}

/// P1: a clear, coloured "How is this going?" card with three choices.
/// R15: a gentle reminder that the coach is there.
class CoachSignpost extends StatelessWidget {
  final VoidCallback onTap;
  const CoachSignpost({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: NC.lilacTint, borderRadius: BorderRadius.circular(22)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CoachAvatar(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  "Remember your coach is here any time you're struggling with your 30-Day Focus. Don't struggle in silence: message navoo and we'll work out the next step together.",
                  style: TextStyle(fontSize: 15, height: 1.4, color: NC.navy)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onTap,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Message navoo'),
              ),
            ]),
          ),
        ]),
      );
}

class _AdaptCard extends StatelessWidget {
  final void Function(String msg, bool send) onPick;
  final String title;
  const _AdaptCard({required this.onPick, required this.title});
  @override
  Widget build(BuildContext context) {
    Widget choice(IconData icon, String label, String msg, Color c, {bool send = true, bool harder = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => harder ? makeItHarder(context) : onPick(msg, send),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(children: [
                  Icon(icon, color: c),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 15.5, color: NC.navy, fontWeight: FontWeight.w600))),
                  const Icon(Icons.chevron_right, color: NC.slate),
                ]),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: NC.warmTint, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('How is this going?', style: T.h3),
        const SizedBox(height: 4),
        const Text("Adapting your Micro-Actions to real life is how change sticks. Tell navoo and we'll adjust.", style: T.small),
        const SizedBox(height: 12),
        choice(Icons.trending_up, "I'm nailing it, make it harder", '', NC.success, harder: true),
        choice(Icons.support, "I'm struggling, help me", 'I\'m struggling with "$title". Can you help me?', NC.error),
        choice(Icons.tune, 'Something has changed', 'Something has changed with "$title". ', NC.blue, send: false),
      ]),
    );
  }
}
