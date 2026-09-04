import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/login_page.dart';
import 'state/auth_store.dart';
import 'state/sim_store.dart';
import 'widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BsnlSimApp());
}

class BsnlSimApp extends StatefulWidget {
  const BsnlSimApp({super.key});

  @override
  State<BsnlSimApp> createState() => _BsnlSimAppState();
}

class _BsnlSimAppState extends State<BsnlSimApp> {
  final auth = AuthStore();
  late final SimStore store = SimStore(auth);

  @override
  void dispose() {
    store.dispose();
    auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSNL Khatushyamji',
      debugShowCheckedModeBanner: false,
      theme: buildBsnlTheme(),
      home: AnimatedBuilder(
        animation: auth,
        builder: (context, _) {
          Widget page;
          if (auth.loading) {
            page = const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (!auth.isLoggedIn) {
            page = LoginPage(auth: auth);
          } else {
            page = AppShell(auth: auth, simStore: store);
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey('${auth.loading}-${auth.isLoggedIn}'),
              child: page,
            ),
          );
        },
      ),
    );
  }
}
