import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_chit/screens/sign_in_screen.dart';
import 'package:safe_chit/services/supabase_service.dart';

void main() {
  setUpAll(() async {
    await SupabaseService.initialize();
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: SignInScreen(
        onStartSignUp: () {},
        onBackToLanding: () {},
      ),
    );
  }

  testWidgets('SignInScreen role toggle exists, defaults to Member and autofills member credentials', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Verify toggle options exist
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Foreman'), findsOneWidget);

    // Verify default auto-fill when kDemoLoginShortcuts is true
    final usernameField = find.byType(TextFormField).at(0);
    final passwordField = find.byType(TextFormField).at(1);

    expect(find.descendant(of: usernameField, matching: find.text('member_demo')), findsOneWidget);
    expect(find.descendant(of: passwordField, matching: find.text('member123')), findsOneWidget);

    // Verify password is masked
    final editableTextFinder = find.descendant(of: passwordField, matching: find.byType(EditableText));
    final EditableText editableText = tester.widget(editableTextFinder);
    expect(editableText.obscureText, isTrue);
  });

  testWidgets('Switching toggle to Foreman overwrites credentials with foreman/foreman123', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Tap Foreman toggle
    await tester.tap(find.text('Foreman'));
    await tester.pumpAndSettle();

    final usernameField = find.byType(TextFormField).at(0);
    final passwordField = find.byType(TextFormField).at(1);

    expect(find.descendant(of: usernameField, matching: find.text('foreman')), findsOneWidget);
    expect(find.descendant(of: passwordField, matching: find.text('foreman123')), findsOneWidget);

    // Password stays masked
    final editableTextFinder = find.descendant(of: passwordField, matching: find.byType(EditableText));
    final EditableText editableText = tester.widget(editableTextFinder);
    expect(editableText.obscureText, isTrue);
  });

  testWidgets('Switching toggle back to Member overwrites credentials with member_demo/member123', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Switch to Foreman then back to Member
    await tester.tap(find.text('Foreman'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Member'));
    await tester.pumpAndSettle();

    final usernameField = find.byType(TextFormField).at(0);
    final passwordField = find.byType(TextFormField).at(1);

    expect(find.descendant(of: usernameField, matching: find.text('member_demo')), findsOneWidget);
    expect(find.descendant(of: passwordField, matching: find.text('member123')), findsOneWidget);
  });

  testWidgets('Fields remain editable by the user', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    final usernameField = find.byType(TextFormField).at(0);
    await tester.enterText(usernameField, 'custom_user');
    await tester.pumpAndSettle();

    expect(find.descendant(of: usernameField, matching: find.text('custom_user')), findsOneWidget);
  });

  testWidgets('Role mismatch shows inline error and does not navigate', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Select Foreman toggle, but enter Member credentials
    await tester.tap(find.text('Foreman'));
    await tester.pumpAndSettle();

    final usernameField = find.byType(TextFormField).at(0);
    final passwordField = find.byType(TextFormField).at(1);

    await tester.enterText(usernameField, 'member_demo');
    await tester.enterText(passwordField, 'member123');
    await tester.pumpAndSettle();

    // Tap Login button
    final loginButton = find.widgetWithText(ElevatedButton, 'Sign In');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    // Verify inline error message is shown
    expect(find.text('This is a member account. Switch to Member.'), findsOneWidget);

    // Switching to Member clears the error and updates credentials
    await tester.tap(find.text('Member'));
    await tester.pumpAndSettle();

    expect(find.text('This is a member account. Switch to Member.'), findsNothing);
  });

  testWidgets('Reverse role mismatch shows inline error and does not navigate', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Toggle is Member (default), enter Foreman credentials
    final usernameField = find.byType(TextFormField).at(0);
    final passwordField = find.byType(TextFormField).at(1);

    await tester.enterText(usernameField, 'foreman_admin');
    await tester.enterText(passwordField, 'foreman123');
    await tester.pumpAndSettle();

    // Tap Login button
    final loginButton = find.widgetWithText(ElevatedButton, 'Sign In');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    // Verify inline error message is shown
    expect(find.text('This is a foreman account. Switch to Foreman.'), findsOneWidget);
  });
}
