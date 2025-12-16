import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:untitled/main.dart';
import 'package:untitled/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots and shows login when logged out', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const BiTasiApp());

    // First frame: session is still being checked.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // After async session check: token is missing -> LoginScreen.
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
