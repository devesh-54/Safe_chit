import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_chit/main.dart';
import 'package:safe_chit/services/supabase_service.dart';

void main() {
  testWidgets('ChitGuard landing page navigation and onboarding flow test', (WidgetTester tester) async {
    await SupabaseService.initialize();
    // 1. Load the App
    await tester.pumpWidget(const ChitGuardApp());
    await tester.pumpAndSettle();

    // Verify Landing Page loads with ChitGuard app title and Hero title
    expect(find.text('ChitGuard'), findsAtLeastNWidgets(1));
    expect(find.text('Get Started'), findsAtLeastNWidgets(1));

    // Tap "Get Started" button on Landing Page to navigate to Step 1: Choose Your Role
    await tester.tap(find.text('Get Started').first);
    await tester.pumpAndSettle();

    // Verify Screen 1: Choose Your Role is loaded
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
  });

  testWidgets('ChitGuard landing page to Sign In navigation test', (WidgetTester tester) async {
    await SupabaseService.initialize();
    await tester.pumpWidget(const ChitGuardApp());
    await tester.pumpAndSettle();

    // Tap Sign In button
    await tester.tap(find.text('Sign In').first);
    await tester.pumpAndSettle();

    // Verify Sign In Screen is displayed
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Username, Email, or Mobile Number'), findsOneWidget);

    // Tap Back button to return to Landing Page
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Verify back on Landing Page
    expect(find.text('Get Started'), findsAtLeastNWidgets(1));
  });
}



