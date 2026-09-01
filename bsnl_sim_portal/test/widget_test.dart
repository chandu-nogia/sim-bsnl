import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bsnl_sim_portal/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app loads portal title', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BsnlSimApp());
    await tester.pump();
    expect(find.text('BSNL SIM Portal'), findsOneWidget);
  });
}
