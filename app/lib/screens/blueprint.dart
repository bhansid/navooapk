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

/// R2: "What's the science behind this?" Navoo is supplying the final copy; each section below is a
/// placeholder in the agreed structure (why willpower alone is not enough, then the three Brain Cheat Codes).
const scienceSections = <(String, String)>[
  ('Why willpower alone is not enough',
      'Willpower runs low when we are tired, stressed or busy, which is exactly when old habits take over. Behavioural science gives you ways to make the right choice easier, so you rely on it less.'),
  ('Nudges', 'Small changes to your surroundings, like leaving your trainers by the door, make the action you want the easy and obvious one.'),
  ('Brain shortcuts (heuristics)', 'Your brain loves shortcuts. Navoo helps you set up simple rules and cues so the healthy choice becomes the automatic one.'),
  ('If/Then planning (implementation intentions)',
      'Deciding in advance "IF this happens, THEN I will do that" means you do not have to decide in the moment. Research shows it makes people much more likely to follow through.'),
  ('Brain Cheat Codes', 'Together these are your Brain Cheat Codes: Navoo helps you create them for every Micro-Action.'),
];

void showScienceSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: NC.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (_, controller) => ListView(controller: controller, padding: const EdgeInsets.fromLTRB(26, 26, 26, 36), children: [
        const Text("What's the science behind this?", style: T.h2),
        const SizedBox(height: 14),
        for (final (title, body) in scienceSections) ...[
          Text(title, style: T.h3),
          const SizedBox(height: 4),
          Text(body, style: T.body),
          const SizedBox(height: 14),
        ],
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

/// R7: one step of the set-up chat, so Back can undo exactly one answer and keep what was typed.
class _Snap {
  final List<_Item> items;
  final String step;
  final List<QuickChoice> choices;
  final bool gridChoices;
  final List<List<Map<String, String>>> focusSets;
  final int focusIndex;
  final bool askedRewardDetail;
  final String pendingFocus;
  final String typed;
  _Snap(this.items, this.step, this.choices, this.gridChoices, this.focusSets, this.focusIndex, this.askedRewardDetail, this.pendingFocus, this.typed);
}

/// Kept in memory so leaving set-up and coming back resumes where the user was (R7).
class _Resume {
  final _Snap now;
  final List<_Snap> history;
  final int ackCount;
  _Resume(this.now, this.history, this.ackCount);
}

/// Forget an unfinished set-up chat (used when a different account signs in).
void resetSetupChat() => _BlueprintChatScreenState._resume = null;

/// Screens 8–14 — the Blueprint, as one conversation.
class BlueprintChatScreen extends StatefulWidget {
  const BlueprintChatScreen({super.key});
  @override
  State<BlueprintChatScreen> createState() => _BlueprintChatScreenState();
}

class _BlueprintChatScreenState extends State<BlueprintChatScreen> {
  static _Resume? _resume;

  final s = AppState.I;
  final items = <_Item>[];
  final scroll = ScrollController();
  final input = TextEditingController();
  String step = 'wish';
  List<QuickChoice> choices = [];
  bool gridChoices = false;
  bool busy = false;
  bool finished = false;
  // R6: every set of focus options shown, so the user can go back to earlier ones.
  List<List<Map<String, String>>> focusSets = [];
  int focusIndex = -1;
  List<Map<String, String>> get focusOptions => focusIndex >= 0 && focusIndex < focusSets.length ? focusSets[focusIndex] : const [];
  String pendingFocus = '';
  final history = <_Snap>[];
  int ackCount = 0;

  _Snap _snap([String typed = '']) => _Snap(List.of(items), step, List.of(choices), gridChoices,
      focusSets.map((e) => List<Map<String, String>>.of(e)).toList(), focusIndex, _askedRewardDetail, pendingFocus, typed);

  void _apply(_Snap x) {
    items
      ..clear()
      ..addAll(x.items);
    step = x.step;
    choices = List.of(x.choices);
    gridChoices = x.gridChoices;
    focusSets = x.focusSets.map((e) => List<Map<String, String>>.of(e)).toList();
    focusIndex = x.focusIndex;
    _askedRewardDetail = x.askedRewardDetail;
    pendingFocus = x.pendingFocus;
  }

  /// R7: Back undoes one answer and puts it back in the box, instead of leaving set-up.
  bool _stepBack() {
    if (busy || history.isEmpty) return false;
    final x = history.removeLast();
    setState(() => _apply(x));
    input.text = x.typed;
    input.selection = TextSelection.collapsed(offset: input.text.length);
    _scroll();
    return true;
  }

  @override
  void dispose() {
    _resume = finished ? null : _Resume(_snap(input.text), List.of(history), ackCount);
    super.dispose();
  }

  int get barStep => switch (step) {
        'wish' || 'reason' => 1,
        'feel' || 'look' || 'able' || 'showup' => 2,
        'focus' || 'focus_confirm' => 3,
        _ => 4,
      };

  @override
  void initState() {
    super.initState();
    final saved = _resume;
    if (saved != null) {
      _apply(saved.now);
      history.addAll(saved.history);
      ackCount = saved.ackCount;
      input.text = saved.now.typed;
      _scroll();
      return;
    }
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

  String get _lastQuestion {
    for (final it in items.reversed) {
      if (it.kind == _K.coach) return it.text;
    }
    return '';
  }

  static const _validations = ['OK, noted.', 'I hear you.', 'Sounds good.', 'Got it, thank you.', 'That makes sense.', 'Noted, thanks.'];

  /// C1 + R3: always acknowledge the answer, but vary it. Every other answer gets a one-line reflection
  /// in the user's words; the rest get a short validation (no AI call, so it is instant).
  Future<void> _ack(String answerText, {String? question, bool? reflect}) async {
    final q = question ?? _lastQuestion;
    final doReflect = reflect ?? (ackCount % 2 == 0);
    ackCount++;
    if (!doReflect) {
      setState(() => _coach(_validations[(ackCount ~/ 2) % _validations.length]));
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    setState(() {
      busy = true;
      items.add(_Item(_K.loading));
    });
    _scroll();
    final r = await Coach.task('acknowledge', {'question': q, 'answer': answerText, 'step': step});
    if (!mounted) return;
    setState(() {
      busy = false;
      items.removeWhere((i) => i.kind == _K.loading);
      final line = '${r?['line'] ?? ''}'.trim();
      _coach(line.isNotEmpty ? line : 'Thanks, that helps.');
    });
    await Future.delayed(const Duration(milliseconds: 250));
  }

  static const rewardLibrary = [
    'A cup of tea or coffee',
    '10 minutes of my favourite show',
    'My favourite song, played loud',
    'A few minutes outside in fresh air',
    'Telling myself "you\'ve got this"',
    'A pat on the back',
    'Messaging a friend about it',
    '5 minutes reading something I enjoy',
    'A long shower or bath',
    'A few minutes of a podcast',
  ];
  static const _vague = ['something', 'enjoyable', 'treat', 'nice', 'ritual', 'reward', 'relax', 'fun', 'anything'];
  bool _askedRewardDetail = false;

  Future<void> answer(String text) async {
    if (busy) return;
    history.add(_snap(text));
    setState(() {
      items.add(_Item(_K.user, text));
      choices = [];
      gridChoices = false;
    });
    _scroll();
    switch (step) {
      case 'wish':
        s.wish = text;
        await _ack(text);
        setState(() {
          _coach("What's the main reason you want to make this change?");
          choices = const [
            QuickChoice('I want more energy', icon: Icons.bolt, color: NC.blue),
            QuickChoice('I want to feel more confident', icon: Icons.sentiment_satisfied_alt, color: NC.success),
            QuickChoice('I want to be healthier long term', icon: Icons.favorite_border, color: NC.warning),
          ];
          step = 'reason';
        });
      case 'reason':
        s.reason = text;
        await _ack(text);
        setState(() {
          _coach("Next, we'll picture the bigger change: your Vision. Then we'll agree a 30-Day Focus, followed by small Micro-Actions.");
          _coach("How do you want to feel when you're living the life you're working towards? A few words is plenty.");
          choices = const [QuickChoice('Lighter'), QuickChoice('Confident'), QuickChoice('Energetic'), QuickChoice('Calm'), QuickChoice('Proud'), QuickChoice('Strong')];
          gridChoices = true;
          step = 'feel';
        });
      case 'feel':
        s.visionAnswers['feel'] = text;
        await _ack(text);
        setState(() {
          _coach('How would you like to look when you are living this?');
          step = 'look';
        });
      case 'look':
        s.visionAnswers['look'] = text;
        await _ack(text);
        setState(() {
          _coach('What do you want to be able to do?');
          step = 'able';
        });
      case 'able':
        s.visionAnswers['able_to_do'] = text;
        await _ack(text);
        setState(() {
          _coach("If you were already living this, what would you be doing differently on a normal day?");
          step = 'showup';
        });
      case 'showup':
        s.visionAnswers['show_up'] = text;
        await _ack(text);
        await _buildVision();
      case 'focus':
        await _focusTyped(text);
      case 'focus_confirm':
        if (text == 'Yes, use this focus') {
          await _setFocus(pendingFocus);
        } else {
          setState(() {
            pendingFocus = '';
            _coach('No problem. Pick one of the options, or type the focus you want in your own words.');
            step = 'focus';
          });
        }
      case 'obstacle1':
        s.obstaclesText = text;
        await _ack(text);
        setState(() {
          _coach('When that happens, what usually happens next?');
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
        });
        await _ack(s.obstaclesText, question: 'What usually gets in the way, and what happens next?');
        setState(() {
          _coach("We'll work around that rather than hoping it won't happen.");
          _coach('A couple of deeper questions now. Your answers will help us create the best Brain Cheat Codes for you.');
          _coach("If you succeed at this, what does that say about the person you're becoming?");
          step = 'identity';
        });
      case 'identity':
        s.identity = text;
        await _ack(text);
        setState(() {
          _coach('And why does that matter to you?');
          step = 'why';
        });
      case 'why':
        s.whyMatters = text;
        await s.save();
        await _ack(text);
        setState(() {
          _coach("Last one: rewards. A small reward straight after a Micro-Action helps it stick. Pick 2 to 4 that you'd genuinely enjoy at different times of day, or write your own. We'll match one to each Micro-Action.");
          choices = rewardLibrary.map((r) => QuickChoice(r)).toList();
          gridChoices = false;
          step = 'reward';
        });
      case 'reward':
        // Library rewards may contain commas, so take those out whole first, then split the rest.
        var rest = text;
        final picked = <String>[];
        for (final lib in rewardLibrary) {
          if (rest.contains(lib)) {
            picked.add(lib);
            rest = rest.replaceAll(lib, ',');
          }
        }
        picked.addAll(rest.split(RegExp(r'\s*[,;\n]\s*')).map((e) => e.trim()).where((e) => e.isNotEmpty));
        final vague = picked.where((p) => p.split(' ').length <= 3 && _vague.any((v) => p.toLowerCase().contains(v)) && !rewardLibrary.contains(p)).toList();
        if (vague.isNotEmpty && !_askedRewardDetail) {
          _askedRewardDetail = true;
          setState(() {
            _coach('"${vague.first}" sounds good. What exactly would that be? Something specific you could do in a few minutes straight after, like a favourite song or a short walk outside.');
            choices = rewardLibrary.map((r) => QuickChoice(r)).toList();
          });
          break;
        }
        s.rewards = picked.take(6).toList();
        s.reward = s.rewards.first;
        await s.save();
        if (!mounted) return;
        final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const RewardCardScreen()));
        if (saved == true && mounted) {
          finished = true;
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
      _coach("Thanks. I'm putting your Vision together.");
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
      _coach('With your Vision in mind, what feels right to focus on for the next 30 days? Here are three options. Pick one, edit it, or suggest your own.');
      step = 'focus';
    });
    await _loadFocusOptions();
  }

  void _showFocusSet(int i) {
    setState(() {
      focusIndex = i;
      items.removeWhere((x) => x.kind == _K.focusOptions);
      items.add(_Item(_K.focusOptions));
    });
    _scroll();
  }

  /// "Show other options": the next set if the user went back, otherwise a new set.
  Future<void> _nextFocusOptions() async {
    if (focusIndex < focusSets.length - 1) {
        _showFocusSet(focusIndex + 1);
        return;
      }
    await _loadFocusOptions();
  }

  Future<void> _loadFocusOptions() async {
    setState(() {
      busy = true;
      items.removeWhere((i) => i.kind == _K.focusOptions);
      items.add(_Item(_K.loading));
    });
    _scroll();
    final shown = focusSets.expand((e) => e).map((e) => e['title']).toList();
    final r = await Coach.task('focus_options', {'wish': s.wish, 'reason': s.reason, 'vision': '${s.visionHeadline} ${s.visionBody}', 'already_shown': shown});
    final list = (r?['options'] is List) ? (r!['options'] as List) : [];
    var opts = list
        .whereType<Map>()
        .map((m) => {'title': '${m['title'] ?? ''}', 'why': '${m['why'] ?? ''}'})
        .where((m) => m['title']!.isNotEmpty)
        .take(3)
        .toList();
    if (opts.isEmpty && focusSets.isEmpty) {
      opts = [
        {'title': 'Build healthier dinners into my workweek.', 'why': 'Evenings are often where good intentions slip.'},
        {'title': 'Move for 10 minutes most days.', 'why': 'Small and repeatable beats big and occasional.'},
        {'title': 'Cut down on evening snacking.', 'why': 'A small change at a tricky time of day.'},
      ];
    }
    if (!mounted) return;
    if (opts.isEmpty) {
      setState(() {
        busy = false;
        items.removeWhere((i) => i.kind == _K.loading);
      });
      toast(context, "Couldn't reach the coach. Try again in a moment.");
      {
        _showFocusSet(focusIndex);
        return;
      }
    }
    focusSets.add(opts);
    setState(() {
      busy = false;
      items.removeWhere((i) => i.kind == _K.loading);
    });
    _showFocusSet(focusSets.length - 1);
  }

  static final _optionRequest = RegExp(
      r"\boptions?\b|\bprevious\b|\bearlier\b|\bgo back\b|\bfirst ones\b|\blast ones\b|^(show|can i see|more|other|different|something else|another)\b|\b(more|other|different|new) (ideas|ones|choices|suggestions)\b",
      caseSensitive: false);

  /// R6: typed text in the focus step. Requests like "show previous options" are handled, never saved
  /// as the focus; anything else is confirmed before it becomes the 30-Day Focus.
  Future<void> _focusTyped(String text) async {
    final t = text.trim();
    if (_optionRequest.hasMatch(t) && t.split(RegExp(r'\s+')).length <= 10) {
      final back = RegExp(r'previous|earlier|go back|first|last ones|before', caseSensitive: false).hasMatch(t);
      if (back && focusIndex > 0) {
        setState(() => _coach('Here are the earlier options.'));
        {
        _showFocusSet(focusIndex - 1);
        return;
      }
      }
      if (back) {
        setState(() => _coach('These are the first options I suggested.'));
        {
        _showFocusSet(focusIndex);
        return;
      }
      }
      setState(() => _coach('Here are some other options.'));
      return _nextFocusOptions();
    }
    setState(() {
      pendingFocus = t;
      _coach('Use "$t" as your 30-Day Focus?');
      choices = const [QuickChoice('Yes, use this focus'), QuickChoice('No, show me the options again')];
      step = 'focus_confirm';
    });
    _scroll();
  }

  void _chooseFocus(String t) {
    if (busy) return;
    history.add(_snap());
    setState(() => items.add(_Item(_K.user, t)));
    _setFocus(t);
  }

  Future<void> _setFocus(String text) async {
    pendingFocus = '';
    s.focus = text.trim();
    s.focusStart = DateTime.now();
    await s.save();
    setState(() {
      items.removeWhere((i) => i.kind == _K.focusOptions);
    });
    await _pause();
    setState(() {
      _coach('Your 30-Day Focus: "${s.focus}"');
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
    if (r != null && r.trim().isNotEmpty) _chooseFocus(r.trim());
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
                    onPressed: () => _chooseFocus(focusOptions[i]['title']!),
                    child: const Text('Use this focus'),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(onPressed: () => _editFocus(focusOptions[i]['title']!), child: const Text('Edit')),
              ]),
            ]),
          ),
        Row(children: [
          if (focusIndex > 0) ...[
            Expanded(child: SoftButton('Previous options', icon: Icons.arrow_back, onPressed: busy ? null : () => _showFocusSet(focusIndex - 1))),
            const SizedBox(width: 10),
          ],
          Expanded(child: SoftButton('Show other options', icon: Icons.refresh, onPressed: busy ? null : _nextFocusOptions)),
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
  Widget build(BuildContext context) => PopScope(
      canPop: history.isEmpty && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stepBack();
      },
      child: NavooScaffold(
        step: barStep,
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Row(children: const [NavooLogo(height: 26)])),
          Expanded(
            child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
              for (var i = 0; i < items.length; i++) _itemWidget(i),
              if (choices.isNotEmpty) ...[
                const SizedBox(height: 8),
                QuickChoices(choices, grid: gridChoices, onPick: (v) {
                  if (step == 'feel' || step == 'reward') {
                    final cur = input.text.trim();
                    input.text = cur.isEmpty ? v : '$cur, $v';
                    input.selection = TextSelection.collapsed(offset: input.text.length);
                  } else {
                    answer(v);
                  }
                }),
                if (step == 'feel' || step == 'reward') const Text('Tap a few, add your own words, then send.', style: T.small),
                if (step != 'feel' && step != 'reward')
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
      ));
}

/// Screen 14 — Your reward card.
class RewardCardScreen extends StatelessWidget {
  final bool onboarding;
  const RewardCardScreen({super.key, this.onboarding = true});
  @override
  Widget build(BuildContext context) => NavooScaffold(
        step: onboarding ? 4 : null,
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/images/reward_tea.jpg', height: 230, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 20),
          const Text('YOUR REWARDS', style: T.label),
          const SizedBox(height: 8),
          for (final r in AppState.I.rewards)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [const Icon(Icons.card_giftcard, color: NC.success, size: 20), const SizedBox(width: 10), Expanded(child: Text(r, style: T.h3))]),
            ),
          const SizedBox(height: 10),
          const Text("Straight after each Micro-Action, you'll choose one of these. You pick the reward for each Micro-Action, and you can always choose a different one.", style: T.sub),
          const SizedBox(height: 22),
          const Row(children: [
            _RewardWhy(Icons.bolt, NC.blueTint, NC.blue, 'Boosts\nmotivation'),
            _RewardWhy(Icons.favorite_border, NC.roseTint, NC.error, 'Makes it more\nenjoyable'),
            _RewardWhy(Icons.star_border, NC.sageTint, NC.success, 'Helps it\nstick'),
          ]),
          const SizedBox(height: 26),
          PrimaryButton('Save my rewards', testKey: const Key('reward_save'), onPressed: () => Navigator.pop(context, true)),
          const SizedBox(height: 12),
          SoftButton('Edit my rewards', onPressed: () async {
            final c = TextEditingController(text: AppState.I.rewards.join('\n'));
            final r = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: NC.bg,
                title: const Text('Your rewards', style: T.h3),
                content: TextField(controller: c, minLines: 3, maxLines: 8, autofocus: true, decoration: const InputDecoration(helperText: 'One reward per line')),
                actions: [FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save'))],
              ),
            );
            final list = (r ?? '').split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            if (list.isNotEmpty) {
              AppState.I.rewards = list.take(8).toList();
              AppState.I.reward = list.first;
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
        InfoCard(icon: Icons.track_changes, tint: NC.sageTint, iconColor: NC.success, label: 'Your Vision', title: s.visionHeadline),
        const SizedBox(height: 10),
        InfoCard(icon: Icons.event_available, label: 'Your 30-Day Focus', title: s.focus),
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
        InfoCard(icon: Icons.card_giftcard, tint: NC.sageTint, iconColor: NC.success, label: 'Your rewards', title: s.rewards.isEmpty ? s.reward : s.rewards.join(' · ')),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: NC.blueTint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.chat_bubble_outline, color: NC.blue),
            SizedBox(width: 12),
            Expanded(
                child: Text(
                    "Next, we'll choose small, realistic Micro-Actions towards your focus, one at a time. When real life gets in the way, talk to me and we'll adapt.",
                    style: T.body)),
          ]),
        ),
        const SizedBox(height: 20),
        PrimaryButton('Build my first Micro-Actions',
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
