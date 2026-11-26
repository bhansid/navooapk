import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb_;
import 'api.dart' show Auth;
import 'state.dart';

/// Keeps each user's data in navoo's Supabase (table user_state, one private row per user).
/// The phone keeps a copy so the app works offline; changes are pushed a few seconds after they happen,
/// and logging in on any phone brings everything back.
class Cloud {
  static Timer? _timer;
  static bool _applying = false;

  static sb_.SupabaseClient? get _client {
    if (!Auth.remote) return null;
    try {
      final c = sb_.Supabase.instance.client;
      return c.auth.currentUser == null ? null : c;
    } catch (_) {
      return null;
    }
  }

  static bool get signedIn => _client != null;

  static void schedulePush() {
    if (_applying || _client == null) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), pushNow);
  }

  static Future<void> pushNow() async {
    _timer?.cancel();
    final c = _client;
    final s = AppState.I;
    if (c == null || !s.loggedIn) return;
    try {
      await c.from('user_state').upsert({
        'user_id': c.auth.currentUser!.id,
        'email': s.email,
        'state': s.toJson(),
        'learnings': s.learnings,
        'updated_at': (s.updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      });
    } catch (_) {
      // Offline or server busy: the phone copy is safe and the next change pushes again.
    }
  }

  /// Brings the cloud copy down if it is newer than this phone's. Returns true if data was restored.
  static Future<bool> pull() async {
    final c = _client;
    if (c == null) return false;
    try {
      final row = await c.from('user_state').select('state, updated_at').eq('user_id', c.auth.currentUser!.id).maybeSingle();
      if (row == null || row['state'] is! Map) return false;
      final remoteAt = DateTime.tryParse('${row['updated_at']}');
      final localAt = AppState.I.updatedAt;
      if (localAt != null && remoteAt != null && !remoteAt.isAfter(localAt)) return false;
      _applying = true;
      AppState.I.fromJson(Map<String, dynamic>.from(row['state'] as Map));
      await AppState.I.saveLocal();
      return true;
    } catch (_) {
      return false;
    } finally {
      _applying = false;
    }
  }

  /// Deletes the cloud record and the login itself.
  static Future<void> deleteRemote() async {
    final c = _client;
    if (c == null) return;
    try {
      await c.from('user_state').delete().eq('user_id', c.auth.currentUser!.id);
      await c.rpc('delete_me');
    } catch (_) {}
  }
}
