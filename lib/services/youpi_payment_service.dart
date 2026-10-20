import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpiAppInfo {
  final String id;
  final String name;
  final String packageName;
  final String iconAsset;
  final int brandColor;

  const UpiAppInfo({
    required this.id,
    required this.name,
    required this.packageName,
    required this.iconAsset,
    required this.brandColor,
  });
}

class YoupiPaymentService {
  YoupiPaymentService._();
  static final YoupiPaymentService instance = YoupiPaymentService._();

  // Configurable gateway base URL
  static String? _customGatewayUrl;

  static String get defaultGatewayUrl {
    if (_customGatewayUrl != null && _customGatewayUrl!.isNotEmpty) {
      return _customGatewayUrl!;
    }
    if (kIsWeb) {
      return 'http://localhost:6100';
    }
    try {
      if (Platform.isAndroid) {
        // Standard Android emulator mapping to host machine localhost
        return 'http://10.0.2.2:6100';
      }
    } catch (_) {}
    return 'http://localhost:6100';
  }

  static void setGatewayUrl(String url) {
    _customGatewayUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  // Pre-configured official UPI apps
  static const List<UpiAppInfo> popularUpiApps = [
    UpiAppInfo(
      id: 'gpay',
      name: 'Google Pay',
      packageName: 'com.google.android.apps.nbu.paisa.user',
      iconAsset: 'assets/images/gpay.png',
      brandColor: 0xFF1A73E8,
    ),
    UpiAppInfo(
      id: 'phonepe',
      name: 'PhonePe',
      packageName: 'com.phonepe.app',
      iconAsset: 'assets/images/phonepe.png',
      brandColor: 0xFF5F259F,
    ),
    UpiAppInfo(
      id: 'paytm',
      name: 'Paytm',
      packageName: 'net.one97.paytm',
      iconAsset: 'assets/images/paytm.png',
      brandColor: 0xFF00B9F5,
    ),
    UpiAppInfo(
      id: 'bhim',
      name: 'BHIM UPI',
      packageName: 'in.org.npci.upiapp',
      iconAsset: 'assets/images/bhim.png',
      brandColor: 0xFF00796B,
    ),
    UpiAppInfo(
      id: 'cred',
      name: 'CRED',
      packageName: 'com.dreamplug.androidapp',
      iconAsset: 'assets/images/cred.png',
      brandColor: 0xFF121212,
    ),
    UpiAppInfo(
      id: 'amazon',
      name: 'Amazon Pay',
      packageName: 'in.amazon.mShop.android.shopping',
      iconAsset: 'assets/images/amazon.png',
      brandColor: 0xFF232F3E,
    ),
  ];

  /// Builds canonical NPCI UPI URI string.
  /// Format: upi://pay?pa=<vpa>&pn=<name>&tr=<orderId>&am=<amount>&tn=<note>&cu=INR
  String buildUpiUri({
    required String payeeVpa,
    required String payeeName,
    required double amount,
    required String orderId,
    String? note,
  }) {
    final cleanVpa = payeeVpa.trim();
    // NPCI strict: Alphanumeric and spaces only, max 25 chars. No special characters like () or @
    final sanitizedName = payeeName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final cleanName = Uri.encodeComponent(
      sanitizedName.isNotEmpty ? (sanitizedName.length > 25 ? sanitizedName.substring(0, 25) : sanitizedName) : 'SafeChit Escrow',
    );
    final amountStr = amount.toStringAsFixed(2);
    final cleanNote = (note ?? 'Chit $orderId').replaceAll(RegExp(r'[^a-zA-Z0-9 -]'), '').trim();
    final txnNote = Uri.encodeComponent(cleanNote.length > 30 ? cleanNote.substring(0, 30) : cleanNote);

    return 'upi://pay?pa=$cleanVpa&pn=$cleanName&tr=$orderId&am=$amountStr&tn=$txnNote&cu=INR';
  }

  /// Builds an Android Intent URI targeted at a specific UPI app.
  String buildUpiIntentUri({
    required String payeeVpa,
    required String payeeName,
    required double amount,
    required String orderId,
    required String packageName,
    String? note,
  }) {
    final upiUri = buildUpiUri(
      payeeVpa: payeeVpa,
      payeeName: payeeName,
      amount: amount,
      orderId: orderId,
      note: note,
    );
    final query = upiUri.split('?').length > 1 ? upiUri.split('?')[1] : '';
    return 'intent://pay?$query#Intent;scheme=upi;package=$packageName;end';
  }

  /// Launches standard UPI app on device
  Future<bool> launchUpiPayment({
    required String payeeVpa,
    required String payeeName,
    required double amount,
    required String orderId,
    String? packageName,
    String? note,
  }) async {
    // 1. If target package specified on Android, try package intent first
    if (packageName != null && packageName.isNotEmpty && !kIsWeb) {
      try {
        final intentUriStr = buildUpiIntentUri(
          payeeVpa: payeeVpa,
          payeeName: payeeName,
          amount: amount,
          orderId: orderId,
          packageName: packageName,
          note: note,
        );
        final intentUri = Uri.parse(intentUriStr);
        if (await canLaunchUrl(intentUri)) {
          return await launchUrl(intentUri, mode: LaunchMode.externalNonBrowserApplication);
        }
      } catch (e) {
        debugPrint('[YoupiPaymentService] Package intent launch failed: $e, falling back to standard URI');
      }
    }

    // 2. Fallback to standard canonical UPI URI
    final upiUriStr = buildUpiUri(
      payeeVpa: payeeVpa,
      payeeName: payeeName,
      amount: amount,
      orderId: orderId,
      note: note,
    );

    final uri = Uri.parse(upiUriStr);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try launching with external non-browser intent
        return await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (e) {
      debugPrint('[YoupiPaymentService] Failed to launch UPI URI: $e');
      return false;
    }
  }

  /// Creates a payment session with YouPI PG API
  Future<Map<String, dynamic>> createPaymentSession({
    required String orderId,
    required double amount,
    required String memberName,
    required String memberPhone,
    required String groupId,
    int cycle = 1,
    String? payeeVpa,
  }) async {
    final url = Uri.parse('$defaultGatewayUrl/api/v1/payments');
    final amountStr = amount.toStringAsFixed(2);

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': 'idem_${orderId}_$cycle',
        },
        body: jsonEncode({
          'orderId': orderId,
          'amount': amountStr,
          'currency': 'INR',
          'customer': {
            'name': memberName,
            'phone': memberPhone,
          },
          'metadata': {
            'groupId': groupId,
            'cycle': cycle,
            'payeeVpa': payeeVpa ?? 'safechit.foreman@upi',
          },
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'paymentId': data['paymentId'] ?? data['id'],
          'status': data['status'] ?? 'ACTIVE',
          'amount': data['amount'] ?? amountStr,
          'checkoutUrl': data['checkoutUrl'],
          'data': data,
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'error': 'DUPLICATE_SESSION_DETECTED',
          'message': data['message'] ?? 'Payment session is active on another device.',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to create payment session',
          'data': data,
        };
      }
    } catch (e) {
      debugPrint('[YoupiPaymentService] Network error creating payment: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Polls payment status from YouPI PG API
  Future<Map<String, dynamic>> pollPaymentStatus(String paymentId) async {
    final url = Uri.parse('$defaultGatewayUrl/api/v1/payments/$paymentId');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': data['status'],
          'isPaid': data['status'] == 'SUCCESS',
          'utr': data['utr'] ?? data['bankReferenceNumber'],
          'amount': data['amount'],
          'data': data,
        };
      }
    } catch (e) {
      debugPrint('[YoupiPaymentService] Status poll error: $e');
    }
    return {'success': false, 'status': 'UNKNOWN'};
  }

  /// Timing-safe verification of HMAC-SHA256 signatures in Dart
  static bool verifyHmacSha256({
    required String payload,
    required String signature,
    required String secretKey,
  }) {
    try {
      final key = utf8.encode(secretKey);
      final bytes = utf8.encode(payload);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);
      final expectedSig = digest.toString();

      final cleanSig = signature.replaceFirst(RegExp(r'^sha256='), '').trim().toLowerCase();
      final cleanExpected = expectedSig.trim().toLowerCase();

      if (cleanSig.length != cleanExpected.length) return false;

      // Constant-time equality comparison
      int result = 0;
      for (int i = 0; i < cleanSig.length; i++) {
        result |= cleanSig.codeUnitAt(i) ^ cleanExpected.codeUnitAt(i);
      }
      return result == 0;
    } catch (e) {
      debugPrint('[YoupiPaymentService] HMAC verification error: $e');
      return false;
    }
  }
}
