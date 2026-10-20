import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:safe_chit/models/chit_payment_record.dart';
import 'package:safe_chit/services/youpi_payment_service.dart';
import 'package:safe_chit/services/supabase_service.dart';

void main() {
  group('YouPI Transaction & Ledger Integration Tests', () {
    test('1. ChitPaymentRecord serializes and deserializes accurately', () {
      final now = DateTime.now();
      final record = ChitPaymentRecord(
        id: 'SC-TEST-001',
        groupId: 'group_1',
        groupName: 'Koramangala Testing Chit',
        cycle: 1,
        memberUsername: 'member_demo',
        memberName: 'Demo Member',
        amount: 1.0,
        amountPaise: 100,
        paymentMethod: 'UPI',
        status: 'ACTIVE',
        payeeVpa: 'devesh1@oksbi',
        payeeName: 'Devesh (Foreman Escrow)',
        createdAt: now,
        notes: 'Cycle 1 Installment',
      );

      final map = record.toMap();
      expect(map['id'], 'SC-TEST-001');
      expect(map['amount_paise'], 100);
      expect(map['payment_method'], 'UPI');

      final reconstructed = ChitPaymentRecord.fromMap(map);
      expect(reconstructed.id, record.id);
      expect(reconstructed.amount, 1.0);
      expect(reconstructed.payeeVpa, 'devesh1@oksbi');
      expect(reconstructed.isPaid, isFalse);
    });

    test('2. Canonical UPI URI Generator creates valid NPCI format for ₹1.00 testing', () {
      final service = YoupiPaymentService.instance;
      final uri = service.buildUpiUri(
        payeeVpa: 'devesh1@oksbi',
        payeeName: 'Devesh',
        amount: 1.0,
        orderId: 'ORD-TEST-01',
        note: 'Installment ₹1.00',
      );

      expect(uri, startsWith('upi://pay?'));
      expect(uri, contains('pa=devesh1@oksbi'));
      expect(uri, contains('am=1.00'));
      expect(uri, contains('cu=INR'));
    });

    test('3. Android Intent URI properly packages target UPI apps for ₹1.00 to devesh1@oksbi', () {
      final service = YoupiPaymentService.instance;
      final intentUri = service.buildUpiIntentUri(
        payeeVpa: 'devesh1@oksbi',
        payeeName: 'Devesh',
        amount: 1.0,
        orderId: 'ORD-TEST-01',
        packageName: 'com.google.android.apps.nbu.paisa.user',
      );

      expect(intentUri, startsWith('intent://pay?'));
      expect(intentUri, contains('pa=devesh1@oksbi'));
      expect(intentUri, contains('am=1.00'));
      expect(intentUri, contains('scheme=upi;package=com.google.android.apps.nbu.paisa.user;end'));
    });

    test('4. Cryptographic HMAC-SHA256 signature verification blocks tampering', () {
      const secretKey = 'safechit_super_secret_key_2026';
      final payload = jsonEncode({'orderId': 'ORD-101', 'amount': 5000, 'status': 'PAID'});

      // Generate legitimate signature
      final keyBytes = utf8.encode(secretKey);
      final payloadBytes = utf8.encode(payload);
      final hmac = Hmac(sha256, keyBytes);
      final validSignature = 'sha256=${hmac.convert(payloadBytes)}';

      // Verify legitimate signature passes
      final isAuthentic = YoupiPaymentService.verifyHmacSha256(
        payload: payload,
        signature: validSignature,
        secretKey: secretKey,
      );
      expect(isAuthentic, isTrue);

      // Verify tampered payload fails
      final tamperedPayload = jsonEncode({'orderId': 'ORD-101', 'amount': 50, 'status': 'PAID'});
      final isTamperedValid = YoupiPaymentService.verifyHmacSha256(
        payload: tamperedPayload,
        signature: validSignature,
        secretKey: secretKey,
      );
      expect(isTamperedValid, isFalse);

      // Verify wrong secret fails
      final isWrongSecretValid = YoupiPaymentService.verifyHmacSha256(
        payload: payload,
        signature: validSignature,
        secretKey: 'wrong_secret_key',
      );
      expect(isWrongSecretValid, isFalse);
    });

    test('5. SafeChit Ledger handles UPI recording & Foreman Cash Confirmation (CASH_COUNTER)', () async {
      final payment = ChitPaymentRecord(
        id: 'SC-CASH-TEST-101',
        groupId: 'group_test',
        groupName: 'Test Chit Group',
        cycle: 1,
        memberUsername: 'subscriber_1',
        memberName: 'Subscriber One',
        amount: 2500.0,
        amountPaise: 250000,
        paymentMethod: 'UPI',
        status: 'ACTIVE',
        payeeVpa: 'foreman@upi',
        payeeName: 'Test Foreman',
        createdAt: DateTime.now(),
      );

      // 1. Record payment in ledger
      await SupabaseService.recordPayment(payment);
      var fetched = await SupabaseService.getPaymentById('SC-CASH-TEST-101');
      expect(fetched, isNotNull);
      expect(fetched!.status, 'ACTIVE');
      expect(fetched.isPaid, isFalse);

      // 2. Simulate Foreman confirming in-person Cash Payment (CASH_COUNTER)
      await SupabaseService.confirmCashPayment(
        paymentId: 'SC-CASH-TEST-101',
        foremanUsername: 'foreman_admin',
        notes: 'Cash received at monthly meeting',
      );

      fetched = await SupabaseService.getPaymentById('SC-CASH-TEST-101');
      expect(fetched!.status, 'PAID');
      expect(fetched.paymentMethod, 'CASH_COUNTER');
      expect(fetched.isPaid, isTrue);
      expect(fetched.notes, contains('Cash received at monthly meeting'));
    });

    test('6. Chit Group pool defaults to ₹5.00 with ₹1.00 contribution & Foreman UPI configuration updates', () async {
      final groups = await SupabaseService.getChitGroups();
      expect(groups.isNotEmpty, isTrue);

      final firstGroup = groups.first;
      expect(firstGroup.totalPoolSize, 5.0);
      expect(firstGroup.monthlyContribution, 1.0);
      expect(firstGroup.foremanUpiId, contains('@oksbi'));

      // Test updating Foreman receiving UPI ID (e.g. to devesh1@oksbi)
      SupabaseService.updateForemanUpiId('devesh1@oksbi');
      expect(SupabaseService.foremanUpiId, 'devesh1@oksbi');

      final refreshedGroups = await SupabaseService.getChitGroups();
      expect(refreshedGroups.first.foremanUpiId, 'devesh1@oksbi');

      // Verify UPI link generator uses the updated VPA
      final service = YoupiPaymentService.instance;
      final uri = service.buildUpiUri(
        payeeVpa: refreshedGroups.first.foremanUpiId,
        payeeName: 'Devesh Foreman',
        amount: refreshedGroups.first.monthlyContribution,
        orderId: 'ORD-DEVESH-01',
      );

      expect(uri, contains('pa=devesh1@oksbi'));
      expect(uri, contains('am=1.00'));
    });
  });
}
