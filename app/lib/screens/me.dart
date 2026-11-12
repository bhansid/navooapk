import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../api.dart';
import '../device.dart';
import '../state.dart';
import '../theme.dart';
import 'blueprint.dart';
import 'shell.dart';
import 'start.dart';
import 'vision.dart';

/// Screen 28 — Me.
class MeTab extends StatefulWidget {
  const MeTab({super.key});
  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  final s = AppState.I;
  @override
  void initState() {
    super.initState();
    s.addListener(_c);
  }

  @override
  void dispose() {
    s.removeListener(_c);
    super.dispose();
  }

  void _c() {
    if (mounted) setState(() {});
  }

  void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 28), children: [
          const Text('Your profile', style: T.h1),
          const SizedBox(height: 6),
          const Text('Your details help Navoo give you more personalised support.', style: T.sub),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: NC.blueTint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: NC.blue,
                child: Text(s.firstName.isEmpty ? '?' : s.firstName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.firstName.isEmpty ? 'You' : s.firstName, style: T.h2),
                  Text(s.email ?? '', style: T.small),
                ]),
              ),
              IconButton(tooltip: 'Edit profile', onPressed: () => go(const ProfileEditScreen()), icon: const Icon(Icons.edit_outlined, color: NC.blue)),
            ]),
          ),
          const SizedBox(height: 12),
          InfoCard(
              icon: Icons.spa_outlined,
              tint: NC.sageTint,
              iconColor: NC.success,
              label: 'Your bigger picture',
              title: s.visionHeadline,
              onTap: () => go(const VisionCardScreen())),
          const SizedBox(height: 10),
          InfoCard(icon: Icons.track_changes, label: 'Current 30-day focus', title: s.focus, onTap: () => go(const FocusScreen())),
          const SizedBox(height: 18),
          _row(Icons.person_outline, 'Basic information', () => go(const ProfileEditScreen())),
          _row(Icons.monitor_heart_outlined, 'Health & lifestyle', () => go(const HealthScreen())),
          _row(Icons.notifications_none, 'Nudges & notifications', () => go(const NudgeSettingsScreen())),
          _row(Icons.event_note, 'Weekly check-in time', () => go(const CheckInSetupScreen())),
          _row(Icons.manage_accounts_outlined, 'Account', () => go(const AccountScreen())),
          _row(Icons.shield_outlined, 'Privacy & AI', () => go(const PrivacyScreen())),
          _row(Icons.science_outlined, 'The science behind Navoo', () => showScienceSheet(context)),
          const SizedBox(height: 8),
          SoftButton('Log out', icon: Icons.logout, outlined: true, onPressed: () async {
            await s.logout();
            if (context.mounted) goReplaceAll(context, const SplashScreen());
          }),
        ]),
      );

  Widget _row(IconData icon, String title, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Icon(icon, color: NC.blue),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: NC.navy)),
            trailing: const Icon(Icons.chevron_right, color: NC.slate),
            onTap: onTap,
          ),
        ),
      );
}

class _Form extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  final VoidCallback onSave;
  const _Form({required this.title, required this.subtitle, required this.children, required this.onSave});
  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
          Text(title, style: T.h1),
          const SizedBox(height: 6),
          Text(subtitle, style: T.sub),
          const SizedBox(height: 18),
          ...children,
          const SizedBox(height: 10),
          PrimaryButton('Save', onPressed: onSave),
        ]),
      );
}

Widget _tf(String label, TextEditingController c, {TextInputType? type, String? suffix}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, suffixText: suffix)),
    );

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final s = AppState.I;
  late final name = TextEditingController(text: s.firstName),
      age = TextEditingController(text: s.age),
      loc = TextEditingController(text: s.location),
      occ = TextEditingController(text: s.occupation),
      time = TextEditingController(text: s.timeAvailability),
      living = TextEditingController(text: s.livingSituation);
  @override
  Widget build(BuildContext context) => _Form(
        title: 'Basic information',
        subtitle: 'All optional. You can also just tell Navoo in the chat.',
        onSave: () async {
          s.firstName = name.text.trim();
          s.age = age.text.trim();
          s.location = loc.text.trim();
          s.occupation = occ.text.trim();
          s.timeAvailability = time.text.trim();
          s.livingSituation = living.text.trim();
          await s.save();
          if (context.mounted) Navigator.pop(context);
        },
        children: [
          _tf('First name', name),
          _tf('Age', age, type: TextInputType.number),
          _tf('Location', loc),
          _tf('Occupation', occ),
          _tf('Time you usually have', time),
          _tf('Living situation', living),
        ],
      );
}

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final s = AppState.I;
  late final weight = TextEditingController(text: s.weightNowKg ?? ''),
      target = TextEditingController(text: s.targetWeightKg),
      height = TextEditingController(text: s.heightCm),
      activity = TextEditingController(text: s.activity),
      diet = TextEditingController(text: s.diet),
      life = TextEditingController(text: s.lifestyle);
  @override
  Widget build(BuildContext context) => _Form(
        title: 'Your health & lifestyle',
        subtitle: "We'll keep this simple, and it's all optional. It helps Navoo give more relevant support.",
        onSave: () async {
          final w = double.tryParse(weight.text.replaceAll(',', '.'));
          if (w != null) {
            s.weightStartKg ??= w.toStringAsFixed(1);
            s.weightNowKg = w.toStringAsFixed(1);
          }
          s.targetWeightKg = target.text.trim();
          s.heightCm = height.text.trim();
          s.activity = activity.text.trim();
          s.diet = diet.text.trim();
          s.lifestyle = life.text.trim();
          await s.save();
          if (context.mounted) Navigator.pop(context);
        },
        children: [
          _tf('Current weight', weight, type: const TextInputType.numberWithOptions(decimal: true), suffix: 'kg'),
          _tf('Target weight', target, type: const TextInputType.numberWithOptions(decimal: true), suffix: 'kg'),
          _tf('Height', height, type: TextInputType.number, suffix: 'cm'),
          _tf('Activity level', activity),
          _tf('Dietary preferences', diet),
          _tf('Anything else about your lifestyle', life),
          InfoCard(
              icon: Icons.chat_bubble_outline,
              label: 'Prefer to share this in chat?',
              title: 'Tell Navoo about your health and lifestyle in a conversation instead.',
              onTap: () => openCoach(context, preset: "Here's a bit about my health and lifestyle: ")),
          const SizedBox(height: 10),
        ],
      );
}

/// Screens 33/34 + 38 — nudges and notifications in one place.
class NudgeSettingsScreen extends StatefulWidget {
  const NudgeSettingsScreen({super.key});
  @override
  State<NudgeSettingsScreen> createState() => _NudgeSettingsScreenState();
}

class _NudgeSettingsScreenState extends State<NudgeSettingsScreen> {
  final s = AppState.I;

  Future<void> _save() async {
    setState(() {});
    await s.save();
    await Device.reschedule();
  }

  Future<int?> _pickHour(int current) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: current, minute: 0));
    return t?.hour;
  }

  Widget _sw(String title, String sub, bool v, ValueChanged<bool> on) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: NC.navy)),
        subtitle: Text(sub, style: T.small),
        value: v,
        onChanged: (x) {
          on(x);
          _save();
        },
      );

  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
          const Text('Nudges & notifications', style: T.h1),
          const SizedBox(height: 6),
          const Text('Short, helpful nudges at the right time. Never nagging.', style: T.sub),
          const SizedBox(height: 14),
          _sw('Notifications', 'Allow Navoo to send nudges to this phone', s.notificationsOn, (v) async {
            s.notificationsOn = v;
            if (v) await Device.askNotificationPermission();
          }),
          _sw('Pause all nudges', 'Take a break. Turn them back on any time.', s.pauseNotifications, (v) => s.pauseNotifications = v),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reminder time', style: TextStyle(fontWeight: FontWeight.w500, color: NC.navy)),
            subtitle: Text(fmtTime(s.nudgeHour, 0), style: T.small),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final h = await _pickHour(s.nudgeHour);
              if (h != null) {
                s.nudgeHour = h;
                _save();
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('How often', style: TextStyle(fontWeight: FontWeight.w500, color: NC.navy)),
            subtitle: Text(s.nudgeFrequency, style: T.small),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final v = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: NC.bg,
                builder: (_) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final o in ['Once a day', 'Twice a day', 'A few times a week'])
                      ListTile(title: Text(o), trailing: s.nudgeFrequency == o ? const Icon(Icons.check, color: NC.blue) : null, onTap: () => Navigator.pop(context, o)),
                  ]),
                ),
              );
              if (v != null) {
                s.nudgeFrequency = v;
                _save();
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quiet hours', style: TextStyle(fontWeight: FontWeight.w500, color: NC.navy)),
            subtitle: Text('${fmtTime(s.quietFrom, 0)} – ${fmtTime(s.quietTo, 0)}', style: T.small),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final a = await _pickHour(s.quietFrom);
              if (a == null) return;
              final b = await _pickHour(s.quietTo);
              if (b == null) return;
              s.quietFrom = a;
              s.quietTo = b;
              _save();
            },
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('TYPES OF NUDGES', style: T.label)),
          _sw('Your own words', 'Your If/Then plan, played back at the right moment', s.nudgeOwnWords, (v) => s.nudgeOwnWords = v),
          _sw('Encouragement', 'A reminder of who you are becoming', s.nudgeEncouragement, (v) => s.nudgeEncouragement = v),
          _sw('Quick tips', 'Small tricks that make the next step easier', s.nudgeTips, (v) => s.nudgeTips = v),
          _sw('Progress insights', 'What Navoo has noticed about what works for you', s.nudgeProgress, (v) => s.nudgeProgress = v),
          _sw('Weekly check-in', 'A reminder at your chosen check-in time', s.nudgeWeekly, (v) => s.nudgeWeekly = v),
        ]),
      );
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return NavooScaffold(
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
        const Text('Account', style: T.h1),
        const SizedBox(height: 6),
        const Text('Manage your account in one place.', style: T.sub),
        const SizedBox(height: 18),
        InfoCard(icon: Icons.mail_outline, tint: NC.sageTint, iconColor: NC.success, label: 'Email', title: s.email ?? ''),
        const SizedBox(height: 10),
        InfoCard(
            icon: Icons.lock_outline,
            tint: NC.warmTint,
            iconColor: NC.warning,
            label: 'Password',
            title: 'Update your password',
            onTap: () async {
              final c = TextEditingController();
              final r = await showDialog<String>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: NC.bg,
                  title: const Text('New password', style: T.h3),
                  content: TextField(controller: c, obscureText: true, autofocus: true),
                  actions: [FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save'))],
                ),
              );
              if (r != null && r.length >= 6 && s.email != null) {
                if (Auth.remote) {
                  await Auth.sendReset(s.email!);
                  if (context.mounted) toast(context, "We've emailed you a link to set your new password.");
                } else {
                  await Auth.changePassword(s.email!, r);
                  if (context.mounted) toast(context, 'Password updated.');
                }
              } else if (r != null && context.mounted) {
                toast(context, 'Use at least 6 characters.');
              }
            }),
        const SizedBox(height: 10),
        InfoCard(
            icon: Icons.link,
            tint: NC.lilacTint,
            iconColor: const Color(0xFF7A62B8),
            label: 'Connected accounts',
            title: 'Email sign-in',
            subtitle: 'Google and Apple sign-in arrive in the next update.'),
        const SizedBox(height: 10),
        InfoCard(
            icon: Icons.delete_outline,
            tint: NC.roseTint,
            iconColor: NC.error,
            label: 'Delete account',
            title: 'Permanently delete your account',
            onTap: () => confirmDelete(context)),
        const SizedBox(height: 10),
        InfoCard(icon: Icons.logout, label: 'Log out', title: 'Sign out of your account', onTap: () async {
          await s.logout();
          if (context.mounted) goReplaceAll(context, const SplashScreen());
        }),
      ]),
    );
  }
}

Future<void> confirmDelete(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: NC.bg,
      title: const Text('Delete everything?', style: T.h3),
      content: const Text('This permanently deletes your account, your vision, your actions, your conversations and everything Navoo has learned about you. It cannot be undone.',
          style: T.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: NC.error), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok == true) {
    await AppState.I.deleteEverything();
    await Device.reschedule();
    if (context.mounted) goReplaceAll(context, const SplashScreen());
  }
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final s = AppState.I;

  Future<void> export() async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/navoo_my_data.json');
      await f.writeAsString(const JsonEncoder.withIndent('  ').convert(s.toJson()));
      await Device.shareFile(f.path, 'My Navoo data');
    } catch (_) {
      if (mounted) toast(context, 'Could not export your data.');
    }
  }

  void info(String title, String body) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => NavooScaffold(
              body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [Text(title, style: T.h1), const SizedBox(height: 14), Text(body, style: T.body)]))));

  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
          const Text('Privacy & AI', style: T.h1),
          const SizedBox(height: 6),
          const Text("You're in control of your data and how it's used.", style: T.sub),
          const SizedBox(height: 18),
          const Text('YOUR DATA', style: T.label),
          const SizedBox(height: 10),
          InfoCard(
              icon: Icons.verified_user_outlined,
              tint: NC.sageTint,
              iconColor: NC.success,
              title: 'How your data is used',
              onTap: () => info('How your data is used',
                  'Your vision, actions, check-ins and conversations are stored on this phone. When you talk to Navoo, the relevant parts are sent securely to our AI coach so it can reply in a way that fits you. Navoo is an AI coach, not a medical service, and its suggestions are not medical advice.\n\nIf you mention something that suggests you may be at risk, Navoo will share crisis support and may flag it privately to the Navoo team so they can follow up safely.')),
          const SizedBox(height: 10),
          InfoCard(icon: Icons.download_outlined, title: 'Export my data', subtitle: 'Download a copy of your data.', onTap: export),
          const SizedBox(height: 10),
          InfoCard(
              icon: Icons.delete_sweep_outlined,
              tint: NC.roseTint,
              iconColor: NC.error,
              title: 'Clear what Navoo has learned',
              subtitle: 'Removes learned patterns and conversations. Keeps your account.',
              onTap: () async {
                setState(() {
                  s.learnings.clear();
                  s.chat.clear();
                });
                await s.save();
                if (context.mounted) toast(context, 'Cleared.');
              }),
          const SizedBox(height: 18),
          const Text('AI PERSONALISATION', style: T.label),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Personalised coaching', style: TextStyle(fontWeight: FontWeight.w500, color: NC.navy)),
            subtitle: const Text('Navoo uses what you share and what it learns to make suggestions more relevant to you.', style: T.small),
            value: s.personalisedCoaching,
            onChanged: (v) async {
              setState(() => s.personalisedCoaching = v);
              await s.save();
            },
          ),
          const SizedBox(height: 12),
          const Text('LEGAL', style: T.label),
          const SizedBox(height: 10),
          InfoCard(
              icon: Icons.description_outlined,
              title: 'Terms',
              onTap: () => info('Terms', 'Navoo is in a test phase. Full terms of service will be published here before launch.')),
          const SizedBox(height: 10),
          InfoCard(
              icon: Icons.policy_outlined,
              tint: NC.sageTint,
              iconColor: NC.success,
              title: 'Privacy policy',
              onTap: () => info('Privacy policy', 'Navoo is in a test phase. The full privacy policy will be published here before launch.')),
          const SizedBox(height: 18),
          const Text('ACCOUNT', style: T.label),
          const SizedBox(height: 10),
          InfoCard(icon: Icons.delete_outline, tint: NC.roseTint, iconColor: NC.error, title: 'Delete account', subtitle: 'Permanently delete your account and all data.', onTap: () => confirmDelete(context)),
        ]),
      );
}
