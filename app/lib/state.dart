import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb_;

class ChatMsg {
  final String role; // user | assistant
  final String text;
  final DateTime at;
  ChatMsg(this.role, this.text, [DateTime? at]) : at = at ?? DateTime.now();
  Map<String, dynamic> toJson() => {'role': role, 'text': text, 'at': at.toIso8601String()};
  static ChatMsg fromJson(Map<String, dynamic> j) => ChatMsg(j['role'] ?? 'user', j['text'] ?? '', DateTime.tryParse(j['at'] ?? ''));
}

class MicroAction {
  String id;
  String title;
  String description;
  String why;
  int minutes;
  String status; // locked | active | done
  String timing; // hour | today | days
  String ifCue;
  String thenDo;
  String backupIf;
  String backupThen;
  String setup;
  String? feeling;
  DateTime? doneAt;
  int week;
  int triggerHour;
  int triggerMinute;
  MicroAction({
    required this.id,
    required this.title,
    this.description = '',
    this.why = '',
    this.minutes = 10,
    this.status = 'locked',
    this.timing = '',
    this.ifCue = '',
    this.thenDo = '',
    this.backupIf = '',
    this.backupThen = '',
    this.setup = '',
    this.feeling,
    this.doneAt,
    this.week = 1,
    this.triggerHour = -1,
    this.triggerMinute = 0,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'why': why,
        'minutes': minutes,
        'status': status,
        'timing': timing,
        'ifCue': ifCue,
        'thenDo': thenDo,
        'backupIf': backupIf,
        'backupThen': backupThen,
        'setup': setup,
        'feeling': feeling,
        'doneAt': doneAt?.toIso8601String(),
        'week': week,
        'triggerHour': triggerHour,
        'triggerMinute': triggerMinute,
      };
  static MicroAction fromJson(Map<String, dynamic> j) => MicroAction(
        id: j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        why: j['why'] ?? '',
        minutes: (j['minutes'] is num) ? (j['minutes'] as num).toInt() : 10,
        status: j['status'] ?? 'locked',
        timing: j['timing'] ?? '',
        ifCue: j['ifCue'] ?? '',
        thenDo: j['thenDo'] ?? '',
        backupIf: j['backupIf'] ?? '',
        backupThen: j['backupThen'] ?? '',
        setup: j['setup'] ?? '',
        feeling: j['feeling'],
        doneAt: DateTime.tryParse(j['doneAt'] ?? ''),
        week: (j['week'] is num) ? (j['week'] as num).toInt() : 1,
        triggerHour: (j['triggerHour'] is num) ? (j['triggerHour'] as num).toInt() : -1,
        triggerMinute: (j['triggerMinute'] is num) ? (j['triggerMinute'] as num).toInt() : 0,
      );
}

/// Everything Navoo knows about the user. Stored on the device.
class AppState extends ChangeNotifier {
  static final AppState I = AppState();

  // account
  String? email;
  String firstName = '';
  bool loggedIn = false;
  bool emailVerified = false;

  // blueprint
  bool onboarded = false;
  String wish = '';
  String reason = '';
  Map<String, String> visionAnswers = {};
  String visionHeadline = '';
  String visionBody = '';
  List<String> feelings = [];
  String identity = '';
  int visionImage = 1;
  String focus = '';
  DateTime? focusStart;
  String obstaclesText = '';
  List<String> obstaclesLogistical = [];
  List<String> obstaclesPsychological = [];
  String obstaclesSummary = '';
  String whyMatters = '';
  String reward = '';
  int reviewWeekday = DateTime.sunday;
  int reviewHour = 19;
  int reviewMinute = 0;
  DateTime? lastReview;
  int week = 1;

  // actions
  List<MicroAction> actions = [];

  // learning + chat
  List<String> learnings = [];
  List<ChatMsg> chat = [];
  String dailyTip = '';
  String dailyTipDate = '';

  // profile + health (optional)
  String age = '';
  String location = '';
  String occupation = '';
  String timeAvailability = '';
  String livingSituation = '';
  String? weightStartKg;
  String? weightNowKg;
  String targetWeightKg = '';
  String heightCm = '';
  String activity = '';
  String diet = '';
  String lifestyle = '';
  String? satisfaction;

  // settings
  bool notificationsOn = true;
  bool pauseNotifications = false;
  bool nudgeOwnWords = true;
  bool nudgeEncouragement = true;
  bool nudgeTips = true;
  bool nudgeProgress = true;
  bool nudgeWeekly = true;
  String nudgeFrequency = 'Once a day';
  int quietFrom = 22;
  int quietTo = 7;
  int nudgeHour = 9;
  bool personalisedCoaching = true;
  bool wellWater = false;
  bool wellStretch = false;
  bool wellWalk = false;
  String? photoPath;

  MicroAction? get currentAction {
    for (final a in actions) {
      if (a.status == 'active') return a;
    }
    return null;
  }

  List<MicroAction> get queue => actions.where((a) => a.status != 'done').toList();
  List<MicroAction> get done => actions.where((a) => a.status == 'done').toList();

  int get focusDay {
    if (focusStart == null) return 1;
    return DateTime.now().difference(focusStart!).inDays + 1;
  }

  /// When the user usually follows through, from completed actions.
  String? get bestTime {
    final hours = done.where((a) => a.doneAt != null).map((a) => a.doneAt!.hour).toList();
    if (hours.length < 2) return null;
    final buckets = <String, int>{'Mornings': 0, 'Afternoons': 0, 'Evenings': 0};
    for (final h in hours) {
      if (h < 12) {
        buckets['Mornings'] = buckets['Mornings']! + 1;
      } else if (h < 17) {
        buckets['Afternoons'] = buckets['Afternoons']! + 1;
      } else {
        buckets['Evenings'] = buckets['Evenings']! + 1;
      }
    }
    final best = buckets.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return '${best.key} (${best.value} of ${hours.length} actions)';
  }

  bool get focusComplete => focusStart != null && focusDay > 30;

  void activateNext() {
    if (currentAction != null) return;
    for (final a in actions) {
      if (a.status == 'locked') {
        a.status = 'active';
        break;
      }
    }
  }

  /// Compact profile sent to the coach so it remembers the person.
  Map<String, dynamic> coachProfile() => {
        'first_name': firstName,
        'wish': wish,
        'main_reason': reason,
        'vision': visionHeadline.isEmpty ? null : '$visionHeadline $visionBody',
        'vision_answers': visionAnswers,
        'identity': identity,
        'why_it_matters': whyMatters,
        'thirty_day_focus': focus,
        'focus_day': focusStart == null ? null : focusDay,
        'obstacles': {'said': obstaclesText, 'logistical': obstaclesLogistical, 'psychological': obstaclesPsychological},
        'reward': reward,
        'current_action': currentAction == null
            ? null
            : {
                'title': currentAction!.title,
                'if': currentAction!.ifCue,
                'then': currentAction!.thenDo,
                'backup_if': currentAction!.backupIf,
                'backup_then': currentAction!.backupThen,
                'setup': currentAction!.setup,
                'timing': currentAction!.timing,
              },
        'coming_next': actions.where((a) => a.status == 'locked').map((a) => a.title).toList(),
        'completed': done.map((a) => {'title': a.title, 'felt': a.feeling, 'week': a.week}).toList(),
        'learned_about_user': personalisedCoaching ? learnings : [],
        'basics': {
          'age': age,
          'location': location,
          'occupation': occupation,
          'time_availability': timeAvailability,
          'living_situation': livingSituation,
          'activity': activity,
          'diet_preferences': diet,
          'lifestyle': lifestyle,
        },
        'week_number': week,
        'best_time_to_act': bestTime,
      };

  void addLearnings(List<String> l) {
    for (final x in l) {
      final t = x.trim();
      if (t.isEmpty) continue;
      if (learnings.any((e) => e.toLowerCase() == t.toLowerCase())) continue;
      learnings.add(t);
    }
    if (learnings.length > 40) learnings = learnings.sublist(learnings.length - 40);
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'firstName': firstName,
        'loggedIn': loggedIn,
        'emailVerified': emailVerified,
        'onboarded': onboarded,
        'wish': wish,
        'reason': reason,
        'visionAnswers': visionAnswers,
        'visionHeadline': visionHeadline,
        'visionBody': visionBody,
        'feelings': feelings,
        'identity': identity,
        'visionImage': visionImage,
        'focus': focus,
        'focusStart': focusStart?.toIso8601String(),
        'obstaclesText': obstaclesText,
        'obstaclesLogistical': obstaclesLogistical,
        'obstaclesPsychological': obstaclesPsychological,
        'obstaclesSummary': obstaclesSummary,
        'whyMatters': whyMatters,
        'reward': reward,
        'reviewWeekday': reviewWeekday,
        'reviewHour': reviewHour,
        'reviewMinute': reviewMinute,
        'lastReview': lastReview?.toIso8601String(),
        'week': week,
        'actions': actions.map((a) => a.toJson()).toList(),
        'learnings': learnings,
        'chat': chat.length > 200 ? chat.sublist(chat.length - 200).map((m) => m.toJson()).toList() : chat.map((m) => m.toJson()).toList(),
        'dailyTip': dailyTip,
        'dailyTipDate': dailyTipDate,
        'age': age,
        'location': location,
        'occupation': occupation,
        'timeAvailability': timeAvailability,
        'livingSituation': livingSituation,
        'weightStartKg': weightStartKg,
        'weightNowKg': weightNowKg,
        'targetWeightKg': targetWeightKg,
        'heightCm': heightCm,
        'activity': activity,
        'diet': diet,
        'lifestyle': lifestyle,
        'satisfaction': satisfaction,
        'notificationsOn': notificationsOn,
        'pauseNotifications': pauseNotifications,
        'nudgeOwnWords': nudgeOwnWords,
        'nudgeEncouragement': nudgeEncouragement,
        'nudgeTips': nudgeTips,
        'nudgeProgress': nudgeProgress,
        'nudgeWeekly': nudgeWeekly,
        'nudgeFrequency': nudgeFrequency,
        'quietFrom': quietFrom,
        'quietTo': quietTo,
        'nudgeHour': nudgeHour,
        'personalisedCoaching': personalisedCoaching,
        'wellWater': wellWater,
        'wellStretch': wellStretch,
        'wellWalk': wellWalk,
        'photoPath': photoPath,
      };

  List<String> _ls(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

  void fromJson(Map<String, dynamic> j) {
    email = j['email'];
    firstName = j['firstName'] ?? '';
    loggedIn = j['loggedIn'] ?? false;
    emailVerified = j['emailVerified'] ?? false;
    onboarded = j['onboarded'] ?? false;
    wish = j['wish'] ?? '';
    reason = j['reason'] ?? '';
    visionAnswers = (j['visionAnswers'] is Map) ? Map<String, String>.from((j['visionAnswers'] as Map).map((k, v) => MapEntry('$k', '$v'))) : {};
    visionHeadline = j['visionHeadline'] ?? '';
    visionBody = j['visionBody'] ?? '';
    feelings = _ls(j['feelings']);
    identity = j['identity'] ?? '';
    visionImage = j['visionImage'] ?? 1;
    focus = j['focus'] ?? '';
    focusStart = DateTime.tryParse(j['focusStart'] ?? '');
    obstaclesText = j['obstaclesText'] ?? '';
    obstaclesLogistical = _ls(j['obstaclesLogistical']);
    obstaclesPsychological = _ls(j['obstaclesPsychological']);
    obstaclesSummary = j['obstaclesSummary'] ?? '';
    whyMatters = j['whyMatters'] ?? '';
    reward = j['reward'] ?? '';
    reviewWeekday = j['reviewWeekday'] ?? DateTime.sunday;
    reviewHour = j['reviewHour'] ?? 19;
    reviewMinute = j['reviewMinute'] ?? 0;
    lastReview = DateTime.tryParse(j['lastReview'] ?? '');
    week = j['week'] ?? 1;
    actions = (j['actions'] is List) ? (j['actions'] as List).map((e) => MicroAction.fromJson(Map<String, dynamic>.from(e))).toList() : [];
    learnings = _ls(j['learnings']);
    chat = (j['chat'] is List) ? (j['chat'] as List).map((e) => ChatMsg.fromJson(Map<String, dynamic>.from(e))).toList() : [];
    dailyTip = j['dailyTip'] ?? '';
    dailyTipDate = j['dailyTipDate'] ?? '';
    age = j['age'] ?? '';
    location = j['location'] ?? '';
    occupation = j['occupation'] ?? '';
    timeAvailability = j['timeAvailability'] ?? '';
    livingSituation = j['livingSituation'] ?? '';
    weightStartKg = j['weightStartKg'];
    weightNowKg = j['weightNowKg'];
    targetWeightKg = j['targetWeightKg'] ?? '';
    heightCm = j['heightCm'] ?? '';
    activity = j['activity'] ?? '';
    diet = j['diet'] ?? '';
    lifestyle = j['lifestyle'] ?? '';
    satisfaction = j['satisfaction'];
    notificationsOn = j['notificationsOn'] ?? true;
    pauseNotifications = j['pauseNotifications'] ?? false;
    nudgeOwnWords = j['nudgeOwnWords'] ?? true;
    nudgeEncouragement = j['nudgeEncouragement'] ?? true;
    nudgeTips = j['nudgeTips'] ?? true;
    nudgeProgress = j['nudgeProgress'] ?? true;
    nudgeWeekly = j['nudgeWeekly'] ?? true;
    nudgeFrequency = j['nudgeFrequency'] ?? 'Once a day';
    quietFrom = j['quietFrom'] ?? 22;
    quietTo = j['quietTo'] ?? 7;
    nudgeHour = j['nudgeHour'] ?? 9;
    personalisedCoaching = j['personalisedCoaching'] ?? true;
    wellWater = j['wellWater'] ?? false;
    wellStretch = j['wellStretch'] ?? false;
    wellWalk = j['wellWalk'] ?? false;
    photoPath = j['photoPath'];
  }

  // ---- persistence (one record per account email) ----
  static const _currentKey = 'navoo.current';
  String get _key => 'navoo.user.${(email ?? 'guest').toLowerCase()}';

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(toJson()));
    await p.setString(_currentKey, email ?? '');
    notifyListeners();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final cur = p.getString(_currentKey);
    if (cur == null || cur.isEmpty) return;
    final raw = p.getString('navoo.user.${cur.toLowerCase()}');
    if (raw == null) return;
    try {
      fromJson(jsonDecode(raw));
    } catch (_) {}
  }

  Future<bool> loadFor(String mail) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('navoo.user.${mail.toLowerCase()}');
    if (raw == null) return false;
    try {
      fromJson(jsonDecode(raw));
      return true;
    } catch (_) {
      return false;
    }
  }

  void resetMemory() {
    final keepEmail = email;
    final keepName = firstName;
    fromJson({});
    email = keepEmail;
    firstName = keepName;
  }

  Future<void> logout() async {
    try {
      await sb_.Supabase.instance.client.auth.signOut();
    } catch (_) {}
    loggedIn = false;
    await save();
    final p = await SharedPreferences.getInstance();
    await p.setString(_currentKey, '');
    fromJson({});
    notifyListeners();
  }

  Future<void> deleteEverything() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
    await p.remove('navoo.auth.${(email ?? '').toLowerCase()}');
    await p.setString(_currentKey, '');
    fromJson({});
    notifyListeners();
  }
}
