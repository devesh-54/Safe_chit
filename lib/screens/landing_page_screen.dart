import 'package:flutter/material.dart';

/// Easily editable, aggressively trimmed copy constants for the ChitGuard Landing Page.
class ChitGuardLandingCopy {
  static const String appName = 'ChitGuard';

  // Hero Section (Heading: 3-6 words, Sub: under 15 words)
  static const String heroTitle = 'Protect Your Chit Group From Default';
  static const String heroSub =
      'ChitGuard protects the organizer — the person who trusts everyone else.';
  static const String heroCtaPrimary = 'Get Started';
  static const String heroCtaSecondary = 'Sign In';

  // Problem Section (Asymmetric 2-Column Split)
  static const String problemTitle = 'The Overlooked Host Risk';
  static const String problemSub =
      'Members take early pot payouts and default on remaining monthly installments.';

  static const String problem1Title = 'Foreman Fraud';
  static const String problem1Sub =
      'Dishonest organizers fleeing with pooled cash. Standard tools focus only here.';

  static const String problem2Title = 'Member Default Risk';
  static const String problem2Sub =
      'Early pot winners vanishing without paying remaining months, leaving hosts personally liable.';

  // How It Works Section (Horizontal Stepper)
  static const String howItWorksTitle = 'Four Steps to Peace of Mind';
  static const String howItWorksSub =
      'Verify identity, sign digital contracts, and automate host default protection.';

  static const List<Map<String, String>> steps = [
    {'num': '01', 'title': 'Verify Identity', 'desc': 'PAN, Aadhaar & facial liveness check.'},
    {'num': '02', 'title': 'Create Group', 'desc': 'Set pot rules & member limits.'},
    {'num': '03', 'title': 'Sign Agreement', 'desc': 'Execute legally binding digital contracts.'},
    {'num': '04', 'title': 'Track & Protect', 'desc': 'AI default prediction & secure payouts.'},
  ];

  // Features Section (Asymmetric Split Blocks)
  static const String featuresTitle = 'Built Specifically for Organizers';
  static const String featuresSub =
      'Intelligent risk scoring, security deposits, and legally structured digital agreements.';

  static const List<Map<String, dynamic>> featureBlocks = [
    {
      'icon': Icons.psychology_outlined,
      'title': 'AI Default Prediction',
      'desc': 'Scoring payment history to predict default probability before auction bids.',
    },
    {
      'icon': Icons.verified_user_outlined,
      'title': 'Deposit Protection',
      'desc': 'Hold collateral or commitment deposits to safeguard unpaid monthly installments.',
    },
    {
      'icon': Icons.description_outlined,
      'title': 'Digital Chit Agreements',
      'desc': 'Legally enforceable digital contracts for every cycle with zero physical paperwork.',
    },
    {
      'icon': Icons.lock_outline,
      'title': 'Two-Factor Payouts',
      'desc': 'Dual-authentication approval between host and winner before cash disbursement.',
    },
  ];

  // Stat Callout (Single Bold Highlight)
  static const String statTitle = 'The Scale of Unprotected Trust';
  static const String statValue = '₹3+ Lakh Crore';
  static const String statSub =
      'Informal chit funds in India operating without legal paper trails or default protection.';

  // CTA Section (Generous Whitespace Anchor)
  static const String ctaTitle = 'Host Your Next Chit Risk-Free';
  static const String ctaSub =
      'Join early organizers safeguarding their monthly chit groups with ChitGuard.';

  // Footer
  static const String footerDisclaimer =
      'ChitGuard is a facilitation tool and does not operate as a licensed chit fund company.';
}

class LandingPageScreen extends StatefulWidget {
  final VoidCallback onStartSignUp;
  final VoidCallback onOpenSignIn;

  const LandingPageScreen({
    super.key,
    required this.onStartSignUp,
    required this.onOpenSignIn,
  });

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _waitlistController = TextEditingController();
  bool _waitlistSubmitted = false;

  final GlobalKey _problemKey = GlobalKey();
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    _waitlistController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _submitWaitlist() {
    if (_waitlistController.text.trim().isNotEmpty) {
      setState(() {
        _waitlistSubmitted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Thank you for joining the ChitGuard waitlist!'),
          backgroundColor: Color(0xFF0F4C81),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Warm off-white / cream base
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Navigation Bar
            _buildNavBar(context),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    // 1. Hero Section (Visual Anchor)
                    _buildHeroSection(context),

                    // 2. Problem Section (Asymmetric 2-Column Split)
                    Container(
                      key: _problemKey,
                      child: _buildProblemSection(context),
                    ),

                    // 3. How It Works (Horizontal Line Stepper)
                    Container(
                      key: _howItWorksKey,
                      child: _buildHowItWorksSection(context),
                    ),

                    // 4. Features Section (Asymmetric Blocks)
                    Container(
                      key: _featuresKey,
                      child: _buildFeaturesSection(context),
                    ),

                    // 5. Stat Callout (Single Bold Stat Highlight)
                    Container(
                      key: _statsKey,
                      child: _buildStatCalloutSection(context),
                    ),

                    // 6. CTA Section (Visual Anchor)
                    _buildCtaSection(context),

                    // 7. Footer
                    _buildFooter(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sticky Navigation Bar
  Widget _buildNavBar(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2DACD)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            children: [
              // App Branding Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: isMobile ? 26 : 32,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Text(
                    'SafeChit',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F4C81),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Desktop Nav Links
              if (isDesktop) ...[
                TextButton(
                  onPressed: () => _scrollToSection(_problemKey),
                  child: const Text('Risk', style: TextStyle(color: Color(0xFF566573), fontSize: 14)),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _scrollToSection(_howItWorksKey),
                  child: const Text('Steps', style: TextStyle(color: Color(0xFF566573), fontSize: 14)),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _scrollToSection(_featuresKey),
                  child: const Text('Features', style: TextStyle(color: Color(0xFF566573), fontSize: 14)),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _scrollToSection(_statsKey),
                  child: const Text('Impact', style: TextStyle(color: Color(0xFF566573), fontSize: 14)),
                ),
                const SizedBox(width: 24),
              ],

              // Actions
              OutlinedButton(
                onPressed: widget.onOpenSignIn,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1C2833), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16,
                    vertical: isMobile ? 8 : 10,
                  ),
                ),
                child: Text(
                  ChitGuardLandingCopy.heroCtaSecondary,
                  style: TextStyle(
                    color: const Color(0xFF1C2833),
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ),

              SizedBox(width: isMobile ? 8 : 10),

              ElevatedButton(
                onPressed: widget.onStartSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C81),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 18,
                    vertical: isMobile ? 8 : 10,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  ChitGuardLandingCopy.heroCtaPrimary,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Hero Section (Visual Anchor with Generous Breathing Room)
  Widget _buildHeroSection(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      width: double.infinity,
      color: const Color(0xFFFAF7F2), // Warm cream background
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: isDesktop ? 80 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: _buildHeroTextContent(context, isDesktop),
        ),
      ),
    );
  }

  Widget _buildHeroTextContent(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Category Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF2ECE1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2DACD)),
          ),
          child: const Text(
            'INFORMAL CHIT FUND PROTECTION',
            style: TextStyle(
              color: Color(0xFF0F4C81),
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Main Title (3-6 words)
        Text(
          ChitGuardLandingCopy.heroTitle,
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1C2833),
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.8,
          ),
        ),

        const SizedBox(height: 16),

        // Single Supporting Line (<15 words) with Thin Gold Underline Motif
        Column(
          crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              ChitGuardLandingCopy.heroSub,
              textAlign: isDesktop ? TextAlign.left : TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF566573),
                fontSize: 16,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 120,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF0F4C81),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),

        const SizedBox(height: 36),

        // Hero Action Buttons
        Wrap(
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          spacing: 14,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: widget.onStartSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Get Started Now →',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            OutlinedButton(
              onPressed: widget.onOpenSignIn,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2DACD), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(fontSize: 15, color: Color(0xFF1C2833), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }



  // 2. Problem Section (Asymmetric 2-Column Split)
  Widget _buildProblemSection(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompactSectionHeader(
                title: ChitGuardLandingCopy.problemTitle,
                sub: ChitGuardLandingCopy.problemSub,
              ),
              const SizedBox(height: 36),
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Featured Card (60%) with Gold Border
                        Expanded(
                          flex: 6,
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFAF7F2),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                              border: Border(
                                left: BorderSide(color: Color(0xFF0F4C81), width: 4),
                                top: BorderSide(color: Color(0xFFE2DACD)),
                                right: BorderSide(color: Color(0xFFE2DACD)),
                                bottom: BorderSide(color: Color(0xFFE2DACD)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'THE UNSEEN THREAT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F4C81),
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  ChitGuardLandingCopy.problem2Title,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C2833),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  ChitGuardLandingCopy.problem2Sub,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                    color: Color(0xFF566573),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Right Secondary Card (40%)
                        Expanded(
                          flex: 4,
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2DACD)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'COMMON FOCUS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF566573),
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  ChitGuardLandingCopy.problem1Title,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C2833),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  ChitGuardLandingCopy.problem1Sub,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                    color: Color(0xFF566573),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFAF7F2),
                            border: Border(
                              left: BorderSide(color: Color(0xFF0F4C81), width: 4),
                              top: BorderSide(color: Color(0xFFE2DACD)),
                              right: BorderSide(color: Color(0xFFE2DACD)),
                              bottom: BorderSide(color: Color(0xFFE2DACD)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                ChitGuardLandingCopy.problem2Title,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1C2833),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                ChitGuardLandingCopy.problem2Sub,
                                style: TextStyle(fontSize: 14, color: Color(0xFF566573)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE2DACD)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                ChitGuardLandingCopy.problem1Title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1C2833),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                ChitGuardLandingCopy.problem1Sub,
                                style: TextStyle(fontSize: 14, color: Color(0xFF566573)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. How It Works Section (Horizontal Line Stepper)
  Widget _buildHowItWorksSection(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF2ECE1), // Warm sand background
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompactSectionHeader(
                title: ChitGuardLandingCopy.howItWorksTitle,
                sub: ChitGuardLandingCopy.howItWorksSub,
              ),
              const SizedBox(height: 40),
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: ChitGuardLandingCopy.steps.map((st) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F4C81),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    st['num']!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  st['title']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C2833),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  st['desc']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF566573),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  : Column(
                      children: ChitGuardLandingCopy.steps.map((st) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F4C81),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  st['num']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      st['title']!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1C2833),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      st['desc']!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF566573),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Features Section (Asymmetric Blocks)
  Widget _buildFeaturesSection(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      width: double.infinity,
      color: const Color(0xFFFAF7F2),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompactSectionHeader(
                title: ChitGuardLandingCopy.featuresTitle,
                sub: ChitGuardLandingCopy.featuresSub,
              ),
              const SizedBox(height: 36),
              isDesktop
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildFeatureBlock(ChitGuardLandingCopy.featureBlocks[0])),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFeatureBlock(ChitGuardLandingCopy.featureBlocks[1])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildFeatureBlock(ChitGuardLandingCopy.featureBlocks[2])),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFeatureBlock(ChitGuardLandingCopy.featureBlocks[3])),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      children: ChitGuardLandingCopy.featureBlocks.map((f) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          child: _buildFeatureBlock(f),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBlock(Map<String, dynamic> f) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2DACD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            f['icon'] as IconData,
            color: const Color(0xFF0F4C81),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f['title'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C2833),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  f['desc'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF566573),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. Stat Callout Section (Single Bold Statement Banner)
  Widget _buildStatCalloutSection(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1C2833), // Contrast charcoal background for single callout
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              const Text(
                ChitGuardLandingCopy.statTitle,
                style: TextStyle(
                  color: Color(0xFFE2DACD),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                ChitGuardLandingCopy.statValue,
                style: TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: const Text(
                  ChitGuardLandingCopy.statSub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 6. CTA Section (Visual Anchor with Generous Breathing Room)
  Widget _buildCtaSection(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      width: double.infinity,
      color: const Color(0xFFFAF7F2),
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 72 : 48,
        horizontal: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2DACD), width: 1.5),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF0F4C81),
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  ChitGuardLandingCopy.ctaTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C2833),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  ChitGuardLandingCopy.ctaSub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF566573),
                  ),
                ),
                const SizedBox(height: 28),

                // Primary Actions
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: widget.onStartSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F4C81),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Start 10-Step Setup',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: widget.onOpenSignIn,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1C2833), width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(color: Color(0xFF1C2833), fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE2DACD)),
                const SizedBox(height: 16),

                // Waitlist Capture
                _waitlistSubmitted
                    ? const Text(
                        '✓ You are on the priority early access list.',
                        style: TextStyle(color: Color(0xFF0F4C81), fontWeight: FontWeight.bold, fontSize: 13),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _waitlistController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter phone or email',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                fillColor: const Color(0xFFFAF7F2),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFE2DACD)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _submitWaitlist,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F4C81),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text('Waitlist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 7. Footer
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        border: Border(top: BorderSide(color: Color(0xFFE2DACD))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Text(
                        'SafeChit',
                        style: TextStyle(
                          color: Color(0xFF1C2833),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                ChitGuardLandingCopy.footerDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSectionHeader({required String title, required String sub}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C2833),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF566573),
          ),
        ),
      ],
    );
  }
}
