import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sftp_browser/app.dart';

void main() {
  testWidgets('shows the saved server landing screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('SFTP Browser'), findsOneWidget);
    expect(find.text('Add server'), findsWidgets);
  });
}
