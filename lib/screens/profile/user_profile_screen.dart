import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../models/reputation_event.dart';

class UserProfileScreen extends StatefulWidget {
  final String username;
  final bool? isOwnProfile;
  final String? initialRole; // 'member' or 'foreman'

  const UserProfileScreen({
    super.key,
    required this.username,
    this.isOwnProfile,
    this.initialRole,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  String _selectedRole = 'member'; // 'member' or 'foreman'
  Map<String, dynamic>? _performanceData;
  late bool _isOwnProfile;

  @override
  void initState() {
    super.initState();
    _isOwnProfile = widget.isOwnProfile ??
        (widget.username.trim().toLowerCase() ==
            SupabaseService.currentUsername.trim().toLowerCase());
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    final data = await SupabaseService.getUserRolePerformance(widget.username);

    if (mounted) {
      final memberStats = data['member'] as Map<String, dynamic>;
      final foremanStats = data['foreman'] as Map<String, dynamic>;

      String initialTab;
      if (widget.initialRole != null &&
          (widget.initialRole == 'member' || widget.initialRole == 'foreman')) {
        initialTab = widget.initialRole!;
      } else if (_isOwnProfile) {
        // Own profile: open current active role (default member if active, else foreman)
        if (memberStats['isActive'] == true) {
          initialTab = 'member';
        } else if (foremanStats['isActive'] == true) {
          initialTab = 'foreman';
        } else {
          initialTab = 'member';
        }
      } else {
        // Another user's public profile: open the role with MORE activity
        final int memberActivity =
            (memberStats['activityCount'] as int?) ?? 0;
        final int foremanActivity =
            (foremanStats['activityCount'] as int?) ?? 0;
        initialTab =
            foremanActivity > memberActivity ? 'foreman' : 'member';
      }

      setState(() {
        _performanceData = data;
        _selectedRole = initialTab;
        _isLoading = false;
      });
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'U';
    // Remove parenthesized suffixes like (Foreman), (Subscriber)
    final cleaned = name.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    final parts = cleaned.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _maskMobile(String? phone) {
    if (phone == null || phone.trim().isEmpty) return 'Not available';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return phone;
    final lastFour = digits.substring(digits.length - 4);
    return '+91 ******$lastFour';
  }

  String _maskEmail(String? email) {
    if (email == null || email.trim().isEmpty) return 'Not available';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final user = parts[0];
    final domain = parts[1];
    if (user.length <= 2) return '$user***@$domain';
    return '${user[0]}***${user[user.length - 1]}@$domain';
  }

  String _formatMemberSince(dynamic rawDate) {
    if (rawDate == null) return 'Member since 2026';
    try {
      final dt = DateTime.parse(rawDate.toString());
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return 'Member since ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'Member since 2026';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isOwnProfile ? 'My Profile & Performance' : 'Member Profile',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Profile',
            onPressed: _loadProfileData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F4C81)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSharedHeader(),
                  const SizedBox(height: 18),
                  _buildSegmentedToggle(),
                  const SizedBox(height: 18),
                  _buildRolePerformanceContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildSharedHeader() {
    final profile =
        _performanceData?['profile'] as Map<String, dynamic>? ?? {};
    final memberStats =
        _performanceData?['member'] as Map<String, dynamic>? ?? {};
    final foremanStats =
        _performanceData?['foreman'] as Map<String, dynamic>? ?? {};

    final fullName = profile['full_name'] as String? ?? widget.username;
    final username = profile['username'] as String? ?? widget.username;
    final city = profile['perm_city'] as String? ?? 'Bengaluru';
    final memberSince = _formatMemberSince(profile['created_at']);

    final bool isMemberActive = memberStats['isActive'] == true;
    final bool isForemanActive = foremanStats['isActive'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF0F4C81),
                child: Text(
                  _getInitials(fullName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF007A87),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          city,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            memberSince,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildRoleStatusChip(
                  roleName: 'Member',
                  isActive: isMemberActive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRoleStatusChip(
                  roleName: 'Foreman',
                  isActive: isForemanActive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleStatusChip({
    required String roleName,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$roleName: ${isActive ? "Active" : "Not active"}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? const Color(0xFF166534)
                    : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleOption(
              label: 'Member',
              roleKey: 'member',
              icon: Icons.person_rounded,
            ),
          ),
          Expanded(
            child: _buildToggleOption(
              label: 'Foreman',
              roleKey: 'foreman',
              icon: Icons.gavel_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required String roleKey,
    required IconData icon,
  }) {
    final bool isSelected = _selectedRole == roleKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = roleKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F4C81) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePerformanceContent() {
    final roleStats = _performanceData?[_selectedRole] as Map<String, dynamic>?;
    if (roleStats == null) return const SizedBox.shrink();

    final bool isActive = roleStats['isActive'] == true;

    // Rule 3: Empty roles - show neutral message, NO score ring, NO zero values
    if (!isActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedRole == 'member'
                    ? Icons.groups_outlined
                    : Icons.gavel_outlined,
                size: 38,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedRole == 'member'
                  ? "Hasn't joined a chit yet"
                  : "Hasn't hosted a group yet",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _selectedRole == 'member'
                  ? 'No chit group memberships or subscriber reputation events recorded.'
                  : 'No organizer schemes or foreman reputation events recorded.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Role is Active: Show Reputation Ring, Tier, Stats, and (if own profile) Contact & Activity
    final double score = (roleStats['score'] as num?)?.toDouble() ?? 100.0;
    final String tier = roleStats['tier'] as String? ?? 'Tier 1';
    final int completedChits = (roleStats['completedChits'] as int?) ?? 0;
    final double onTimeRate =
        (roleStats['onTimeRate'] as num?)?.toDouble() ?? 100.0;
    final int defaults = (roleStats['defaults'] as int?) ?? 0;
    final List<ReputationEvent> events =
        (roleStats['events'] as List<dynamic>?)?.cast<ReputationEvent>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Reputation Ring & Tier
        _buildReputationRingCard(score: score, tier: tier),
        const SizedBox(height: 14),

        // 2. Performance Stats Grid
        _buildStatsGrid(
          completedChits: completedChits,
          onTimeRate: onTimeRate,
          defaults: defaults,
        ),
        const SizedBox(height: 16),

        // 3. Private Profile Sections (Masked Mobile, Email, Recent Activity)
        if (_isOwnProfile) ...[
          _buildContactInfoCard(),
          const SizedBox(height: 16),
          _buildRecentActivitySection(events),
        ] else ...[
          // Public profile disclaimer (Strictly NO phone, email, activity, group names, or KYC)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ChitGuard Public View • Sensitive contact details, group names, and activity logs are kept private.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReputationRingCard({
    required double score,
    required String tier,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Score Ring
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(
                    value: (score / 100.0).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF059669), // Emerald
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.toInt()}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'SCORE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Tier & Role Summary
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tier,
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedRole == 'member'
                      ? 'Subscriber Standing'
                      : 'Organizer Standing',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedRole == 'member'
                      ? 'Measured from on-time chit contributions and clean guarantee track record.'
                      : 'Measured from timely payout releases and spotless auction facilitation.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({
    required int completedChits,
    required double onTimeRate,
    required int defaults,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'COMPLETED CHITS',
            value: '$completedChits Chits',
            icon: Icons.verified_rounded,
            iconColor: const Color(0xFF0F4C81),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'ON-TIME RATE',
            value: '${onTimeRate.toInt()}%',
            icon: Icons.timer_rounded,
            iconColor: const Color(0xFF059669),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'DEFAULTS',
            value: '$defaults Defaults',
            icon: Icons.shield_outlined,
            iconColor: defaults > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF059669),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    final profile =
        _performanceData?['profile'] as Map<String, dynamic>? ?? {};
    final phone = _maskMobile(profile['mobile_number'] as String?);
    final email = _maskEmail(profile['email'] as String?);
    final city = profile['perm_city'] as String? ?? 'Bengaluru, India';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Private Contact Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildContactRow(
            icon: Icons.phone_android_rounded,
            label: 'Mobile',
            value: phone,
          ),
          const SizedBox(height: 8),
          _buildContactRow(
            icon: Icons.alternate_email_rounded,
            label: 'Email',
            value: email,
          ),
          const SizedBox(height: 8),
          _buildContactRow(
            icon: Icons.location_city_rounded,
            label: 'Registered City',
            value: city,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(List<ReputationEvent> events) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent ${_selectedRole == "member" ? "Member" : "Foreman"} Activity',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '${events.length} Events',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007A87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'No recent reputation events recorded for this role.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            ...events.map((ev) {
              final isPositive = ev.scoreDelta >= 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 16,
                        color: isPositive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev.description,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatEventTime(ev.createdAt),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${isPositive ? "+" : ""}${ev.scoreDelta.toInt()} pts',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPositive
                              ? const Color(0xFF166534)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatEventTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return 'Just now';
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

