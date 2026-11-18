import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Default security deposit percentage if the group does not specify an amount.
/// 10% of one monthly installment (0.10).
const double kDefaultDepositPercentOfInstallment = 0.10;

/// Global flag for development / testing tools.
/// Enables debug buttons like "Test: refund deposit" and "Test: forfeit deposit" on host console.
const bool kDevTools = true;

/// Razorpay Test Key ID (Public Key only - Key Secret is NEVER stored in the Flutter app).
const String kRazorpayTestKeyId = 'rzp_test_5172839401';

/// Dynamic base URL for SafeChit backend payment bridge.
/// Overridable at compile time:
/// `flutter run --dart-define=BACKEND_URL=http://<PC-LAN-IP>:3000`
String get kDepositBackendUrl {
  const envUrl = String.fromEnvironment('BACKEND_URL');
  if (envUrl.isNotEmpty) {
    return envUrl;
  }
  if (kIsWeb) {
    return 'http://localhost:3000';
  }
  try {
    if (Platform.isAndroid) {
      // 10.0.2.2 routes from Android emulator to host machine localhost
      return 'http://10.0.2.2:3000';
    }
  } catch (_) {}
  return 'http://localhost:3000';
}

