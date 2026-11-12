import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'state.dart';

const kApiBase = String.fromEnvironment('NAVOO_API', defaultValue: 'https://navoo-coach-api.netlify.app');
const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const kSupabaseAnon = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

class CoachReply {
  final String reply;
  final String safety;
  final bool outOfScope;
  final List<String> learnings;
  final bool failed;
  CoachReply(this.reply, {this.safety = 'none', this.outOfScope = false, this.learnings = const [], this.failed = false});
}

class Coach {
  static final _client = http.Client();
  static String get _user => AppState.I.email ?? 'guest';

  static Future<CoachReply> chat(List<ChatMsg> history) async {
    final s = AppState.I;
    try {
      final res = await _client
          .post(Uri.parse('$kApiBase/api/coach'),
              headers: {'content-type': 'application/json'},
              body: jsonEncode({
                'mode': 'chat',
                'userId': _user,
                'profile': s.coachProfile(),
                'messages': history.map((m) => {'role': m.role, 'text': m.text}).toList(),
              }))
          .timeout(const Duration(seconds: 45));
      final j = jsonDecode(res.body);
      if (res.statusCode == 200 && j['ok'] == true && (j['reply'] ?? '').toString().isNotEmpty) {
        final l = (j['learnings'] is List) ? (j['learnings'] as List).map((e) => e.toString()).toList() : <String>[];
        return CoachReply(j['reply'], safety: j['safety'] ?? 'none', outOfScope: j['out_of_scope'] == true, learnings: l);
      }
      return CoachReply(j['error']?.toString() ?? 'I couldn\'t reply just now. Please try again in a moment.', failed: true);
    } catch (_) {
      return CoachReply('I can\'t reach the coach right now. Check your connection and try again.', failed: true);
    }
  }

  /// Structured AI task. Returns null if the coach is unreachable so callers can use a fallback.
  static Future<Map<String, dynamic>?> task(String task, Map<String, dynamic> data) async {
    try {
      final res = await _client
          .post(Uri.parse('$kApiBase/api/coach'),
              headers: {'content-type': 'application/json'},
              body: jsonEncode({'mode': 'task', 'task': task, 'data': data, 'userId': _user, 'profile': AppState.I.coachProfile()}))
          .timeout(const Duration(seconds: 45));
      final j = jsonDecode(res.body);
      if (res.statusCode == 200 && j['ok'] == true && j['result'] is Map) return Map<String, dynamic>.from(j['result']);
    } catch (_) {}
    return null;
  }

  static Future<void> feedback(Map<String, dynamic> data) async {
    try {
      await _client
          .post(Uri.parse('$kApiBase/api/coach'),
              headers: {'content-type': 'application/json'}, body: jsonEncode({'mode': 'feedback', 'userId': _user, 'data': data}))
          .timeout(const Duration(seconds: 20));
    } catch (_) {}
  }
}

class AuthResult {
  final bool ok;
  final String? error;
  final bool needsVerification;
  AuthResult(this.ok, {this.error, this.needsVerification = false});
}

/// Accounts. Uses Supabase when configured at build time, otherwise accounts live on this phone.
class Auth {
  static bool get remote => kSupabaseUrl.isNotEmpty && kSupabaseAnon.isNotEmpty;

  static Map<String, String> get _h => {'apikey': kSupabaseAnon, 'content-type': 'application/json'};

  static String _hash(String email, String pw) => crypto.sha256.convert(utf8.encode('navoo:${email.toLowerCase()}:$pw')).toString();

  static Future<AuthResult> signUp(String name, String email, String pw) async {
    if (remote) {
      try {
        final r = await http.post(Uri.parse('$kSupabaseUrl/auth/v1/signup'),
            headers: _h, body: jsonEncode({'email': email, 'password': pw, 'data': {'first_name': name}}));
        final j = jsonDecode(r.body);
        if (r.statusCode >= 400) return AuthResult(false, error: (j['msg'] ?? j['error_description'] ?? 'Could not create account').toString());
        final verified = j['access_token'] != null;
        return AuthResult(true, needsVerification: !verified);
      } catch (_) {
        return AuthResult(false, error: 'No connection. Please try again.');
      }
    }
    final p = await SharedPreferences.getInstance();
    if (p.getString('navoo.auth.${email.toLowerCase()}') != null) {
      return AuthResult(false, error: 'An account with this email already exists. Try logging in.');
    }
    await p.setString('navoo.auth.${email.toLowerCase()}', _hash(email, pw));
    return AuthResult(true, needsVerification: false);
  }

  static Future<AuthResult> login(String email, String pw) async {
    if (remote) {
      try {
        final r = await http.post(Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
            headers: _h, body: jsonEncode({'email': email, 'password': pw}));
        final j = jsonDecode(r.body);
        if (r.statusCode >= 400) {
          final msg = (j['error_description'] ?? j['msg'] ?? '').toString();
          if (msg.toLowerCase().contains('confirm')) return AuthResult(false, error: 'Please verify your email first.', needsVerification: true);
          return AuthResult(false, error: 'Email or password is incorrect.');
        }
        return AuthResult(true);
      } catch (_) {
        return AuthResult(false, error: 'No connection. Please try again.');
      }
    }
    final p = await SharedPreferences.getInstance();
    final stored = p.getString('navoo.auth.${email.toLowerCase()}');
    if (stored == null) return AuthResult(false, error: 'No account found for this email. Create one below.');
    if (stored != _hash(email, pw)) return AuthResult(false, error: 'Email or password is incorrect.');
    return AuthResult(true);
  }

  static Future<bool> sendReset(String email) async {
    if (remote) {
      try {
        await http.post(Uri.parse('$kSupabaseUrl/auth/v1/recover'), headers: _h, body: jsonEncode({'email': email}));
      } catch (_) {}
    }
    return true;
  }

  static Future<bool> resendVerification(String email) async {
    if (!remote) return true;
    try {
      final r = await http.post(Uri.parse('$kSupabaseUrl/auth/v1/resend'),
          headers: _h, body: jsonEncode({'type': 'signup', 'email': email}));
      return r.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  static Future<void> changePassword(String email, String pw) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('navoo.auth.${email.toLowerCase()}', _hash(email, pw));
  }
}
