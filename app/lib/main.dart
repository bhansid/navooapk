import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'device.dart';
import 'state.dart';
import 'theme.dart';
import 'screens/start.dart';
import 'screens/blueprint.dart';
import 'screens/shell.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, systemNavigationBarColor: NC.bg));
  await AppState.I.load();
  Device.init();
  runApp(const NavooApp());
}

class NavooApp extends StatelessWidget {
  const NavooApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Navoo',
        debugShowCheckedModeBanner: false,
        theme: navooTheme(),
        navigatorKey: navKey,
        home: const Root(),
      );
}

/// Decides where the user lands.
class Root extends StatelessWidget {
  const Root({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    if (s.loggedIn && s.onboarded) return MainShell();
    if (s.loggedIn) return const PersonalIntroScreen();
    return const SplashScreen();
  }
}
