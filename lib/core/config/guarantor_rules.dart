/// Feature flag and validation hook for Guarantor eligibility rules.
const bool kEnforceGuarantorRules = false;

/// Rule: New members who haven't joined at least 2 groups must have a guarantor.
bool isGuarantorRequired({required int joinedChitsCount}) {
  return joinedChitsCount < 2;
}

class GuarantorValidationResult {
  final bool isAllowed;
  final String? reason;

  const GuarantorValidationResult({
    required this.isAllowed,
    this.reason,
  });

  factory GuarantorValidationResult.allowed() =>
      const GuarantorValidationResult(isAllowed: true);

  factory GuarantorValidationResult.disallowed(String reason) =>
      GuarantorValidationResult(isAllowed: false, reason: reason);
}

/// Validates whether a requested user can serve as a guarantor.
GuarantorValidationResult validateGuarantorRequest({
  required String memberUsername,
  required String guarantorUsername,
  required String relation,
  required double chitPoolValue,
}) {
  if (!kEnforceGuarantorRules) {
    // Testing mode: Basic checks handled at UI level
    return GuarantorValidationResult.allowed();
  }

  // TODO: Rule 1 - Guarantor must be a relative or friend. The guarantor confirms the stated relation.
  // TODO: Rule 2 - Guarantor cannot be the host of that group, and cannot share a PAN, bank account, or mobile number with the member.
  // TODO: Rule 3 - Guarantor eligibility: reputation tier 'Trusted', at least 2 completed chits, no active default.
  // TODO: Rule 4 - Guarantee limited to the value of the biggest chit the guarantor completed cleanly.
  // TODO: Rule 5 - Maximum 2 active guarantees per guarantor, plus an 'Available as guarantor' switch in their profile.
  // TODO: Rule 6 - Only low-reputation (New tier) users need a guarantor, and only for chits up to a ceiling (start: ₹10,000). Above it, the user needs their own reputation.
  // TODO: Rule 7 - Reputation thresholds: New under 30, Building 30-59, Trusted 60+. New: solo up to ₹1,000, with guarantor up to ₹10,000. Building: solo up to ₹25,000. Trusted: solo up to scheme ceiling.

  return GuarantorValidationResult.allowed();
}
