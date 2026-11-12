import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'state.dart';

class Device {
  static const _channel = MethodChannel('navoo/device');
  static final _notes = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
      await _notes.initialize(const InitializationSettings(android: android, iOS: ios));
      _ready = true;
    } catch (_) {}
  }

  static Future<bool> askNotificationPermission() async {
    await init();
    try {
      final a = _notes.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (a != null) return await a.requestNotificationsPermission() ?? false;
      final i = _notes.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (i != null) return await i.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (_) {}
    return false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('navoo_nudges', 'Nudges',
        channelDescription: 'Gentle reminders for your next action', importance: Importance.defaultImportance),
    iOS: DarwinNotificationDetails(),
  );

  static tz.TZDateTime _next(int hour, int minute, {int? weekday}) {
    var d = DateTime.now();
    var t = DateTime(d.year, d.month, d.day, hour, minute);
    while (t.isBefore(d) || (weekday != null && t.weekday != weekday)) {
      t = t.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(t, tz.UTC);
  }

  static bool _quiet(int hour, AppState s) {
    if (s.quietFrom == s.quietTo) return false;
    if (s.quietFrom < s.quietTo) return hour >= s.quietFrom && hour < s.quietTo;
    return hour >= s.quietFrom || hour < s.quietTo;
  }

  /// Re-schedules every reminder from the current state. Safe to call often.
  static Future<void> reschedule({List<Map<String, String>> nudges = const []}) async {
    await init();
    final s = AppState.I;
    try {
      await _notes.cancelAll();
      if (!s.notificationsOn || s.pauseNotifications) return;
      final a = s.currentAction;
      final hours = <int>[];
      if (s.nudgeFrequency == 'Twice a day') {
        hours.addAll([s.nudgeHour, 18]);
      } else if (s.nudgeFrequency == 'A few times a week') {
        hours.add(s.nudgeHour);
      } else {
        hours.add(s.nudgeHour);
      }
      var id = 1;
      if (a != null) {
        final texts = <String>[];
        for (final n in nudges) {
          final type = n['type'] ?? '';
          if (type == 'own_words' && !s.nudgeOwnWords) continue;
          if (type == 'identity' && !s.nudgeEncouragement) continue;
          if ((type == 'meta' || type == 'friction') && !s.nudgeTips) continue;
          if ((n['text'] ?? '').isNotEmpty) texts.add(n['text']!);
        }
        if (texts.isEmpty && s.nudgeOwnWords && a.ifCue.isNotEmpty) texts.add('If ${a.ifCue}, then ${a.thenDo}.');
        if (texts.isEmpty) texts.add('Your next step: ${a.title}. It only takes a few minutes.');
        for (var i = 0; i < hours.length; i++) {
          final h = hours[i];
          if (_quiet(h, s)) continue;
          await _notes.zonedSchedule(
            id++,
            'Navoo',
            texts[i % texts.length],
            _next(h, 0),
            _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: s.nudgeFrequency == 'A few times a week' ? DateTimeComponents.dayOfWeekAndTime : DateTimeComponents.time,
          );
        }
      }
      if (s.nudgeWeekly && s.onboarded) {
        await _notes.zonedSchedule(
          100,
          'Your weekly check-in',
          'Ten minutes to look at what worked and adjust what comes next.',
          _next(s.reviewHour, s.reviewMinute, weekday: s.reviewWeekday),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (_) {}
  }

  static Future<bool> addWeeklyCheckInToCalendar() async {
    final s = AppState.I;
    final start = _next(s.reviewHour, s.reviewMinute, weekday: s.reviewWeekday).toLocal();
    final event = Event(
      title: 'Navoo weekly check-in',
      description: 'Ten minutes with Navoo: what worked, what got in the way, and what to adjust next.',
      startDate: start,
      endDate: start.add(const Duration(minutes: 10)),
      recurrence: Recurrence(frequency: Frequency.weekly),
    );
    try {
      return await Add2Calendar.addEvent2Cal(event);
    } catch (_) {
      return false;
    }
  }

  /// Renders a widget behind a RepaintBoundary to PNG bytes.
  static Future<Uint8List?> capture(GlobalKey key, {double pixelRatio = 3}) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> saveToGallery(Uint8List png) async {
    try {
      final ok = await Gal.hasAccess(toAlbum: true) || await Gal.requestAccess(toAlbum: true);
      if (!ok) return 'Please allow access to Photos to save your vision.';
      await Gal.putImageBytes(png, name: 'navoo_vision_${DateTime.now().millisecondsSinceEpoch}', album: 'Navoo');
      return null;
    } catch (e) {
      return 'Could not save the image.';
    }
  }

  /// Android: sets the wallpaper directly. iPhone: not allowed by Apple, so we save to Photos instead.
  /// [where]: 1 home, 2 lock, 3 both.
  static Future<String> setWallpaper(Uint8List png, int where) async {
    if (Platform.isAndroid) {
      try {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/navoo_wallpaper.png');
        await f.writeAsBytes(png);
        final ok = await _channel.invokeMethod<bool>('setWallpaper', {'path': f.path, 'where': where});
        return ok == true ? 'done' : 'Could not set the wallpaper.';
      } catch (_) {
        return 'Could not set the wallpaper.';
      }
    }
    final err = await saveToGallery(png);
    return err ?? 'ios-saved';
  }

  static Future<void> printImage(Uint8List png, String title) async {
    final doc = pw.Document(title: title);
    final img = pw.MemoryImage(png);
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (c) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain))));
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: title);
  }

  static Future<void> shareImage(Uint8List png, String text) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/navoo_vision.png');
    await f.writeAsBytes(png);
    await Share.shareXFiles([XFile(f.path)], text: text);
  }

  static Future<void> shareFile(String path, String text) async {
    await Share.shareXFiles([XFile(path)], text: text);
  }
}
