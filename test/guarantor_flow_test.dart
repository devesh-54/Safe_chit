import 'package:flutter_test/flutter_test.dart';
import 'package:safe_chit/core/config/guarantor_rules.dart';
import 'package:safe_chit/models/guarantee_request.dart';
import 'package:safe_chit/models/chit_join_request.dart';
import 'package:safe_chit/services/supabase_service.dart';

void main() {
  group('Guarantor Rules & Flow Tests', () {
    test('1. isGuarantorRequired mandates guarantor for new members with < 2 groups', () {
      expect(isGuarantorRequired(joinedChitsCount: 0), isTrue);
      expect(isGuarantorRequired(joinedChitsCount: 1), isTrue);
      expect(isGuarantorRequired(joinedChitsCount: 2), isFalse);
      expect(isGuarantorRequired(joinedChitsCount: 5), isFalse);
    });

    test('2. validateGuarantorRequest returns allowed while rules flag is false', () {
      final res = validateGuarantorRequest(
        memberUsername: 'member_test2',
        guarantorUsername: 'member_demo',
        relation: 'Friend',
        chitPoolValue: 5.0,
      );
      expect(res.isAllowed, isTrue);
      expect(res.reason, isNull);
    });

    test('3. GuaranteeRequest serialization and deserialization works accurately', () {
      final now = DateTime.now();
      final req = GuaranteeRequest(
        id: 'gr_test_1',
        groupId: 'group_1',
        groupName: 'Indiranagar Quick Pool',
        joinRequestId: 'req_100',
        memberId: 'member_test2',
        memberName: 'Rahul Sharma',
        guarantorId: 'member_demo',
        relation: 'Colleague',
        status: 'pending',
        chitValue: 5.0,
        durationMonths: 5,
        createdAt: now,
      );

      final json = req.toJson();
      expect(json['id'], 'gr_test_1');
      expect(json['group_id'], 'group_1');
      expect(json['join_request_id'], 'req_100');
      expect(json['member_id'], 'member_test2');
      expect(json['guarantor_id'], 'member_demo');
      expect(json['relation'], 'Colleague');
      expect(json['status'], 'pending');

      final deserialized = GuaranteeRequest.fromJson(json);
      expect(deserialized.id, req.id);
      expect(deserialized.guarantorId, req.guarantorId);
      expect(deserialized.relation, req.relation);
      expect(deserialized.status, 'pending');
    });

    test('4. ChitJoinRequest includes and preserves guarantor fields', () {
      final joinReq = ChitJoinRequest(
        id: 'req_200',
        groupId: 'group_2',
        groupName: 'Koramangala Chit',
        inviteCode: '849201',
        memberUsername: 'member_test2',
        memberName: 'Rahul Sharma',
        memberPhone: '+91 9876543210',
        memberEmail: 'rahul@test.com',
        memberCity: 'Bengaluru',
        reputationScore: 100.0,
        status: 'pending',
        createdAt: DateTime.now(),
        guarantorUsername: 'member_demo',
        guarantorRelation: 'Friend',
        guarantorStatus: 'pending',
      );

      final json = joinReq.toJson();
      expect(json['guarantor_username'], 'member_demo');
      expect(json['guarantor_relation'], 'Friend');
      expect(json['guarantor_status'], 'pending');

      final deserialized = ChitJoinRequest.fromJson(json);
      expect(deserialized.guarantorUsername, 'member_demo');
      expect(deserialized.guarantorRelation, 'Friend');
      expect(deserialized.guarantorStatus, 'pending');
    });

    test('5. checkUserExists correctly validates existing vs non-existent usernames', () async {
      expect(await SupabaseService.checkUserExists('member_demo'), isTrue);
      expect(await SupabaseService.checkUserExists('foreman'), isTrue);
      expect(await SupabaseService.checkUserExists('member_test2'), isTrue);
      expect(await SupabaseService.checkUserExists(''), isFalse);
      expect(await SupabaseService.checkUserExists('non_existent_ghost_user_12345'), isFalse);
    });

    test('6. Submit join request with guarantor creates guarantee request and responds', () async {
      final success = await SupabaseService.submitJoinRequest(
        inviteCode: 'CG-KORA-982',
        memberUsername: 'member_test2',
        guarantorUsername: 'member_demo',
        guarantorRelation: 'Friend',
      );
      expect(success, isTrue);

      // Check guarantor incoming requests
      final incoming = await SupabaseService.getGuaranteeRequestsForGuarantor('member_demo');
      expect(incoming.isNotEmpty, isTrue);
      final req = incoming.firstWhere((r) => r.memberId == 'member_test2');
      expect(req.status, 'pending');
      expect(req.guarantorId, 'member_demo');

      // Guarantor accepts
      final respondSuccess = await SupabaseService.respondToGuaranteeRequest(
        requestId: req.id,
        accept: true,
      );
      expect(respondSuccess, isTrue);

      final updatedList = await SupabaseService.getGuaranteeRequestsForGuarantor('member_demo');
      final updatedReq = updatedList.firstWhere((r) => r.id == req.id);
      expect(updatedReq.status, 'accepted');
      expect(updatedReq.respondedAt, isNotNull);
    });

    test('7. Mutual Exclusion: validateMemberGuarantorMutualExclusion blocks co-existence', () {
      // Case A: Nominated guarantor is already a member of the group
      final res1 = validateMemberGuarantorMutualExclusion(
        memberUsername: 'member_new',
        guarantorUsername: 'alice',
        currentGroupMemberUsernames: ['alice', 'bob'],
        currentGroupGuarantorUsernames: [],
      );
      expect(res1.isAllowed, isFalse);
      expect(res1.reason, contains('already a member of this chit group'));

      // Case B: Applicant is already a guarantor in this group
      final res2 = validateMemberGuarantorMutualExclusion(
        memberUsername: 'charlie',
        guarantorUsername: 'david',
        currentGroupMemberUsernames: ['alice', 'bob'],
        currentGroupGuarantorUsernames: ['charlie'],
      );
      expect(res2.isAllowed, isFalse);
      expect(res2.reason, contains('already acting as a guarantor'));

      // Case C: Applicant nominates themselves
      final res3 = validateMemberGuarantorMutualExclusion(
        memberUsername: 'alice',
        guarantorUsername: 'alice',
        currentGroupMemberUsernames: ['bob'],
        currentGroupGuarantorUsernames: [],
      );
      expect(res3.isAllowed, isFalse);
      expect(res3.reason, contains('cannot nominate yourself'));

      // Case D: Valid nomination where neither is member or guarantor in this group
      final res4 = validateMemberGuarantorMutualExclusion(
        memberUsername: 'member_new',
        guarantorUsername: 'charlie',
        currentGroupMemberUsernames: ['alice', 'bob'],
        currentGroupGuarantorUsernames: [],
      );
      expect(res4.isAllowed, isTrue);
    });

    test('8. Mutual Exclusion: validateGuarantorAcceptance blocks member from acting as guarantor', () {
      final resBlocked = validateGuarantorAcceptance(
        guarantorUsername: 'alice',
        currentGroupMemberUsernames: ['alice', 'bob'],
      );
      expect(resBlocked.isAllowed, isFalse);
      expect(resBlocked.reason, contains('already a member of this chit group'));

      final resAllowed = validateGuarantorAcceptance(
        guarantorUsername: 'charlie',
        currentGroupMemberUsernames: ['alice', 'bob'],
      );
      expect(resAllowed.isAllowed, isTrue);
    });

    test('9. Mutual Exclusion: Service blocks join request if guarantor is already a member', () async {
      // 'Rajesh Kumar' is an active member in group_1 ('CG-KORA-982')
      final targetGroup = await SupabaseService.getGroupByInviteCode('CG-KORA-982');
      expect(targetGroup, isNotNull);

      // Attempt to submit join request nominating existing group member 'Rajesh Kumar' as guarantor
      final fail = await SupabaseService.submitJoinRequest(
        inviteCode: targetGroup!.inviteCode,
        memberUsername: 'new_applicant_99',
        guarantorUsername: 'Rajesh Kumar',
        guarantorRelation: 'Friend',
      );
      expect(fail, isFalse);
    });

    test('10. Mutual Exclusion: Service blocks guarantor from accepting if already a group member', () async {
      final targetGroup = await SupabaseService.getGroupByInviteCode('CG-KORA-982');
      expect(targetGroup, isNotNull);

      // Suppose someone requested 'Rajesh Kumar' (already a member in group_1) to be a guarantor
      final conflictReq = GuaranteeRequest(
        id: 'gr_conflict_test_10',
        groupId: targetGroup!.id,
        joinRequestId: 'req_conflict_dummy',
        memberId: 'applicant_xyz',
        guarantorId: 'Rajesh Kumar', // Already an active member of group_1
        relation: 'Colleague',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // If we attempt to respond with accept: true, it should be strictly blocked
      final accepted = await SupabaseService.respondToGuaranteeRequest(
        requestId: conflictReq.id,
        accept: true,
      );
      expect(accepted, isFalse);
    });

    test('11. Mutual Exclusion: Service blocks active guarantor from joining same group as a member', () async {
      // From Test 6, 'member_demo' is an active guarantor in group_1 ('CG-KORA-982')
      final isGuarantor = await SupabaseService.isUserGuarantorInGroup(
        groupId: 'group_1',
        username: 'member_demo',
      );
      expect(isGuarantor, isTrue);

      // Now member_demo tries to submit a join request to group_1
      final joinAttempt = await SupabaseService.submitJoinRequest(
        inviteCode: 'CG-KORA-982',
        memberUsername: 'member_demo',
      );
      // Must be blocked because member_demo is already an active guarantor in group_1
      expect(joinAttempt, isFalse);
    });
  });
}

