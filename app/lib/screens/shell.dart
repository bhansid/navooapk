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
          NavigationDestination(key: Key('tab_coach'), icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble, color: NC.blue), label: 'Coach'),
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
            const NavooLogo(height: 26),
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
                    const Text("You've completed this week's steps.", style: T.h2),
                    const SizedBox(height: 8),
                    const Text("At your check-in we'll choose the next ones together, based on what you learned.", style: T.sub),
                    const SizedBox(height: 16),
                    PrimaryButton('Start my check-in',
                        trailingArrow: true, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyReviewIntro()))),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('YOUR FOCUS RIGHT NOW', style: T.label),
                          const SizedBox(height: 8),
                          Text(a.title, key: const Key('home_action_title'), style: T.h2),
                          const SizedBox(height: 6),
                          Text(a.ifCue.isNotEmpty ? 'If ${a.ifCue}, then ${a.thenDo}.' : 'One small step towards your 30-day focus.', style: T.small),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                              iconFor(a.title) == Icons.restaurant || iconFor(a.title) == Icons.kitchen_outlined ? 'assets/images/food_bowl.jpg' : 'assets/images/meal_prep.jpg',
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
                    const SizedBox(height: 10),
                    SoftButton('Things have changed, help me adapt',
                        icon: Icons.tune, onPressed: () => widget.onCoach(preset: 'Things have changed with "${a.title}". ', send: false)),
                    const SizedBox(height: 8),
                    Center(
                        child: LinkText('Help me adjust this',
                            onTap: () => widget.onCoach(preset: '"${a.title}" isn\'t quite working for me. Can we adjust it?', send: true))),
                  ]),
          ),
          const SizedBox(height: 14),
          // Daily coach slot
          Material(
            color: NC.blueTint,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () async {
                final tip = s.dailyTip.isNotEmpty ? s.dailyTip : 'What would make your next step easier right now?';
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
                      Text(s.dailyTip.isNotEmpty ? s.dailyTip : 'What would make your next step easier right now?',
                          style: const TextStyle(fontSize: 16.5, height: 1.4, color: NC.navy, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      const Text('Reply to Navoo', style: TextStyle(color: NC.blue, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          InfoCard(
              icon: Icons.event_available,
              label: 'Your 30-day focus · week $week',
              title: s.focus,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()))),
          const SizedBox(height: 10),
          InfoCard(
              icon: Icons.favorite_border,
              tint: NC.lilacTint,
              iconColor: const Color(0xFF7A62B8),
              label: 'Your vision',
              title: s.visionHeadline,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisionCardScreen()))),
        ]),
      ),
    );
  }
}

/// 30-day focus view/edit.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final s = AppState.I;
  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
          const Text('Your 30-day focus', style: T.h1),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/images/food_bowl.jpg', height: 150, width: double.infinity, fit: BoxFit.cover)),
          const SizedBox(height: 16),
          Text(s.focus, style: T.h2),
          const SizedBox(height: 8),
          Text('Under your vision: ${s.visionHeadline}', style: T.sub),
          const SizedBox(height: 20),
          const Text('YOUR STEPS', style: T.label),
          const SizedBox(height: 10),
          for (final a in s.actions.reversed.take(9))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InfoCard(
                icon: a.status == 'done' ? Icons.check : (a.status == 'active' ? iconFor(a.title) : Icons.lock_outline),
                tint: a.status == 'done' ? NC.sageTint : (a.status == 'active' ? NC.warmTint : NC.bg),
                iconColor: a.status == 'done' ? NC.success : (a.status == 'active' ? NC.warning : NC.slate),
                label: a.status == 'done' ? 'Done' : (a.status == 'active' ? 'Right now' : 'Coming next'),
                title: a.title,
              ),
            ),
          const SizedBox(height: 14),
          SoftButton('Edit my focus', icon: Icons.edit_outlined, onPressed: () async {
            final c = TextEditingController(text: s.focus);
            final r = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: NC.bg,
                title: const Text('Your 30-day focus', style: T.h3),
                content: TextField(controller: c, maxLines: 3, autofocus: true),
                actions: [FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save'))],
              ),
            );
            if (r != null && r.trim().isNotEmpty) {
              setState(() => s.focus = r.trim());
              await s.save();
            }
          }),
          const SizedBox(height: 10),
          SoftButton('Talk it through with Navoo', icon: Icons.chat_bubble_outline, outlined: true,
              onPressed: () => openCoach(context, preset: 'Can we talk about my 30-day focus? ')),
        ]),
      );
}
