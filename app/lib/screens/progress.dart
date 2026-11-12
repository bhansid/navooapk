import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';

/// Screen 25 — Progress. Behaviour and learning, not streaks.
class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});
  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
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

  String get consistency {
    final now = DateTime.now();
    final thisWeek = s.done.where((a) => a.doneAt != null && now.difference(a.doneAt!).inDays < 7).length;
    final lastWeek = s.done.where((a) => a.doneAt != null && now.difference(a.doneAt!).inDays >= 7 && now.difference(a.doneAt!).inDays < 14).length;
    if (s.done.isEmpty) return 'Getting started';
    if (thisWeek > lastWeek) return 'Improving';
    if (thisWeek == 0) return 'Ready to pick up';
    return 'Steady';
  }

  Future<void> logWeight() async {
    final c = TextEditingController(text: s.weightNowKg ?? '');
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NC.bg,
        title: const Text('Log your weight', style: T.h3),
        content: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: 'kg'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save')),
        ],
      ),
    );
    final v = double.tryParse((r ?? '').replaceAll(',', '.'));
    if (v == null || v < 25 || v > 350) return;
    setState(() {
      s.weightStartKg ??= v.toStringAsFixed(1);
      s.weightNowKg = v.toStringAsFixed(1);
    });
    await s.save();
  }

  @override
  Widget build(BuildContext context) {
    final lastDone = s.done.isEmpty ? null : s.done.last;
    final good = s.done.where((a) => a.feeling == 'Good' || a.feeling == 'Great').length;
    double? change;
    if (s.weightStartKg != null && s.weightNowKg != null) {
      change = double.parse(s.weightNowKg!) - double.parse(s.weightStartKg!);
    }
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 28), children: [
        const Text('Your progress', style: T.h1),
        const SizedBox(height: 6),
        const Text('Small actions. Real learning.', style: T.sub),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _Stat(icon: Icons.check_circle_outline, tint: NC.sageTint, color: NC.success, label: 'Actions done', value: '${s.done.length}')),
          const SizedBox(width: 10),
          Expanded(child: _Stat(icon: Icons.bar_chart_rounded, tint: NC.blueTint, color: NC.blue, label: 'Consistency', value: consistency)),
        ]),
        const SizedBox(height: 12),
        if (lastDone != null) ...[
          InfoCard(
              icon: Icons.emoji_events_outlined,
              tint: NC.lilacTint,
              iconColor: const Color(0xFF7A62B8),
              label: 'Latest win',
              title: lastDone.title,
              subtitle: lastDone.feeling == null ? null : 'It felt: ${lastDone.feeling!.toLowerCase()}'),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: NC.warmTint.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.lightbulb_outline, color: NC.warning),
              SizedBox(width: 10),
              Text("WHAT I'VE LEARNED ABOUT MYSELF", style: T.label),
            ]),
            const SizedBox(height: 12),
            if (s.learnings.isEmpty)
              const Text('As you take actions and talk to Navoo, what helps you and what gets in the way will show up here.', style: T.body)
            else
              ...s.learnings.reversed.take(8).map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 7, color: NC.warning)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l, style: T.body)),
                    ]),
                  )),
          ]),
        ),
        const SizedBox(height: 12),
        if (s.bestTime != null) ...[
          InfoCard(icon: Icons.schedule, tint: NC.blueTint, iconColor: NC.blue, label: 'When I follow through best', title: s.bestTime!),
          const SizedBox(height: 12),
        ],
        if (s.obstaclesLogistical.isNotEmpty || s.obstaclesPsychological.isNotEmpty) ...[
          InfoCard(
              icon: Icons.warning_amber_rounded,
              tint: NC.roseTint,
              iconColor: NC.error,
              label: 'What tends to get in my way',
              title: [...s.obstaclesLogistical, ...s.obstaclesPsychological].take(4).join(' · ')),
          const SizedBox(height: 12),
        ],
        if (s.done.isNotEmpty) ...[
          InfoCard(
              icon: Icons.favorite_border,
              tint: NC.sageTint,
              iconColor: NC.success,
              label: 'What motivates me',
              title: s.reward.isEmpty ? s.whyMatters : 'Reward: ${s.reward}',
              subtitle: good > 0 ? '$good of your actions felt good or great.' : null),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: NC.blueTint.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('OUTCOME (OPTIONAL)', style: T.label),
            const SizedBox(height: 10),
            if (s.weightNowKg == null)
              const Text('You can log your weight if it helps. It is one measure among many, and always optional.', style: T.body)
            else
              Row(children: [
                Text('${s.weightNowKg} kg', style: T.h2),
                const SizedBox(width: 14),
                if (change != null && change.abs() >= 0.1)
                  Text('${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg since you started', style: T.small),
              ]),
            const SizedBox(height: 12),
            const Text("Progress isn't just a number. It's how you feel, what you do, and what you learn about yourself.", style: T.small),
            const SizedBox(height: 12),
            SoftButton(s.weightNowKg == null ? 'Log weight' : 'Update weight', icon: Icons.monitor_weight_outlined, onPressed: logWeight),
          ]),
        ),
        const SizedBox(height: 12),
        if (s.done.isNotEmpty) ...[
          const Text('COMPLETED', style: T.label),
          const SizedBox(height: 10),
          ...s.done.reversed.take(12).map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoCard(icon: Icons.check, tint: NC.sageTint, iconColor: NC.success, title: a.title, subtitle: 'Week ${a.week}'),
              )),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color tint, color;
  final String label, value;
  const _Stat({required this.icon, required this.tint, required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tint.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: tint, shape: BoxShape.circle), child: Icon(icon, color: color)),
          const Spacer(),
          Text(label.toUpperCase(), style: T.label),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: value.length > 6 ? 20 : 30, fontWeight: FontWeight.w700, color: NC.navy)),
        ]),
      );
}
