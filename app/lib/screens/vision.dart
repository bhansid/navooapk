import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../api.dart';
import '../device.dart';
import '../state.dart';
import '../theme.dart';

const visionImages = ['vision_1', 'vision_2', 'vision_3', 'hero_splash', 'hero_personal'];

/// The vision card the user saves, prints or sets as wallpaper. Rendered at phone proportions.
class VisionPoster extends StatelessWidget {
  final double width;
  const VisionPoster({super.key, required this.width});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final img = visionImages[(s.visionImage - 1).clamp(0, visionImages.length - 1)];
    final h = width * 2.05;
    final scale = width / 300;
    return SizedBox(
      width: width,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22 * scale),
        child: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/images/$img.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x0016324F), Color(0x2216324F), Color(0xE616324F)],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22 * scale, 26 * scale, 22 * scale, 26 * scale),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                NavooMark(size: 22 * scale, white: true),
                SizedBox(width: 6 * scale),
                Text('MY VISION', style: TextStyle(color: Colors.white, fontSize: 11 * scale, letterSpacing: 2, fontWeight: FontWeight.w600)),
              ]),
              const Spacer(),
              Text(s.visionHeadline,
                  style: TextStyle(color: Colors.white, fontSize: 26 * scale, height: 1.12, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
              SizedBox(height: 10 * scale),
              Text(s.visionBody, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13.5 * scale, height: 1.4)),
              if (s.feelings.isNotEmpty) ...[
                SizedBox(height: 14 * scale),
                Wrap(
                  spacing: 6 * scale,
                  runSpacing: 6 * scale,
                  children: s.feelings
                      .map((f) => Container(
                            padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                            child: Text(f, style: TextStyle(color: Colors.white, fontSize: 12 * scale, fontWeight: FontWeight.w500)),
                          ))
                      .toList(),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Screens 10/11 and 31/32 — your vision with save, wallpaper, print, share, edit and image choice.
class VisionCardScreen extends StatefulWidget {
  final bool onboarding;
  const VisionCardScreen({super.key, this.onboarding = false});
  @override
  State<VisionCardScreen> createState() => _VisionCardScreenState();
}

class _VisionCardScreenState extends State<VisionCardScreen> {
  final s = AppState.I;
  final key = GlobalKey();
  bool working = false;

  Future<void> _withImage(Future<void> Function(Uint8List png) f) async {
    setState(() => working = true);
    final png = await Device.capture(key, pixelRatio: 3.6);
    if (png == null) {
      if (mounted) toast(context, 'Could not create the image. Please try again.');
    } else {
      await f(png);
    }
    if (mounted) setState(() => working = false);
  }

  Future<void> download() => _withImage((png) async {
        final err = await Device.saveToGallery(png);
        if (mounted) toast(context, err ?? 'Saved to your photos.');
      });

  Future<void> wallpaper() async {
    final where = Theme.of(context).platform == TargetPlatform.android
        ? await showModalBottomSheet<int>(
            context: context,
            backgroundColor: NC.bg,
            builder: (_) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Padding(padding: EdgeInsets.all(20), child: Text('Set as wallpaper', style: T.h3)),
                ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Lock screen'), onTap: () => Navigator.pop(context, 2)),
                ListTile(leading: const Icon(Icons.home_outlined), title: const Text('Home screen'), onTap: () => Navigator.pop(context, 1)),
                ListTile(leading: const Icon(Icons.smartphone), title: const Text('Both'), onTap: () => Navigator.pop(context, 3)),
                const SizedBox(height: 12),
              ]),
            ),
          )
        : 3;
    if (where == null) return;
    await _withImage((png) async {
      final r = await Device.setWallpaper(png, where);
      if (!mounted) return;
      if (r == 'done') {
        toast(context, 'Your vision is now your wallpaper.');
      } else if (r == 'ios-saved') {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: NC.bg,
            title: const Text('Saved to Photos', style: T.h3),
            content: const Text(
                'iPhone doesn\'t let apps change the wallpaper directly. To set it:\n\n1. Open Photos and find your vision.\n2. Tap Share, then "Use as Wallpaper".\n3. Choose Lock Screen.',
                style: T.body),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
          ),
        );
      } else {
        toast(context, r);
      }
    });
  }

  Future<void> printIt() => _withImage((png) => Device.printImage(png, 'My Navoo vision'));
  Future<void> share() => _withImage((png) => Device.shareImage(png, 'My vision'));

  Future<void> edit() async {
    final h = TextEditingController(text: s.visionHeadline), b = TextEditingController(text: s.visionBody);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NC.bg,
        title: const Text('Edit your vision', style: T.h3),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: h, decoration: const InputDecoration(labelText: 'Headline'), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: b, decoration: const InputDecoration(labelText: 'In your words'), maxLines: 5),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        s.visionHeadline = h.text.trim();
        s.visionBody = b.text.trim();
      });
      await s.save();
    }
  }

  Future<void> rewrite() async {
    setState(() => working = true);
    final r = await Coach.task('vision', {'wish': s.wish, 'reason': s.reason, ...s.visionAnswers, 'previous_version': s.visionHeadline});
    if (r != null) {
      s.visionHeadline = '${r['headline'] ?? s.visionHeadline}';
      s.visionBody = '${r['body'] ?? s.visionBody}';
      if (r['feelings'] is List) s.feelings = List<String>.from((r['feelings'] as List).map((e) => '$e')).take(3).toList();
      await s.save();
    } else if (mounted) {
      toast(context, "Couldn't reach the coach. Try again in a moment.");
    }
    if (mounted) setState(() => working = false);
  }

  void nextImage() {
    setState(() => s.visionImage = s.visionImage % visionImages.length + 1);
    s.save();
  }

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 48).clamp(200.0, 420.0) * 0.86;
    return NavooScaffold(
      step: widget.onboarding ? 2 : null,
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
        Text(widget.onboarding ? "Here's the bigger change you're working towards." : 'Your Vision', style: widget.onboarding ? T.h2 : T.h1),
        const SizedBox(height: 6),
        const Text('Keep it somewhere you will see it every day.', style: T.sub),
        const SizedBox(height: 18),
        Center(child: RepaintBoundary(key: key, child: VisionPoster(width: w))),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton.icon(onPressed: working ? null : nextImage, icon: const Icon(Icons.image_outlined), label: const Text('Try another image')),
          TextButton.icon(onPressed: working ? null : edit, icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
        ]),
        if (!widget.onboarding)
          Center(child: TextButton.icon(onPressed: working ? null : rewrite, icon: const Icon(Icons.refresh), label: const Text('Regenerate wording'))),
        const SizedBox(height: 8),
        PrimaryButton('Download image', icon: Icons.download, busy: working, onPressed: download, testKey: const Key('vision_download')),
        const SizedBox(height: 10),
        SoftButton('Set as wallpaper', icon: Icons.wallpaper, onPressed: working ? null : wallpaper),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: SoftButton('Print', icon: Icons.print_outlined, onPressed: working ? null : printIt)),
          const SizedBox(width: 10),
          Expanded(child: SoftButton('Share', icon: Icons.ios_share, onPressed: working ? null : share)),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: NC.sageTint, borderRadius: BorderRadius.circular(18)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.science_outlined, color: NC.success),
            SizedBox(width: 12),
            Expanded(child: Text('Seeing your vision often keeps it front of mind, so you notice more chances to act on it.', style: T.body)),
          ]),
        ),
        const SizedBox(height: 18),
        if (widget.onboarding)
          PrimaryButton('Save vision', trailingArrow: true, testKey: const Key('vision_save'), onPressed: () async {
            await s.save();
            if (context.mounted) Navigator.pop(context);
          })
        else
          VisionDetails(onChanged: () => setState(() {})),
      ]),
    );
  }
}

/// Feelings, identity and current focus shown under the vision (Wider Vision area).
class VisionDetails extends StatelessWidget {
  final VoidCallback onChanged;
  const VisionDetails({super.key, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (s.feelings.isNotEmpty) ...[
        const Text('HOW I WANT TO FEEL', style: T.label),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: s.feelings
                .map((f) => Chip(label: Text(f), backgroundColor: NC.warmTint, side: BorderSide.none, shape: const StadiumBorder()))
                .toList()),
        const SizedBox(height: 14),
      ],
      if (s.identity.isNotEmpty) ...[
        InfoCard(icon: Icons.person_outline, tint: NC.lilacTint, iconColor: const Color(0xFF7A62B8), label: 'How I want to show up', title: s.identity),
        const SizedBox(height: 10),
      ],
      if (s.whyMatters.isNotEmpty) ...[
        InfoCard(icon: Icons.menu_book_outlined, tint: NC.warmTint, iconColor: NC.warning, label: 'Why this matters', title: s.whyMatters),
        const SizedBox(height: 10),
      ],
      InfoCard(icon: Icons.track_changes, label: 'Current focus', title: s.focus),
    ]);
  }
}
