# Guarantor rules to enforce after testing is complete

- Guarantor must be a relative or friend. The guarantor confirms the stated relation.
- Guarantor cannot be the host of that group, and cannot share a PAN, bank account, or mobile number with the member.
- Guarantor eligibility: reputation tier "Trusted", at least 2 completed chits, no active default.
- Guarantee limited to the value of the biggest chit the guarantor completed cleanly.
- Maximum 2 active guarantees per guarantor, plus an "Available as guarantor" switch in their profile.
- Only low-reputation (New tier) users need a guarantor, and only for chits up to a ceiling (start: ₹10,000). Above it, the user needs their own reputation.
- Reputation thresholds: New under 30, Building 30-59, Trusted 60+. New: solo up to ₹1,000, with guarantor up to ₹10,000. Building: solo up to ₹25,000. Trusted: solo up to scheme ceiling.
- Tighten RLS on security_deposits: members can only read their own deposits, hosts can read deposits for their groups, and only verified backend signatures/webhooks can update status to 'held', 'refunded', or 'forfeited'.

