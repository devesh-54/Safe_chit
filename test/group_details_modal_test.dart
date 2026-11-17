import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_chit/models/chit_group.dart';
import 'package:safe_chit/screens/common/group_details_modal.dart';

void main() {
  testWidgets('GroupDetailsModal renders without errors', (WidgetTester tester) async {
    final group = ChitGroup(
      id: 'group_test_1',
      name: 'meowl',
      totalPoolSize: 100000.0,
      durationMonths: 10,
      monthlyContribution: 10000.0,
      securityDeposit: 1000.0,
      payoutRules: 'Standard',
      inviteCode: '148376',
      status: 'Active',
      currentCycle: 1,
      membersCount: 10,
      schemeType: 'Bidding',
      isPublic: true,
      city: 'Bengaluru',
      foremanUpiId: 'devesh1@oksbi',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailsModal(
          group: group,
          isForeman: false,
          currentUsername: 'member_demo',
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('meowl'), findsWidgets);
    expect(find.text('Overview'), findsWidgets);
  });
}
