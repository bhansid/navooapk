import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../state.dart';
import '../theme.dart';
import 'blueprint.dart';
import 'shell.dart';

void goReplaceAll(BuildContext context, Widget page) {
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (_) => false);
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool coach;
  const _Bubble(this.text, {required this.coach});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        coach
            ? const CoachAvatar(size: 44)
            : Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: NC.blueTint, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Color(0xFF7FA3B9))),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: coach ? const Color(0xFFDCEBF6) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Text(text, style: const TextStyle(fontSize: 15.5, height: 1.35, color: NC.text)),
          ),
        ),
      ]);
}

/// Screen 1 — approved Navoo splash with rotating example conversations.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const pairs = [
    ["I'm struggling today.", "That's okay. Let's spot what's getting in the way, then make your next step easier."],
    ["I missed yesterday.", "That's useful to know. What got in the way? We'll adjust, not start over."],
    ["I'll start properly on Monday.", "You don't need to wait. What's one small thing that feels doable right now?"],
  ];
  int i = 0;
  Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 4), (_) => setState(() => i = (i + 1) % pairs.length));
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEDF4FA), NC.bg])),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 150,
          height: MediaQuery.of(context).size.height * 0.42,
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black], stops: [0, 0.25]).createShader(r),
            blendMode: BlendMode.dstIn,
            child: Image.asset('assets/images/hero_splash.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const NavooLogo(height: 38),
              const SizedBox(height: 30),
              const Text('Your Goals,\nMade Doable.', style: TextStyle(fontSize: 40, height: 1.08, fontWeight: FontWeight.w700, color: NC.navy, letterSpacing: -1)),
              const SizedBox(height: 14),
              const Text('Personalised support. Practical advice. Lasting change.', style: T.sub),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Column(key: ValueKey(i), children: [
                  _Bubble(pairs[i][0], coach: false),
                  const SizedBox(height: 10),
                  _Bubble(pairs[i][1], coach: true),
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  _Trust(Icons.psychology_outlined, NC.sageTint, NC.success, 'Backed by\nbehavioural science'),
                  _Trust(Icons.favorite_border, NC.warmTint, NC.warning, 'Personalised\nto your life'),
                  _Trust(Icons.bar_chart_rounded, NC.blueTint, NC.blue, 'Small steps.\nLasting change.'),
                ]),
              ),
              const SizedBox(height: 14),
              PrimaryButton('Get started',
                  testKey: const Key('splash_get_started'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Trust extends StatelessWidget {
  final IconData icon;
  final Color tint, color;
  final String text;
  const _Trust(this.icon, this.tint, this.color, this.text);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: tint, shape: BoxShape.circle), child: Icon(icon, color: color)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: NC.navy, height: 1.25)),
        ]),
      );
}

/// Screen 2 — Welcome.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                NavooLogo(height: 32),
                SizedBox(height: 26),
                Text('You know what you want to change. Navoo helps you actually do it.', style: T.h1),
                SizedBox(height: 14),
                Text('An AI behaviour-change coach that gets to know you, helps you work out what to do next, and adapts when real life gets in the way.',
                    style: T.sub),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: Image.asset('assets/images/hero_welcome.jpg', fit: BoxFit.cover, width: double.infinity, alignment: Alignment.topCenter)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Column(children: [
                PrimaryButton('Get started',
                    trailingArrow: true,
                    testKey: const Key('welcome_get_started'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAccountScreen()))),
                const SizedBox(height: 12),
                SoftButton('I already have an account',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()))),
              ]),
            ),
          ),
        ]),
      );
}

class _Field extends StatefulWidget {
  final TextEditingController c;
  final String hint;
  final IconData icon;
  final bool password;
  final TextInputType? type;
  final Key? fieldKey;
  const _Field(this.c, this.hint, this.icon, {this.password = false, this.type, this.fieldKey});
  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool hide = true;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          key: widget.fieldKey,
          controller: widget.c,
          obscureText: widget.password && hide,
          keyboardType: widget.type,
          autocorrect: !widget.password,
          textCapitalization: widget.hint == 'First name' ? TextCapitalization.words : TextCapitalization.none,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon, color: NC.slate),
            suffixIcon: widget.password
                ? IconButton(
                    tooltip: hide ? 'Show password' : 'Hide password',
                    icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: NC.slate),
                    onPressed: () => setState(() => hide = !hide))
                : null,
          ),
        ),
      );
}

class _SocialRow extends StatelessWidget {
  const _SocialRow();
  @override
  Widget build(BuildContext context) => Column(children: [
        const Row(children: [
          Expanded(child: Divider(color: NC.border)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or continue with', style: T.small)),
          Expanded(child: Divider(color: NC.border)),
        ]),
        const SizedBox(height: 14),
        _social(context, Icons.g_mobiledata, 'Continue with Google'),
      ]);

  Widget _social(BuildContext context, IconData icon, String label) => SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: NC.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          icon: Icon(icon, size: 28, color: NC.text),
          label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: NC.text)),
          onPressed: () async {
            if (icon == Icons.apple) {
              toast(context, 'Sign in with Apple arrives with the iPhone version.');
              return;
            }
            final r = await Auth.google();
            if (!context.mounted) return;
            if (r == null || r.$1.isEmpty) {
              toast(context, 'Google sign-in was cancelled.');
              return;
            }
            await _enterApp(context, r.$1, name: r.$2.isEmpty ? null : r.$2);
          },
        ),
      );
}

bool _validEmail(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e.trim());

Future<void> _enterApp(BuildContext context, String email, {String? name}) async {
  final s = AppState.I;
  final had = await s.loadFor(email);
  if (!had) {
    s.fromJson({});
  }
  s.email = email.trim().toLowerCase();
  if (name != null && name.trim().isNotEmpty) s.firstName = name.trim();
  s.loggedIn = true;
  s.emailVerified = true;
  await s.save();
  if (!context.mounted) return;
  goReplaceAll(context, s.onboarded ? MainShell() : const PersonalIntroScreen());
}

/// Screen 3 — Create account.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});
  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final name = TextEditingController(), email = TextEditingController(), pw = TextEditingController();
  bool busy = false;
  String? err;

  Future<void> submit() async {
    setState(() => err = null);
    if (name.text.trim().isEmpty) return setState(() => err = 'Please add your first name.');
    if (!_validEmail(email.text)) return setState(() => err = 'Please enter a valid email.');
    if (pw.text.length < 6) return setState(() => err = 'Use at least 6 characters for your password.');
    setState(() => busy = true);
    final r = await Auth.signUp(name.text.trim(), email.text.trim(), pw.text);
    setState(() => busy = false);
    if (!r.ok) return setState(() => err = r.error);
    if (!mounted) return;
    if (r.needsVerification) {
      AppState.I.firstName = name.text.trim();
      Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email.text.trim(), name: name.text.trim(), password: pw.text)));
    } else {
      await _enterApp(context, email.text, name: name.text);
    }
  }

  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(28, 4, 28, 28), children: [
          const NavooLogo(height: 30),
          const SizedBox(height: 26),
          const Text('Create your account', style: T.h1),
          const SizedBox(height: 10),
          const Text("We'll use a few details to personalise your experience.", style: T.sub),
          const SizedBox(height: 26),
          _Field(name, 'First name', Icons.person_outline, fieldKey: const Key('signup_name')),
          _Field(email, 'Email', Icons.mail_outline, type: TextInputType.emailAddress, fieldKey: const Key('signup_email')),
          _Field(pw, 'Password', Icons.lock_outline, password: true, fieldKey: const Key('signup_password')),
          if (err != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err!, style: const TextStyle(color: NC.error))),
          const SizedBox(height: 6),
          PrimaryButton('Create account', trailingArrow: true, busy: busy, onPressed: submit, testKey: const Key('signup_submit')),
          const SizedBox(height: 22),
          const _SocialRow(),
          const SizedBox(height: 14),
          Center(
            child: LinkText('Already have an account? Log in',
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))),
          ),
        ]),
      );
}

/// Screen 4 — Check your email (shown when email verification is switched on).
class VerifyEmailScreen extends StatefulWidget {
  final String email, name, password;
  const VerifyEmailScreen({super.key, required this.email, required this.name, required this.password});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(28, 4, 28, 28), children: [
          const NavooLogo(height: 30),
          const SizedBox(height: 26),
          const Text('Check your email', style: T.h1),
          const SizedBox(height: 10),
          const Text("We've sent a verification link to your email address.", style: T.sub),
          const SizedBox(height: 26),
          Center(
            child: Container(
              width: 170,
              height: 170,
              decoration: const BoxDecoration(color: NC.sageTint, shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_read_outlined, size: 84, color: NC.success),
            ),
          ),
          const SizedBox(height: 26),
          InfoCard(icon: Icons.mail_outline, label: 'Verification link sent to', title: widget.email),
          const SizedBox(height: 18),
          PrimaryButton('Continue', trailingArrow: true, busy: busy, onPressed: () async {
            setState(() => busy = true);
            final r = await Auth.login(widget.email, widget.password);
            setState(() => busy = false);
            if (!context.mounted) return;
            if (r.ok) {
              await _enterApp(context, widget.email, name: widget.name);
            } else {
              toast(context, r.needsVerification ? 'Not verified yet. Tap the link in your email, then try again.' : (r.error ?? 'Please try again.'));
            }
          }),
          const SizedBox(height: 8),
          Center(
              child: LinkText('Resend email', onTap: () async {
            final ok = await Auth.resendVerification(widget.email);
            if (context.mounted) toast(context, ok ? 'Sent again. Check your inbox and spam folder.' : 'Could not resend just now.');
          })),
          Center(child: LinkText('Change email', onTap: () => Navigator.pop(context))),
        ]),
      );
}

/// Screen 5 — Log in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), pw = TextEditingController();
  bool busy = false;
  String? err;

  Future<void> submit() async {
    setState(() => err = null);
    if (!_validEmail(email.text)) return setState(() => err = 'Please enter a valid email.');
    if (pw.text.isEmpty) return setState(() => err = 'Please enter your password.');
    setState(() => busy = true);
    final r = await Auth.login(email.text.trim(), pw.text);
    setState(() => busy = false);
    if (!r.ok) return setState(() => err = r.error);
    if (mounted) await _enterApp(context, email.text);
  }

  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(28, 4, 28, 28), children: [
          const NavooLogo(height: 30),
          const SizedBox(height: 30),
          const Text('Welcome back', style: T.h1),
          const SizedBox(height: 10),
          const Text('Good to see you again.', style: T.sub),
          const SizedBox(height: 28),
          _Field(email, 'Email', Icons.mail_outline, type: TextInputType.emailAddress, fieldKey: const Key('login_email')),
          _Field(pw, 'Password', Icons.lock_outline, password: true, fieldKey: const Key('login_password')),
          Align(
              alignment: Alignment.centerRight,
              child: LinkText('Forgot password?',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordScreen())))),
          if (err != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err!, style: const TextStyle(color: NC.error))),
          const SizedBox(height: 6),
          PrimaryButton('Log in', trailingArrow: true, busy: busy, onPressed: submit, testKey: const Key('login_submit')),
          const SizedBox(height: 22),
          const _SocialRow(),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('New to Navoo?', style: T.small),
            LinkText('Create an account',
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CreateAccountScreen()))),
          ]),
        ]),
      );
}

/// Screen 6 — Reset password (two states).
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final email = TextEditingController();
  bool sent = false, busy = false;
  @override
  Widget build(BuildContext context) => NavooScaffold(
        body: ListView(padding: const EdgeInsets.fromLTRB(28, 4, 28, 28), children: [
          const NavooLogo(height: 30),
          const SizedBox(height: 28),
          if (!sent) ...[
            const Text('Reset your password', style: T.h1),
            const SizedBox(height: 10),
            const Text('Enter the email address linked to your account.', style: T.sub),
            const SizedBox(height: 26),
            _Field(email, 'Email', Icons.mail_outline, type: TextInputType.emailAddress),
            PrimaryButton('Send reset link', trailingArrow: true, busy: busy, onPressed: () async {
              if (!_validEmail(email.text)) return toast(context, 'Please enter a valid email.');
              setState(() => busy = true);
              await Auth.sendReset(email.text.trim());
              setState(() {
                busy = false;
                sent = true;
              });
            }),
          ] else ...[
            const Text('Check your email', style: T.h1),
            const SizedBox(height: 10),
            Text(
                Auth.remote
                    ? "If an account exists for this email, we've sent instructions to reset your password."
                    : 'In this test version accounts are kept on this phone, so no email is sent. Create a new account or contact the Navoo team.',
                style: T.sub),
            const SizedBox(height: 26),
            if (Auth.remote) InfoCard(icon: Icons.mail_outline, label: "We've sent a reset link to", title: email.text.trim()),
            const SizedBox(height: 18),
            SoftButton('Back to login', onPressed: () => Navigator.pop(context)),
          ],
        ]),
      );
}
