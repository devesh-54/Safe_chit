/// Development convenience shortcuts for quick testing in local/staging builds.
/// 
/// Set [kDemoLoginShortcuts] to `false` before any public or production release.
const bool kDemoLoginShortcuts = true;

enum LoginRole {
  member,
  foreman,
}

class DemoCredentials {
  // Member demo credentials
  static const String memberUsername = 'member_demo';
  static const String memberPassword = 'member123';

  // Foreman demo credentials
  static const String foremanUsername = 'foreman';
  static const String foremanPassword = 'foreman123';
}
