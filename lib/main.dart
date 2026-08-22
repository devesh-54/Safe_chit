import 'package:flutter/material.dart';
import 'models/onboarding_state.dart';
import 'services/supabase_service.dart';
import 'widgets/progress_header.dart';
import 'screens/landing_page_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/account_setup_screen.dart';
import 'screens/personal_identity_screen.dart';
import 'screens/gov_id_verification_screen.dart';
import 'screens/biometric_liveness_screen.dart';
import 'screens/address_screen.dart';
import 'screens/bank_verification_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/credentials_setup_screen.dart';
import 'screens/verification_summary_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const ChitGuardApp());
}

enum AppView {
  landing,
  signIn,
  onboarding,
}

class ChitGuardApp extends StatelessWidget {
  const ChitGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChitGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C81),
          primary: const Color(0xFF0F4C81),
          secondary: const Color(0xFF007A87),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: const AppContainer(),
    );
  }
}

class AppContainer extends StatefulWidget {
  const AppContainer({super.key});

  @override
  State<AppContainer> createState() => _AppContainerState();
}

class _AppContainerState extends State<AppContainer> {
  AppView _currentView = AppView.landing;

  void _navigateTo(AppView view) {
    setState(() {
      _currentView = view;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentView) {
      case AppView.landing:
        return LandingPageScreen(
          onStartSignUp: () => _navigateTo(AppView.onboarding),
          onOpenSignIn: () => _navigateTo(AppView.signIn),
        );
      case AppView.signIn:
        return SignInScreen(
          onStartSignUp: () => _navigateTo(AppView.onboarding),
          onBackToLanding: () => _navigateTo(AppView.landing),
        );
      case AppView.onboarding:
        return OnboardingContainer(
          onBackToLanding: () => _navigateTo(AppView.landing),
        );
    }
  }
}

class OnboardingContainer extends StatefulWidget {
  final VoidCallback? onBackToLanding;

  const OnboardingContainer({
    super.key,
    this.onBackToLanding,
  });

  @override
  State<OnboardingContainer> createState() => _OnboardingContainerState();
}

class _OnboardingContainerState extends State<OnboardingContainer> {
  late OnboardingState _onboardingState;

  @override
  void initState() {
    super.initState();
    _onboardingState = OnboardingState();
  }

  void _resetOnboarding() {
    setState(() {
      _onboardingState = OnboardingState();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Onboarding flow reset to beginning.'),
        backgroundColor: Color(0xFF334155),
      ),
    );
  }

  Widget _buildScreen(int step) {
    switch (step) {
      case 1:
        return RoleSelectionScreen(
          state: _onboardingState,
          onContinue: () => _onboardingState.nextStep(),
        );
      case 2:
        return AccountSetupScreen(
          state: _onboardingState,
          onContinue: () => _onboardingState.nextStep(),
        );
      case 3:
        return PersonalIdentityScreen(
          state: _onboardingState,
          onContinue: () => _onboardingState.nextStep(),
        );
      case 4:
        return GovIdVerificationScreen(
          state: _onboardingState,
          onContinue: () => _onboardingState.nextStep(),
        );
      case 5:
        return BiometricLivenessScreen(
          state: _onboardingState,
          onContinue: () => _onboardingState.nextStep(),
        );
      case 6:
        return AddressScreen(
          state: _onboardingState,
          onContinue: () => _onboardingState.nextStep(),
        );
      case 7:
        return BankVerificationScreen(
          state: _onboardingState,
          onContinue: () => _onboardingState.nextStep(),
        );
      case 8:
        return ConsentScreen(
          state: _onboardingState,
          onContinue: () => _onboardingState.nextStep(),
        );
      case 9:
        return CredentialsSetupScreen(
          state: _onboardingState,
          onContinue: () => _onboardingState.nextStep(),
        );
      case 10:
        return VerificationSummaryScreen(
          state: _onboardingState,
          onRestart: () {
            _resetOnboarding();
            if (widget.onBackToLanding != null) {
              widget.onBackToLanding!();
            }
          },
        );
      default:
        return const Center(child: Text('Unknown Step'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _onboardingState,
      builder: (context, child) {
        final step = _onboardingState.currentStep;
        final hasHeader = step > 0;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                if (hasHeader)
                  ProgressHeader(
                    currentStep: step,
                    totalSteps: 10,
                    onBackPressed: step > 1
                        ? () => _onboardingState.prevStep()
                        : (widget.onBackToLanding != null ? widget.onBackToLanding : null),
                    onSummaryPressed: step < 10
                        ? () {
                            if (!_onboardingState.tryNavigateTo(10)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cannot skip directly to summary. Please complete all preceding steps first.'),
                                  backgroundColor: Color(0xFFDC2626),
                                ),
                              );
                            }
                          }
                        : null,
                    showSummaryIcon: step < 10,
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(step),
                      child: _buildScreen(step),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

