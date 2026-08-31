import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/home_page.dart';
import 'state/sim_store.dart';

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
  final store = SimStore();

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSNL SIM Portal',
      debugShowCheckedModeBanner: false,
      theme: buildBsnlTheme(),
      home: HomePage(store: store),
    );
  }
}
