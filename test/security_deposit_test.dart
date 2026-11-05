import 'package:flutter_test/flutter_test.dart';
import 'package:safe_chit/models/security_deposit.dart';
import 'package:safe_chit/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security Deposit Model & Service Tests', () {
    test('1. SecurityDeposit model correctly serializes and deserializes', () {
      final json = {
        'id': 'dep_101',
        'group_id': 'grp_test_1',
        'member_id': 'member_alice',
        'amount': 2500.0,
        'status': 'held',
        'razorpay_order_id': 'order_test_12345',
        'razorpay_payment_id': 'pay_test_98765',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final dep = SecurityDeposit.fromJson(json);
      expect(dep.id, equals('dep_101'));
      expect(dep.groupId, equals('grp_test_1'));
      expect(dep.memberId, equals('member_alice'));
      expect(dep.amount, equals(2500.0));
      expect(dep.status, equals('held'));
      expect(dep.isHeld, isTrue);
      expect(dep.isPending, isFalse);
      expect(dep.isRefunded, isFalse);
      expect(dep.isForfeited, isFalse);
      expect(dep.displayStatus, equals('Held'));
      expect(dep.razorpayOrderId, equals('order_test_12345'));
      expect(dep.razorpayPaymentId, equals('pay_test_98765'));

      final encoded = dep.toJson();
      expect(encoded['id'], equals('dep_101'));
      expect(encoded['status'], equals('held'));
      expect(encoded['amount'], equals(2500.0));
    });

    test('2. Order creation generates valid test order parameters', () async {
      final res = await SupabaseService.createDepositOrder(
        groupId: 'grp_alpha',
        memberId: 'member_demo',
        amount: 1500.0,
      );

      expect(res.containsKey('orderId'), isTrue);
      expect(res.containsKey('amount'), isTrue);
      expect(res['amount'], equals(150000)); // amount in paise
      expect(res['currency'], equals('INR'));
    });

    test('3. Verification marks deposit status as held', () async {
      const groupId = 'grp_verify_test';
      const memberId = 'user_kavita';
      const amount = 3000.0;

      final orderRes = await SupabaseService.createDepositOrder(
        groupId: groupId,
        memberId: memberId,
        amount: amount,
      );
      final depositId = orderRes['depositId'] as String;
      final orderId = orderRes['orderId'] as String;

      final success = await SupabaseService.verifyDepositSignature(
        depositId: depositId,
        orderId: orderId,
        paymentId: 'pay_test_kavita_01',
        signature: 'test_sig_pay_test_kavita_01',
        groupId: groupId,
        memberId: memberId,
        amount: amount,
      );

      expect(success, isTrue);

      final dep = await SupabaseService.getSecurityDeposit(
        groupId: groupId,
        memberId: memberId,
      );
      expect(dep, isNotNull);
      expect(dep!.isHeld, isTrue);
      expect(dep.displayStatus, equals('Held'));
      expect(dep.razorpayPaymentId, equals('pay_test_kavita_01'));
    });

    test('4. Host test refund updates status to refunded', () async {
      const groupId = 'grp_refund_test';
      const memberId = 'user_rahul';
      const amount = 2000.0;

      await SupabaseService.verifyDepositSignature(
        depositId: 'dep_rahul',
        orderId: 'order_rahul',
        paymentId: 'pay_rahul_01',
        signature: 'test_sig_rahul',
        groupId: groupId,
        memberId: memberId,
        amount: amount,
      );

      final refundSuccess = await SupabaseService.refundDeposit(
        depositId: 'dep_rahul',
        groupId: groupId,
        memberId: memberId,
        amount: amount,
      );
      expect(refundSuccess, isTrue);

      final dep = await SupabaseService.getSecurityDeposit(
        groupId: groupId,
        memberId: memberId,
      );
      expect(dep, isNotNull);
      expect(dep!.isRefunded, isTrue);
      expect(dep.displayStatus, equals('Refunded'));
    });

    test('5. Host test forfeit updates status to forfeited', () async {
      const groupId = 'grp_forfeit_test';
      const memberId = 'user_defaulter';
      const amount = 5000.0;

      await SupabaseService.verifyDepositSignature(
        depositId: 'dep_defaulter',
        orderId: 'order_defaulter',
        paymentId: 'pay_defaulter_01',
        signature: 'test_sig_defaulter',
        groupId: groupId,
        memberId: memberId,
        amount: amount,
      );

      final forfeitSuccess = await SupabaseService.forfeitDeposit(
        depositId: 'dep_defaulter',
        groupId: groupId,
        memberId: memberId,
        amount: amount,
      );
      expect(forfeitSuccess, isTrue);

      final dep = await SupabaseService.getSecurityDeposit(
        groupId: groupId,
        memberId: memberId,
      );
      expect(dep, isNotNull);
      expect(dep!.isForfeited, isTrue);
      expect(dep.displayStatus, equals('Forfeited'));
    });
  });
}

