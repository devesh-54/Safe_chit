import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_chit/main.dart';

void main() {
  testWidgets('ChitGuard onboarding full flow test', (WidgetTester tester) async {
    // 1. Load the App
    await tester.pumpWidget(const ChitGuardApp());
    await tester.pumpAndSettle();

    // Verify Screen 1 is loaded
    expect(find.text('Choose Your Role'), findsOneWidget);

    // Tap Member Card
    await tester.tap(find.text("I'm a Member"));
    await tester.pumpAndSettle();

    // Tap Continue to navigate to Screen 2
    final continueBtn = find.text('Continue');
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // Verify Screen 2: Account Setup
    expect(find.text('Account Setup'), findsOneWidget);

    // Enter 10-digit mobile
    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.at(0), '9876543210');
    await tester.pumpAndSettle();

    // Tap Send OTP
    await tester.tap(find.text('Send OTP'));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Enter OTP
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.pumpAndSettle();

    // Tap Verify OTP
    await tester.tap(find.text('Verify').first);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    // Enter Email
    await tester.enterText(find.byType(TextFormField).last, 'test@gmail.com');
    await tester.pumpAndSettle();

    // Tap Verify Email
    await tester.tap(find.text('Verify'));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Tap Continue to navigate to Screen 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify Screen 3: Personal Details
    expect(find.text('Personal Details'), findsOneWidget);
  });
}
