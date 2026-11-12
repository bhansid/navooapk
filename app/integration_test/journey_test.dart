import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:navoo/main.dart' as app;
import 'package:navoo/screens/chat_widgets.dart';
import 'package:navoo/screens/review.dart';
import 'package:navoo/screens/vision.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full Navoo journey', (t) async {
    var converted = false;
    final log = <String>[];

    Future<void> wait([int ms = 600]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(String name) async {
      await wait(700);
      if (Platform.isAndroid && !converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
        await wait(300);
      }
      await binding.takeScreenshot(name);
      log.add('shot $name');
    }

    Future<void> waitFor(Finder f, {int secs = 75}) async {
      for (var i = 0; i < secs * 5; i++) {
        await t.pump(const Duration(milliseconds: 200));
        if (f.evaluate().isNotEmpty) return;
      }
      throw TestFailure('Timed out waiting for $f. Steps so far: $log');
    }

    Future<void> tap(Finder f) async {
      await waitFor(f);
      await t.ensureVisible(f.first);
      await wait(300);
      await t.tap(f.first, warnIfMissed: false);
      await wait(500);
    }

    Future<void> type(Finder f, String text) async {
      await waitFor(f);
      await t.ensureVisible(f.first);
      await t.enterText(f.first, text);
      await wait(300);
    }

    Future<void> sendChat(String text) async {
      await type(find.byKey(const Key('chat_input')), text);
      await tap(find.byKey(const Key('chat_send')));
    }

    Future<void> waitCoachReply(int before) async {
      for (var i = 0; i < 90 * 5; i++) {
        await t.pump(const Duration(milliseconds: 200));
        if (find.byType(TypingBubble).evaluate().isEmpty && find.byType(ChatBubble).evaluate().length >= before + 2) return;
      }
      throw TestFailure('Coach did not reply. Steps: $log');
    }

    app.main();
    await wait(2500);
    await shot('01_splash');

    await tap(find.byKey(const Key('splash_get_started')));
    await shot('02_welcome');
    await tap(find.byKey(const Key('welcome_get_started')));
    await shot('03_create_account');
    await type(find.byKey(const Key('signup_name')), 'Sarah');
    await type(find.byKey(const Key('signup_email')), 'sarah${DateTime.now().millisecondsSinceEpoch}@example.com');
    await type(find.byKey(const Key('signup_password')), 'navoo123');
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.byKey(const Key('signup_submit')));
    await waitFor(find.byKey(const Key('intro_begin')));
    await shot('04_lets_make_this_personal');

    await tap(find.byKey(const Key('intro_begin')));
    await shot('05_wish');
    await tap(find.text('Lose weight and feel healthier'));
    await waitFor(find.text('I want to feel more confident'));
    await shot('06_reason');
    await tap(find.text('I want to feel more confident'));
    await waitFor(find.text('Lighter'));
    await tap(find.text('Lighter'));
    await tap(find.text('Confident'));
    await tap(find.text('Energetic'));
    await shot('07_vision_feel');
    await tap(find.byKey(const Key('chat_send')));
    await wait(1200);
    await sendChat('Stronger and healthier. Not a number on the scale.');
    await wait(1200);
    await sendChat('Keep up with my kids, travel more and be active without feeling tired.');
    await wait(1200);
    await sendChat('More present and confident, and I would stop avoiding photos.');
    await waitFor(find.byKey(const Key('vision_save')), secs: 90);
    await shot('08_vision_card');
    await tap(find.byKey(const Key('vision_save')));

    await waitFor(find.byKey(const Key('focus_use_0')), secs: 90);
    await shot('09_focus_options');
    await tap(find.byKey(const Key('focus_use_0')));
    await waitFor(find.text("I'm too tired after work"));
    await shot('10_obstacles');
    await tap(find.text("I'm too tired after work"));
    await waitFor(find.text('I order takeaway'));
    await tap(find.text('I order takeaway'));
    // identity + why (no chips): wait for the coach to finish, then answer
    for (var i = 0; i < 90 * 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
      if (find.byType(TypingBubble).evaluate().isEmpty && find.textContaining("person you're becoming").evaluate().isNotEmpty) break;
    }
    await shot('11_identity');
    await sendChat("Someone who takes their health seriously and has energy for their family.");
    await wait(1500);
    await sendChat('My kids. I want to keep up with them.');
    await waitFor(find.text('Tea or coffee'));
    await shot('12_reward_chat');
    await tap(find.text('Tea or coffee'));
    await waitFor(find.byKey(const Key('reward_save')));
    await shot('13_reward_card');
    await tap(find.byKey(const Key('reward_save')));
    await waitFor(find.byKey(const Key('summary_build')));
    await shot('14_bigger_picture');
    await tap(find.byKey(const Key('summary_build')));
    await waitFor(find.byKey(const Key('checkin_calendar')));
    await shot('15_weekly_checkin');
    await tap(find.text("I'll do this later"));
    await waitFor(find.byKey(const Key('steps_continue')), secs: 90);
    await shot('16_first_steps');
    await tap(find.byKey(const Key('steps_continue')));
    await type(find.byKey(const Key('if_cue')), 'I finish my morning coffee');
    await type(find.byKey(const Key('then_do')), "I'll save 3 healthy dinner recipes");
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('17_if_then');
    await tap(find.byKey(const Key('ifthen_lock')));
    await waitFor(find.byKey(const Key('ready_home')));
    await shot('18_ready');
    await tap(find.byKey(const Key('ready_home')));
    await waitFor(find.byKey(const Key('home_done')));
    await wait(8000);
    await shot('19_home');

    await tap(find.byKey(const Key('home_do_it')));
    await waitFor(find.byKey(const Key('detail_done')));
    await shot('20_action_detail');
    await tap(find.byKey(const Key('detail_done')));
    await waitFor(find.byKey(const Key('celebrate_continue')));
    await wait(400);
    await shot('21_celebration');
    await tap(find.byKey(const Key('feel_Good')));
    await tap(find.byKey(const Key('celebrate_continue')));
    await waitFor(find.byKey(const Key('claim_reward')));
    await shot('22_reward_ready');
    await tap(find.byKey(const Key('claim_reward')));
    await wait(1500);

    await tap(find.byKey(const Key('tab_coach')));
    await wait(800);
    var before = find.byType(ChatBubble).evaluate().length;
    await sendChat('I missed my walk yesterday because work ran late. I always mess this up.');
    await waitCoachReply(before);
    await shot('23_coach_setback');
    before = find.byType(ChatBubble).evaluate().length;
    await sendChat('Can you write me a Python script to sort a list?');
    await waitCoachReply(before);
    await shot('24_coach_out_of_scope');
    before = find.byType(ChatBubble).evaluate().length;
    await sendChat('Is it okay to eat late at night if I want to lose weight?');
    await waitCoachReply(before);
    await shot('25_coach_health_question');

    await tap(find.byKey(const Key('tab_progress')));
    await shot('26_progress');
    await tap(find.byKey(const Key('tab_me')));
    await shot('27_me');
    await tap(find.text('Nudges & notifications'));
    await shot('28_nudges');
    app.navKey.currentState!.pop();
    await wait(800);
    await tap(find.text('Privacy & AI'));
    await shot('29_privacy');
    app.navKey.currentState!.pop();
    await wait(800);

    app.navKey.currentState!.push(MaterialPageRoute(builder: (_) => const VisionCardScreen()));
    await wait(1500);
    await shot('30_vision');
    app.navKey.currentState!.pop();
    await wait(800);

    app.navKey.currentState!.push(MaterialPageRoute(builder: (_) => const WeeklyReviewIntro()));
    await waitFor(find.byKey(const Key('review_start')));
    await shot('31_review_intro');
    await tap(find.byKey(const Key('review_start')));
    await waitFor(find.byKey(const Key('worked_continue')), secs: 90);
    await shot('32_what_worked');
    await tap(find.byKey(const Key('worked_continue')));
    await type(find.byKey(const Key('review_inway')), 'On Wednesday I got home exhausted and ordered takeaway.');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('33_what_got_in_the_way');
    await tap(find.byKey(const Key('inway_continue')));
    await waitFor(find.byKey(const Key('nextweek_accept')), secs: 90);
    await shot('34_next_week');
    await tap(find.byKey(const Key('nextweek_accept')));
    await wait(1500);
    await shot('35_home_after_review');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
