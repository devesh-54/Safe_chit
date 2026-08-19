import 'package:flutter_test/flutter_test.dart';
import 'package:safe_chit/main.dart';

void main() {
  testWidgets('ChitGuard onboarding smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChitGuardApp());

    // Verify that the role selection screen is displayed.
    expect(find.text('Choose Your Role'), findsOneWidget);
    expect(find.text("I'm a Member"), findsOneWidget);
    expect(find.text("I'm a Host (Foreman)"), findsOneWidget);
  });
}
