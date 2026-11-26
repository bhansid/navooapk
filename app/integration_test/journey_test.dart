import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:navoo/main.dart' as app;
import 'package:navoo/screens/chat_widgets.dart';
import 'package:navoo/screens/review.dart';
import 'package:navoo/screens/vision.dart';
import 'package:navoo/screens/shell.dart';
import 'package:navoo/state.dart';

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

    void nudgeScroll() {
      for (final e in find.byType(Scrollable).evaluate()) {
        final st = (e as StatefulElement).state as ScrollableState;
        final p = st.position;
        if (p.axis != Axis.vertical || !p.hasContentDimensions) continue;
        if (p.pixels < p.maxScrollExtent) p.jumpTo((p.pixels + 400).clamp(0.0, p.maxScrollExtent));
      }
    }

    Future<void> waitFor(Finder f, {int secs = 75}) async {
      for (var i = 0; i < secs * 5; i++) {
        await t.pump(const Duration(milliseconds: 200));
        if (f.evaluate().isNotEmpty) return;
        if (i % 3 == 2) nudgeScroll();
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
      log.add('send: ${text.substring(0, text.length > 20 ? 20 : text.length)}');
      await type(find.byKey(const Key('chat_input')), text);
      await tap(find.byKey(const Key('chat_send')));
    }

    // Counts saved messages (not on-screen bubbles, which scroll out of the list once the chat is long).
    Future<void> waitCoachReply(int before) async {
      for (var i = 0; i < 120 * 5; i++) {
        await t.pump(const Duration(milliseconds: 200));
        if (find.byType(TypingBubble).evaluate().isEmpty && AppState.I.chat.length >= before + 2) return;
      }
      throw TestFailure('Coach did not reply. Steps: $log');
    }

    // The coach acknowledges each answer (C1); wait until it has finished before answering again.
    Future<void> waitIdle() async {
      await wait(800);
      for (var i = 0; i < 90 * 5; i++) {
        await t.pump(const Duration(milliseconds: 200));
        if (find.byType(TypingBubble).evaluate().isEmpty) break;
      }
      await wait(600);
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
    await waitIdle();
    await sendChat('Stronger and healthier, and comfortable in my clothes.');
    await waitIdle();
    // R7: Back undoes one answer and puts it back in the box.
    await t.tap(find.byTooltip('Back').first, warnIfMissed: false);
    await wait(1200);
    final inputW = t.widget(find.byKey(const Key('chat_input')));
    final restored = inputW is TextField ? inputW.controller?.text ?? '' : '';
    if (!restored.contains('comfortable in my clothes')) throw TestFailure('R7: Back did not restore the last answer (got "$restored"). Steps: $log');
    await shot('07b_step_back_keeps_answer');
    await tap(find.byKey(const Key('chat_send')));
    await waitIdle();
    await sendChat('Keep up with my kids, travel more and be active without feeling tired.');
    await waitIdle();
    await sendChat('More present and confident, and I would stop avoiding photos.');
    await waitFor(find.byKey(const Key('vision_save')), secs: 150);
    await shot('08_vision_card');
    await tap(find.byKey(const Key('vision_save')));

    await waitFor(find.byKey(const Key('focus_use_0')), secs: 90);
    await shot('09_focus_options');
    // R6: other options, then back to the earlier ones; a typed request is not saved as the focus.
    await tap(find.text('Show other options'));
    for (var i = 0; i < 90 * 5 && find.text('Previous options').evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 200));
      // If the coach couldn't be reached, the app says so and keeps the options; try again once, as a user would.
      if (i == 60 * 5) await tap(find.text('Show other options'));
    }
    await waitFor(find.text('Previous options'), secs: 30);
    await shot('09b_other_options');
    await tap(find.text('Previous options'));
    await wait(1000);
    await sendChat('show me the previous options');
    await wait(1500);
    if (find.text('Yes, use this focus').evaluate().isNotEmpty) throw TestFailure('R6: "show me the previous options" was treated as a focus. Steps: $log');
    await shot('09c_previous_options');
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
    await waitIdle();
    await sendChat('My kids. I want to keep up with them.');
    await waitFor(find.text('A cup of tea or coffee'));
    await tap(find.text('A cup of tea or coffee'));
    await tap(find.text('My favourite song, played loud'));
    await shot('12_reward_chat');
    await tap(find.byKey(const Key('chat_send')));
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
    await waitFor(find.byKey(const Key('if_cue')));
    await wait(8000);
    await shot('17_brain_cheat_codes');
    await type(find.byKey(const Key('if_cue')), 'I finish eating my lunch');
    await type(find.byKey(const Key('then_do')), 'walk for 10 minutes');
    await type(find.byKey(const Key('slip_if')), 'I am too tired when I get home');
    await type(find.byKey(const Key('slip_then')), 'remind myself of my Vision');
    await type(find.byKey(const Key('nudge')), 'Trainers by the front door');
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(600);
    await shot('17b_codes_filled');
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
    await wait(2500);
    if (find.text('Your Brain Cheat Codes').evaluate().isNotEmpty) {
      await shot('22b_next_codes');
      // R11 + R12: main If/Then only, skip the other two parts, and choose no reward.
      await type(find.byKey(const Key('if_cue')), 'I get back from my lunch break');
      await type(find.byKey(const Key('then_do')), 'walk round the block');
      FocusManager.instance.primaryFocus?.unfocus();
      await tap(find.byKey(const Key('skip_slip')));
      await tap(find.byKey(const Key('skip_nudge')));
      if (find.byKey(const Key('no_reward')).evaluate().isNotEmpty) await tap(find.byKey(const Key('no_reward')));
      await wait(600);
      await shot('22c_codes_partly_skipped');
      await tap(find.byKey(const Key('ifthen_lock')));
      await wait(1500);
      if (find.byKey(const Key('ifthen_lock')).evaluate().isNotEmpty) throw TestFailure('R11: could not lock in with the slip-up and nudge skipped. Steps: $log');
    }

    await tap(find.byKey(const Key('tab_coach')));
    await wait(800);
    var before = AppState.I.chat.length;
    await sendChat('I missed my walk yesterday because work ran late. I always mess this up.');
    await waitCoachReply(before);
    await shot('23_coach_setback');
    before = AppState.I.chat.length;
    await sendChat('Can you write me a Python script to sort a list?');
    await waitCoachReply(before);
    await shot('24_coach_out_of_scope');
    before = AppState.I.chat.length;
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

    app.navKey.currentState!.push(MaterialPageRoute(builder: (_) => const FocusScreen()));
    await wait(1500);
    await shot('30b_this_weeks_micro_actions');
    // R16: new Micro-Actions are shown with a Confirm button before Brain Cheat Codes.
    await t.ensureVisible(find.text('Suggest different Micro-Actions'));
    await wait(500);
    await tap(find.text('Suggest different Micro-Actions'));
    for (var i = 0; i < 70 * 5 && find.byKey(const Key('confirm_more')).evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 200));
      if (i == 60 * 5) {
        await shot('30x_debug_before_retry');
        if (find.text('Suggest different Micro-Actions').evaluate().isNotEmpty) await tap(find.text('Suggest different Micro-Actions'));
      }
    }
    await waitFor(find.byKey(const Key('confirm_more')), secs: 90);
    await shot('30c_confirm_new_micro_actions');
    await tap(find.byKey(const Key('confirm_more')));
    await waitFor(find.text('Your Brain Cheat Codes'));
    await tap(find.text('Skip for now'));
    await wait(1500);
    app.navKey.currentState!.popUntil((r) => r.isFirst);
    await wait(800);

    app.navKey.currentState!.push(MaterialPageRoute(builder: (_) => const WeeklyReviewIntro()));
    await waitFor(find.byKey(const Key('review_start')));
    await shot('31_review_intro');
    await tap(find.byKey(const Key('review_start')));
    await waitFor(find.byKey(const Key('review_worked')), secs: 90);
    await type(find.byKey(const Key('review_worked')), 'Having my trainers by the door made the lunch walks easy.');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('32_what_worked');
    // R17: Speak to Navoo opens on top, with a Back button that returns to the same place.
    await tap(find.text('Speak to navoo'));
    await waitFor(find.byKey(const Key('coach_back')));
    await shot('32b_coach_over_checkin');
    await tap(find.byKey(const Key('coach_back')));
    await waitFor(find.byKey(const Key('review_worked')));
    // R18: leave the check-in, then pick it up again from Home with the answer kept.
    app.navKey.currentState!.popUntil((r) => r.isFirst);
    await wait(1000);
    await tap(find.byKey(const Key('tab_home')));
    await wait(800);
    // Home keeps its scroll position from earlier in the test; go back to the top, where the card is.
    for (var i = 0; i < 6 && find.text('Continue your check-in').evaluate().isEmpty; i++) {
      await t.fling(find.byType(Scrollable).first, const Offset(0, 1200), 3000, warnIfMissed: false);
      await wait(500);
    }
    await waitFor(find.text('Continue your check-in'));
    await shot('32c_continue_checkin_on_home');
    await tap(find.text('Continue your check-in'));
    await waitFor(find.byKey(const Key('review_worked')));
    final workedW = t.widget(find.byKey(const Key('review_worked')));
    final kept = workedW is TextField ? workedW.controller?.text ?? '' : '';
    if (!kept.contains('trainers by the door')) throw TestFailure('R18: check-in answer was not kept (got "$kept"). Steps: $log');
    await tap(find.byKey(const Key('worked_continue')));
    await type(find.byKey(const Key('review_inway')), 'On Wednesday I got home exhausted and ordered takeaway.');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot('33_what_got_in_the_way');
    await tap(find.byKey(const Key('inway_continue')));
    await waitFor(find.byKey(const Key('nextweek_accept')), secs: 90);
    await shot('34_next_week');
    await tap(find.byKey(const Key('nextweek_accept')));
    await wait(2500);
    if (find.text('Your Brain Cheat Codes').evaluate().isNotEmpty) {
      await shot('34b_codes_after_review');
      await tap(find.text('Skip for now'));
      await wait(1500);
    }
    await shot('35_home_after_review');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
