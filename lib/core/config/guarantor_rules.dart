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

/// Validates that a member and their guarantor do NOT co-exist in the same chit group.
/// Disallows a member from nominating an existing group member as guarantor,
/// and disallows an active guarantor from joining that group as a member.
GuarantorValidationResult validateMemberGuarantorMutualExclusion({
  required String memberUsername,
  required String? guarantorUsername,
  required List<String> currentGroupMemberUsernames,
  required List<String> currentGroupGuarantorUsernames,
}) {
  final cleanMember = memberUsername.trim().toLowerCase();
  final cleanGuarantor = guarantorUsername?.trim().toLowerCase();

  // Rule A: An existing guarantor cannot join the same chit group as a member
  final isGuarantorInGroup = currentGroupGuarantorUsernames
      .map((u) => u.trim().toLowerCase())
      .contains(cleanMember);
  if (isGuarantorInGroup) {
    return GuarantorValidationResult.disallowed(
      'You are already acting as a guarantor in this chit group. '
      'Guarantors cannot join the same group as members to protect against dual default.',
    );
  }

  // Rule B: A member cannot nominate someone who is already a member of this chit group
  if (cleanGuarantor != null && cleanGuarantor.isNotEmpty) {
    if (cleanGuarantor == cleanMember) {
      return GuarantorValidationResult.disallowed(
        'You cannot nominate yourself as your own guarantor.',
      );
    }

    final isGuarantorAlreadyMember = currentGroupMemberUsernames
        .map((u) => u.trim().toLowerCase())
        .contains(cleanGuarantor);
    if (isGuarantorAlreadyMember) {
      return GuarantorValidationResult.disallowed(
        '@$guarantorUsername is already a member of this chit group. '
        'A member and their guarantor cannot belong to the same chit group.',
      );
    }
  }

  return GuarantorValidationResult.allowed();
}

/// Validates whether a guarantor can accept a guarantee request for a group.
/// A user cannot act as a guarantor if they are already a member of that group.
GuarantorValidationResult validateGuarantorAcceptance({
  required String guarantorUsername,
  required List<String> currentGroupMemberUsernames,
}) {
  final cleanGuarantor = guarantorUsername.trim().toLowerCase();
  final isMember = currentGroupMemberUsernames
      .map((u) => u.trim().toLowerCase())
      .contains(cleanGuarantor);

  if (isMember) {
    return GuarantorValidationResult.disallowed(
      'You are already a member of this chit group. '
      'Members cannot act as guarantors in the same group to protect against dual default.',
    );
  }

  return GuarantorValidationResult.allowed();
}

