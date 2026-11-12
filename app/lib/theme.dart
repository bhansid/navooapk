import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NC {
  static const navy = Color(0xFF16324F);
  static const blue = Color(0xFF2F6B8A);
  static const sage = Color(0xFF6FA58A);
  static const bg = Color(0xFFF7F8F6);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF172026);
  static const slate = Color(0xFF5D6972);
  static const border = Color(0xFFDDE3E5);
  static const success = Color(0xFF3F7D5A);
  static const warning = Color(0xFFB7791F);
  static const error = Color(0xFFB84A4A);
  static const blueTint = Color(0xFFE6EFF4);
  static const sageTint = Color(0xFFE8F1EC);
  static const warmTint = Color(0xFFFBF1E3);
  static const lilacTint = Color(0xFFEEECF6);
  static const roseTint = Color(0xFFF8E9E9);
}

ThemeData navooTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: NC.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: NC.blue, primary: NC.blue, surface: NC.bg),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: NC.text, displayColor: NC.navy, fontFamily: 'Inter'),
    appBarTheme: const AppBarTheme(
      backgroundColor: NC.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: NC.navy,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: NC.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: NC.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: NC.blue, width: 1.5)),
      hintStyle: const TextStyle(color: NC.slate),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? NC.success : NC.border),
    ),
  );
}

class T {
  static const h1 = TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w700, color: NC.navy, letterSpacing: -0.8);
  static const h2 = TextStyle(fontSize: 26, height: 1.15, fontWeight: FontWeight.w700, color: NC.navy, letterSpacing: -0.5);
  static const h3 = TextStyle(fontSize: 19, height: 1.25, fontWeight: FontWeight.w600, color: NC.navy);
  static const body = TextStyle(fontSize: 16, height: 1.45, color: NC.text);
  static const sub = TextStyle(fontSize: 17, height: 1.4, color: NC.slate);
  static const small = TextStyle(fontSize: 14, height: 1.4, color: NC.slate);
  static const label = TextStyle(fontSize: 12, letterSpacing: 1.6, fontWeight: FontWeight.w600, color: NC.slate);
}

class NavooLogo extends StatelessWidget {
  final double height;
  const NavooLogo({super.key, this.height = 34});
  @override
  Widget build(BuildContext context) => Image.asset('assets/images/logo_full.png', height: height, semanticLabel: 'navoo');
}

class NavooMark extends StatelessWidget {
  final double size;
  final bool white;
  const NavooMark({super.key, this.size = 36, this.white = false});
  @override
  Widget build(BuildContext context) =>
      Image.asset(white ? 'assets/images/logo_mark_white.png' : 'assets/images/logo_mark.png', width: size, height: size);
}

class CoachAvatar extends StatelessWidget {
  final double size;
  const CoachAvatar({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: NC.blueTint, shape: BoxShape.circle),
        padding: EdgeInsets.all(size * 0.2),
        child: const NavooMark(),
      );
}

/// Primary button. [pressable3d] gives the chunky "real button" press used for Done.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool trailingArrow;
  final bool pressable3d;
  final bool busy;
  final Key? testKey;
  const PrimaryButton(this.label,
      {super.key, this.onPressed, this.icon, this.trailingArrow = false, this.pressable3d = false, this.busy = false, this.testKey});
  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final depth = widget.pressable3d ? 6.0 : 0.0;
    final content = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (widget.busy)
        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
      else ...[
        if (widget.icon != null) ...[Icon(widget.icon, color: Colors.white, size: 22), const SizedBox(width: 10)],
        Flexible(
            child: Text(widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))),
        if (widget.trailingArrow) ...[const SizedBox(width: 10), const Icon(Icons.arrow_forward, color: Colors.white, size: 22)],
      ]
    ]);
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        key: widget.testKey,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                if (widget.pressable3d) HapticFeedback.mediumImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 58 + depth,
          padding: EdgeInsets.only(top: _down ? depth : 0),
          child: Stack(children: [
            if (widget.pressable3d)
              Positioned.fill(
                top: depth,
                child: Container(decoration: BoxDecoration(color: NC.navy, borderRadius: BorderRadius.circular(18))),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 90),
              left: 0,
              right: 0,
              top: 0,
              height: 58,
              child: Container(
                decoration: BoxDecoration(
                  color: enabled ? NC.blue : NC.blue.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: content,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class SoftButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  const SoftButton(this.label, {super.key, this.onPressed, this.icon, this.outlined = false});
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54, minWidth: double.infinity),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            backgroundColor: outlined ? Colors.white : NC.blueTint,
            foregroundColor: NC.blue,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: outlined ? const BorderSide(color: NC.blue, width: 1.2) : BorderSide.none),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
          ]),
        ),
      );
}

class LinkText extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const LinkText(this.label, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => TextButton(
      onPressed: onTap,
      child: Text(label, style: const TextStyle(color: NC.blue, fontSize: 15.5, fontWeight: FontWeight.w500)));
}

/// Card with an icon bubble, small caps label, title and optional subtitle.
class InfoCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String? label;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const InfoCard(
      {super.key,
      required this.icon,
      required this.title,
      this.tint = NC.blueTint,
      this.iconColor = NC.blue,
      this.label,
      this.subtitle,
      this.trailing,
      this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: tint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (label != null) ...[Text(label!.toUpperCase(), style: T.label), const SizedBox(height: 4)],
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: NC.navy, height: 1.25)),
                  if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: T.small)],
                ]),
              ),
              if (trailing != null) trailing! else if (onTap != null) const Icon(Icons.chevron_right, color: NC.slate),
            ]),
          ),
        ),
      );
}

class StepBar extends StatelessWidget {
  final int step; // 1..total
  final int total;
  const StepBar(this.step, {super.key, this.total = 5});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            total,
            (i) => Container(
                  width: 34,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: i < step ? NC.blue : NC.border, borderRadius: BorderRadius.circular(4)),
                )),
      );
}

class NavooScaffold extends StatelessWidget {
  final Widget body;
  final int? step;
  final bool back;
  final List<Widget>? actions;
  final bool showLogo;
  const NavooScaffold({super.key, required this.body, this.step, this.back = true, this.actions, this.showLogo = true});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: back && Navigator.of(context).canPop()
              ? IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop())
              : null,
          title: step != null ? StepBar(step!) : null,
          centerTitle: true,
          actions: actions,
        ),
        body: SafeArea(top: false, child: body),
      );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: NC.navy));
}

/// Navoo "thinking" animation: the mark breathing with orbiting dots and rotating lines.
class NavooThinking extends StatefulWidget {
  final List<String> lines;
  const NavooThinking({super.key, this.lines = const [
    "Looking at what you've told me...",
    'Matching steps to your real day...',
    'Using behavioural science to make this easier...',
    'Keeping it small and doable...',
  ]});
  @override
  State<NavooThinking> createState() => _NavooThinkingState();
}

class _NavooThinkingState extends State<NavooThinking> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  int line = 0;
  @override
  void initState() {
    super.initState();
    c.addStatusListener((_) {});
    _tick();
  }

  Future<void> _tick() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 2200));
      if (mounted) setState(() => line = (line + 1) % widget.lines.length);
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 170,
              height: 170,
              child: AnimatedBuilder(
                animation: c,
                builder: (_, __) {
                  final t = c.value * 2 * 3.14159265;
                  final pulse = 1 + 0.06 * (1 + math.sin(t * 2)) / 2;
                  final dots = <Widget>[];
                  const colors = [NC.blue, NC.sage, Color(0xFFF2C14E)];
                  for (var i = 0; i < 3; i++) {
                    final a = t + i * 2.094;
                    dots.add(Positioned(
                      left: 85 + 70 * math.cos(a) - 7,
                      top: 85 + 70 * math.sin(a) - 7,
                      child: Container(width: 14, height: 14, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
                    ));
                  }
                  return Stack(children: [
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          width: 120 * pulse,
                          height: 120 * pulse,
                          decoration: BoxDecoration(color: NC.blueTint.withValues(alpha: 0.8), shape: BoxShape.circle),
                        ),
                      ),
                    ),
                    Center(child: Transform.scale(scale: pulse, child: const NavooMark(size: 64))),
                    ...dots,
                  ]);
                },
              ),
            ),
            const SizedBox(height: 26),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(widget.lines[line], key: ValueKey(line), textAlign: TextAlign.center, style: T.sub),
            ),
          ]),
        ),
      );
}
