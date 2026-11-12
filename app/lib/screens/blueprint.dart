import 'package:flutter/material.dart';
import '../api.dart';
import '../device.dart';
import '../state.dart';
import '../theme.dart';
import 'actions.dart';
import 'chat_widgets.dart';
import 'vision.dart';

/// Screen 7 — "Let's make this personal."
class PersonalIntroScreen extends StatelessWidget {
  const PersonalIntroScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Center(child: StepBar(1)),
                const SizedBox(height: 22),
                const NavooLogo(height: 32),
                const SizedBox(height: 22),
                const Text("Let's make this personal.", style: T.h1),
                const SizedBox(height: 14),
                Text(
                    "${AppState.I.firstName.isNotEmpty ? 'Hi ${AppState.I.firstName}. ' : ''}I'll ask you a few quick questions about what you want, what matters to you and what tends to get in the way.",
                    style: T.sub),
                const SizedBox(height: 10),
                const Text('That helps me give you advice that actually fits your life.', style: T.sub),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: Image.asset('assets/images/hero_personal.jpg', fit: BoxFit.cover, width: double.infinity, alignment: Alignment.topCenter)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: NC.sageTint, borderRadius: BorderRadius.circular(16)),
                  child: const Row(children: [
                    Icon(Icons.science_outlined, color: NC.success),
                    SizedBox(width: 12),
                    Expanded(child: Text('Built on proven behavioural science.', style: TextStyle(fontSize: 15.5, color: NC.navy))),
                  ]),
                ),
                const SizedBox(height: 12),
                PrimaryButton("Let's begin",
                    trailingArrow: true,
                    testKey: const Key('intro_begin'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlueprintChatScreen()))),
                LinkText("What's the science behind this?", onTap: () => showScienceSheet(context)),
                const Text('Navoo is an AI coach, not a medical service.', style: TextStyle(fontSize: 12.5, color: NC.slate)),
              ]),
            ),
          ),
        ]),
      );
}

void showScienceSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: NC.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const Padding(
      padding: EdgeInsets.fromLTRB(26, 26, 26, 36),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Why this works', style: T.h2),
        SizedBox(height: 14),
        Text('• A clear picture of where you are heading helps you notice choices that move you towards it.', style: T.body),
        SizedBox(height: 8),
        Text('• Naming what will get in the way, before it happens, makes it easier to handle when it does.', style: T.body),
        SizedBox(height: 8),
        Text('• Deciding "if this happens, then I will do that" in advance makes follow-through more likely.', style: T.body),
        SizedBox(height: 8),
        Text('• A small reward straight after an action helps it stick.', style: T.body),
        SizedBox(height: 8),
        Text('• When something doesn\'t work, we adapt the approach, not the goal.', style: T.body),
      ]),
    ),
  );
}

enum _K { coach, user, focusOptions, loading }

class _Item {
  final _K kind;
  final String text;
  _Item(this.kind, [this.text = '']);
}

/// Screens 8–14 — the Blueprint, as one conversation.
class BlueprintChatScreen extends StatefulWidget {
  const BlueprintChatScreen({super.key});
  @override
  State<BlueprintChatScreen> createState() => _BlueprintChatScreenState();
}

class _BlueprintChatScreenState extends State<BlueprintChatScreen> {
  final s = AppState.I;
  final items = <_Item>[];
  final scroll = ScrollController();
  final input = TextEditingController();
  String step = 'wish';
  List<QuickChoice> choices = [];
  bool gridChoices = false;
  bool busy = false;
  List<Map<String, String>> focusOptions = [];

  int get barStep => switch (step) {
        'wish' || 'reason' => 1,
        'feel' || 'look' || 'able' || 'showup' => 2,
        'focus' => 3,
        _ => 4,
      };

  @override
  void initState() {
    super.initState();
    _coach('What would you most like to change about your health right now?');
    choices = const [
      QuickChoice('Lose weight and feel healthier', icon: Icons.favorite_border, color: NC.warning),
      QuickChoice('Have more energy', icon: Icons.bolt, color: NC.blue),
      QuickChoice('Eat better', icon: Icons.restaurant, color: NC.success),
      QuickChoice('Move more', icon: Icons.directions_walk, color: Color(0xFF7A62B8)),
    ];
  }

  void _coach(String t) => items.add(_Item(_K.coach, t));

  void _scroll() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });

  Future<void> _pause() => Future.delayed(const Duration(milliseconds: 450));

  Future<void> answer(String text) async {
    if (busy) return;
    setState(() {
      items.add(_Item(_K.user, text));
      choices = [];
      gridChoices = false;
    });
    _scroll();
    switch (step) {
      case 'wish':
        s.wish = text;
        await _pause();
        setState(() {
          _coach("Got it. That can mean quite a few things, so let's work out what matters most to you.\n\nWhat's the main reason you want to make this change?");
          choices = const [
            QuickChoice('I want more energy', icon: Icons.bolt, color: NC.blue),
            QuickChoice('I want to feel more confident', icon: Icons.sentiment_satisfied_alt, color: NC.success),
            QuickChoice('I want to be healthier long term', icon: Icons.favorite_border, color: NC.warning),
          ];
          step = 'reason';
        });
      case 'reason':
        s.reason = text;
        await _pause();
        setState(() {
          _coach("First, we'll picture the bigger change: your vision. Then we'll agree a 30-day focus, followed by small actions.");
          _coach("How do you want to feel when you're living the life you're working towards? A few words is plenty.");
          choices = const [QuickChoice('Lighter'), QuickChoice('Confident'), QuickChoice('Energetic'), QuickChoice('Calm'), QuickChoice('Proud'), QuickChoice('Strong')];
          gridChoices = true;
          step = 'feel';
        });
      case 'feel':
        s.visionAnswers['feel'] = text;
        await _pause();
        setState(() {
          _coach('How do you want to look? It doesn\'t need to be a number on the scale.');
          step = 'look';
        });
      case 'look':
        s.visionAnswers['look'] = text;
        await _pause();
        setState(() {
          _coach('Noted. What do you want to be able to do?');
          step = 'able';
        });
      case 'able':
        s.visionAnswers['able_to_do'] = text;
        await _pause();
        setState(() {
          _coach('How would you show up differently, day to day?');
          step = 'showup';
        });
      case 'showup':
        s.visionAnswers['show_up'] = text;
        await _buildVision();
      case 'focus':
        await _setFocus(text);
      case 'obstacle1':
        s.obstaclesText = text;
        await _pause();
        setState(() {
          _coach("That makes sense, and it's very common. When that happens, what usually happens next?");
          choices = const [
            QuickChoice('I order takeaway'),
            QuickChoice('I snack instead'),
            QuickChoice('I make whatever is quickest'),
            QuickChoice('I skip it and eat later'),
            QuickChoice('It varies'),
          ];
          step = 'obstacle2';
        });
      case 'obstacle2':
        s.obstaclesText = '${s.obstaclesText}. Then: $text';
        setState(() {
          busy = true;
          items.add(_Item(_K.loading));
        });
        _scroll();
        final r = await Coach.task('categorise_obstacles', {'said': s.obstaclesText, 'focus': s.focus});
        s.obstaclesLogistical = (r?['logistical'] is List) ? List<String>.from((r!['logistical'] as List).map((e) => '$e')) : [];
        s.obstaclesPsychological = (r?['psychological'] is List) ? List<String>.from((r!['psychological'] as List).map((e) => '$e')) : [];
        s.obstaclesSummary = (r?['summary'] ?? '').toString().isNotEmpty ? r!['summary'].toString() : _short(s.obstaclesText);
        await s.save();
        setState(() {
          busy = false;
          items.removeWhere((i) => i.kind == _K.loading);
          _coach("That's useful to know. We'll plan around it rather than hoping it won't happen.");
          _coach("If you succeed at this, what does that say about the person you're becoming?");
          step = 'identity';
        });
      case 'identity':
        s.identity = text;
        await _pause();
        setState(() {
          _coach('And why does that matter to you?');
          step = 'why';
        });
      case 'why':
        s.whyMatters = text;
        await s.save();
        await _pause();
        setState(() {
          _coach('Last one. When you complete something difficult, what would feel like a good little reward straight away? Something simple you enjoy.');
          choices = const [
            QuickChoice('Tea or coffee', icon: Icons.coffee_outlined),
            QuickChoice('Favourite show', icon: Icons.tv, color: Color(0xFF7A62B8)),
            QuickChoice('Music', icon: Icons.music_note_outlined, color: NC.success),
            QuickChoice('Relaxation time', icon: Icons.spa_outlined, color: NC.success),
            QuickChoice('Something enjoyable', icon: Icons.sentiment_satisfied_alt, color: NC.warning),
            QuickChoice('Personal ritual', icon: Icons.favorite_border, color: NC.error),
          ];
          gridChoices = true;
          step = 'reward';
        });
      case 'reward':
        s.reward = text;
        await s.save();
        if (!mounted) return;
        final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const RewardCardScreen()));
        if (saved == true && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryScreen()));
        } else if (mounted) {
          setState(() {
            _coach('No problem. Tell me the reward you would like instead.');
            step = 'reward';
          });
        }
    }
    _scroll();
  }

  String _short(String t) => t.length > 70 ? '${t.substring(0, 67)}...' : t;

  Future<void> _buildVision() async {
    setState(() {
      busy = true;
      _coach("Thanks. I'm putting your vision together.");
      items.add(_Item(_K.loading));
    });
    _scroll();
    final r = await Coach.task('vision', {'wish': s.wish, 'reason': s.reason, ...s.visionAnswers});
    final a = s.visionAnswers;
    s.visionHeadline = (r?['headline'] ?? '').toString().isNotEmpty ? r!['headline'].toString() : 'A healthier, more confident you.';
    s.visionBody = (r?['body'] ?? '').toString().isNotEmpty
        ? r!['body'].toString()
        : 'You want to feel ${a['feel'] ?? 'good'}. ${a['able_to_do'] ?? ''}'.trim();
    s.feelings = (r?['feelings'] is List) ? List<String>.from((r!['feelings'] as List).map((e) => '$e')).take(3).toList() : (a['feel'] ?? '').split(RegExp(r'[,\s]+')).where((e) => e.isNotEmpty).take(3).toList();
    if ((r?['identity'] ?? '').toString().isNotEmpty) s.identity = r!['identity'].toString();
    await s.save();
    if (!mounted) return;
    setState(() {
      busy = false;
      items.removeWhere((i) => i.kind == _K.loading);
    });
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const VisionCardScreen(onboarding: true)));
    if (!mounted) return;
    setState(() {
      _coach('With your vision in mind, what feels right to focus on for the next 30 days? Here are three options. Pick one, edit it, or suggest your own.');
      step = 'focus';
    });
    await _loadFocusOptions();
  }

  Future<void> _loadFocusOptions() async {
    setState(() {
      busy = true;
      items.removeWhere((i) => i.kind == _K.focusOptions);
      items.add(_Item(_K.loading));
    });
    _scroll();
    final r = await Coach.task('focus_options', {'wish': s.wish, 'reason': s.reason, 'vision': '${s.visionHeadline} ${s.visionBody}', 'already_shown': focusOptions.map((e) => e['title']).toList()});
    final list = (r?['options'] is List) ? (r!['options'] as List) : [];
    focusOptions = list
        .whereType<Map>()
        .map((m) => {'title': '${m['title'] ?? ''}', 'why': '${m['why'] ?? ''}'})
        .where((m) => m['title']!.isNotEmpty)
        .take(3)
        .toList();
    if (focusOptions.isEmpty) {
      focusOptions = [
        {'title': 'Build healthier dinners into my workweek.', 'why': 'Evenings are often where good intentions slip.'},
        {'title': 'Move for 10 minutes most days.', 'why': 'Small and repeatable beats big and occasional.'},
        {'title': 'Cut down on evening snacking.', 'why': 'A small change at a tricky time of day.'},
      ];
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      items.removeWhere((i) => i.kind == _K.loading);
      items.add(_Item(_K.focusOptions));
    });
    _scroll();
  }

  Future<void> _setFocus(String text) async {
    s.focus = text.trim();
    s.focusStart = DateTime.now();
    await s.save();
    setState(() {
      items.removeWhere((i) => i.kind == _K.focusOptions);
    });
    await _pause();
    setState(() {
      _coach('Your 30-day focus: "${s.focus}"');
      _coach("What's most likely to get in your way with this?");
      choices = const [
        QuickChoice("I'm too tired after work"),
        QuickChoice("I don't have time"),
        QuickChoice('Takeaway or snacks are easier'),
        QuickChoice('Stress'),
        QuickChoice('Weekends throw me off'),
      ];
      step = 'obstacle1';
    });
    _scroll();
  }

  Future<void> _editFocus(String start) async {
    final c = TextEditingController(text: start);
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NC.bg,
        title: const Text('Edit your focus', style: T.h3),
        content: TextField(controller: c, maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Use this focus')),
        ],
      ),
    );
    if (r != null && r.trim().isNotEmpty) {
      setState(() => items.add(_Item(_K.user, r.trim())));
      await _setFocus(r);
    }
  }

  Widget _focusCards() => Column(children: [
        for (var i = 0; i < focusOptions.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: NC.sageTint, borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.track_changes, color: NC.success),
                const SizedBox(width: 8),
                Text('Option ${i + 1}', style: T.small),
              ]),
              const SizedBox(height: 8),
              Text(focusOptions[i]['title']!, style: T.h3),
              if (focusOptions[i]['why']!.isNotEmpty) ...[const SizedBox(height: 6), Text(focusOptions[i]['why']!, style: T.small)],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    key: Key('focus_use_$i'),
                    style: FilledButton.styleFrom(backgroundColor: NC.blue, minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      final t = focusOptions[i]['title']!;
                      setState(() => items.add(_Item(_K.user, t)));
                      _setFocus(t);
                    },
                    child: const Text('Use this focus'),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(onPressed: () => _editFocus(focusOptions[i]['title']!), child: const Text('Edit')),
              ]),
            ]),
          ),
        Row(children: [
          Expanded(child: SoftButton('Show other options', icon: Icons.refresh, onPressed: busy ? null : _loadFocusOptions)),
        ]),
        const SizedBox(height: 6),
        const Text('Or type your own focus below.', style: T.small),
      ]);

  Widget _itemWidget(int i) {
    final it = items[i];
    switch (it.kind) {
      case _K.coach:
        return ChatBubble(it.text, fromCoach: true, showAvatar: i == 0 || items[i - 1].kind != _K.coach);
      case _K.user:
        return ChatBubble(it.text, fromCoach: false);
      case _K.loading:
        return const TypingBubble();
      case _K.focusOptions:
        return _focusCards();
    }
  }

  @override
  Widget build(BuildContext context) => NavooScaffold(
        step: barStep,
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Row(children: const [NavooLogo(height: 26)])),
          Expanded(
            child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
              for (var i = 0; i < items.length; i++) _itemWidget(i),
              if (choices.isNotEmpty) ...[
                const SizedBox(height: 8),
                QuickChoices(choices, grid: gridChoices, onPick: (v) {
                  if (step == 'feel') {
                    final cur = input.text.trim();
                    input.text = cur.isEmpty ? v : '$cur, $v';
                    input.selection = TextSelection.collapsed(offset: input.text.length);
                  } else {
                    answer(v);
                  }
                }),
                if (step == 'feel') const Text('Tap a few, add your own words, then send.', style: T.small),
                if (step != 'feel')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: const [
                      Icon(Icons.chat_bubble_outline, size: 18, color: NC.slate),
                      SizedBox(width: 8),
                      Text('Or tell me in your own words below', style: T.small),
                    ]),
                  ),
              ],
            ]),
          ),
          ChatInput(onSend: answer, enabled: !busy, controller: input),
        ]),
      );
}

/// Screen 14 — Your reward card.
class RewardCardScreen extends StatelessWidget {
  const RewardCardScreen({super.key});
  @override
  Widget build(BuildContext context) => NavooScaffold(
        step: 4,
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/images/reward_tea.jpg', height: 230, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 20),
          const Text('YOUR REWARD', style: T.label),
          const SizedBox(height: 8),
          Text(AppState.I.reward, style: T.h2),
          const SizedBox(height: 10),
          const Text("We'll use this to reinforce the actions you take. Straight after you finish an action, this is yours.", style: T.sub),
          const SizedBox(height: 22),
          const Row(children: [
            _RewardWhy(Icons.bolt, NC.blueTint, NC.blue, 'Boosts\nmotivation'),
            _RewardWhy(Icons.favorite_border, NC.roseTint, NC.error, 'Makes it more\nenjoyable'),
            _RewardWhy(Icons.star_border, NC.sageTint, NC.success, 'Helps it\nstick'),
          ]),
          const SizedBox(height: 26),
          PrimaryButton('Save reward', testKey: const Key('reward_save'), onPressed: () => Navigator.pop(context, true)),
          const SizedBox(height: 12),
          SoftButton('Edit my reward', onPressed: () async {
            final c = TextEditingController(text: AppState.I.reward);
            final r = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: NC.bg,
                title: const Text('Your reward', style: T.h3),
                content: TextField(controller: c, maxLines: 2, autofocus: true),
                actions: [FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save'))],
              ),
            );
            if (r != null && r.trim().isNotEmpty) {
              AppState.I.reward = r.trim();
              await AppState.I.save();
              if (context.mounted) Navigator.pop(context, true);
            }
          }),
        ]),
      );
}

class _RewardWhy extends StatelessWidget {
  final IconData icon;
  final Color tint, color;
  final String text;
  const _RewardWhy(this.icon, this.tint, this.color, this.text);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: tint, shape: BoxShape.circle), child: Icon(icon, color: color)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: T.small),
        ]),
      );
}

/// Screen 15 — "You've got your bigger picture."
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return NavooScaffold(
      step: 5,
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
        const NavooLogo(height: 28),
        const SizedBox(height: 18),
        const Text("You've got your bigger picture.", style: T.h1),
        const SizedBox(height: 8),
        const Text("Here's a summary of what you've shared.", style: T.sub),
        const SizedBox(height: 20),
        InfoCard(icon: Icons.track_changes, tint: NC.sageTint, iconColor: NC.success, label: 'Your vision', title: s.visionHeadline),
        const SizedBox(height: 10),
        InfoCard(icon: Icons.event_available, label: 'Your 30-day focus', title: s.focus),
        const SizedBox(height: 10),
        InfoCard(
            icon: Icons.warning_amber_rounded,
            tint: NC.warmTint,
            iconColor: NC.warning,
            label: 'What might get in the way',
            title: s.obstaclesSummary.isEmpty ? s.obstaclesText : s.obstaclesSummary),
        const SizedBox(height: 10),
        InfoCard(
            icon: Icons.favorite_border,
            tint: NC.lilacTint,
            iconColor: const Color(0xFF7A62B8),
            label: 'What matters to you',
            title: s.whyMatters.isEmpty ? s.identity : s.whyMatters),
        const SizedBox(height: 10),
        InfoCard(icon: Icons.card_giftcard, tint: NC.sageTint, iconColor: NC.success, label: 'Your reward', title: s.reward),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: NC.blueTint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.chat_bubble_outline, color: NC.blue),
            SizedBox(width: 12),
            Expanded(
                child: Text(
                    "Next, we'll choose small, realistic steps towards your focus, one at a time. When real life gets in the way, talk to me and we'll adapt.",
                    style: T.body)),
          ]),
        ),
        const SizedBox(height: 20),
        PrimaryButton('Build my first steps',
            trailingArrow: true,
            testKey: const Key('summary_build'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInSetupScreen(onboarding: true)))),
      ]),
    );
  }
}

const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String fmtTime(int h, int m) {
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

/// Screen 16 — weekly check-in.
class CheckInSetupScreen extends StatefulWidget {
  final bool onboarding;
  const CheckInSetupScreen({super.key, this.onboarding = false});
  @override
  State<CheckInSetupScreen> createState() => _CheckInSetupScreenState();
}

class _CheckInSetupScreenState extends State<CheckInSetupScreen> {
  final s = AppState.I;
  bool allSet = false;

  Future<void> pick() async {
    final day = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: NC.bg,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(20), child: Text('Which day?', style: T.h3)),
          for (var i = 0; i < 7; i++)
            ListTile(title: Text(weekdayNames[i]), trailing: s.reviewWeekday == i + 1 ? const Icon(Icons.check, color: NC.blue) : null, onTap: () => Navigator.pop(context, i + 1)),
        ]),
      ),
    );
    if (day == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: s.reviewHour, minute: s.reviewMinute));
    setState(() {
      s.reviewWeekday = day;
      if (t != null) {
        s.reviewHour = t.hour;
        s.reviewMinute = t.minute;
      }
    });
    await s.save();
  }

  Future<void> finish({bool calendar = false, bool reminder = false}) async {
    if (calendar) await Device.addWeeklyCheckInToCalendar();
    if (reminder) {
      s.nudgeWeekly = true;
      await Device.askNotificationPermission();
    }
    await s.save();
    if (!mounted) return;
    if (calendar || reminder) {
      setState(() => allSet = true);
    } else {
      _next();
    }
  }

  void _next() {
    if (widget.onboarding) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FirstStepsScreen()));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final when = '${weekdayNames[s.reviewWeekday - 1]}, ${fmtTime(s.reviewHour, s.reviewMinute)}';
    if (allSet) {
      return NavooScaffold(
        step: widget.onboarding ? 5 : null,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Column(children: [
            const Spacer(),
            Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(color: NC.sageTint, shape: BoxShape.circle),
                child: const Icon(Icons.event_available, size: 76, color: NC.success)),
            const SizedBox(height: 26),
            const Text('All set.', style: T.h1),
            const SizedBox(height: 10),
            Text("You'll get a reminder every $when to look at your week and adjust what comes next.", textAlign: TextAlign.center, style: T.sub),
            const Spacer(),
            PrimaryButton('Continue', trailingArrow: true, onPressed: _next, testKey: const Key('checkin_continue')),
          ]),
        ),
      );
    }
    return NavooScaffold(
      step: widget.onboarding ? 5 : null,
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
        const NavooLogo(height: 28),
        const SizedBox(height: 18),
        const Text("Let's set up your weekly check-in.", style: T.h1),
        const SizedBox(height: 10),
        const Text('Just 10 minutes each week to look at your progress, notice what is working and adjust what comes next.', style: T.sub),
        const SizedBox(height: 20),
        const _Bullet(Icons.bar_chart_rounded, NC.sageTint, NC.success, 'Review your progress'),
        const _Bullet(Icons.favorite_border, NC.blueTint, NC.blue, "Notice what's working"),
        const _Bullet(Icons.sync, NC.lilacTint, Color(0xFF7A62B8), 'Adapt where needed'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: NC.blueTint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('WHEN WOULD YOU LIKE TO CHECK IN?', style: T.label),
            const SizedBox(height: 10),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined, color: NC.blue),
                title: Text(when, style: const TextStyle(fontWeight: FontWeight.w600, color: NC.navy)),
                trailing: const Icon(Icons.chevron_right),
                onTap: pick,
              ),
            ),
            Center(child: LinkText('Choose a different time', onTap: pick)),
          ]),
        ),
        const SizedBox(height: 18),
        PrimaryButton('Add to calendar', icon: Icons.event, onPressed: () => finish(calendar: true), testKey: const Key('checkin_calendar')),
        const SizedBox(height: 12),
        SoftButton('Set reminder', icon: Icons.notifications_none, onPressed: () => finish(reminder: true)),
        Center(child: LinkText("I'll do this later", onTap: () => finish())),
      ]),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final Color tint, color;
  final String text;
  const _Bullet(this.icon, this.tint, this.color, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: tint, shape: BoxShape.circle), child: Icon(icon, color: color)),
          const SizedBox(width: 14),
          Text(text, style: const TextStyle(fontSize: 16.5, color: NC.navy)),
        ]),
      );
}
