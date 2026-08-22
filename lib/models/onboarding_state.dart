import 'package:flutter/material.dart';

enum VerificationStatus {
  notStarted,
  inProgress,
  verified,
  failed,
}

enum UserRole {
  member,
  host,
}

class OnboardingState extends ChangeNotifier {
  int _currentStep = 1;
  int get currentStep => _currentStep;

  UserRole? _role;
  UserRole? get role => _role;

  // Step 2: Account Setup (Mobile + Email)
  String _mobileNumber = '';
  String get mobileNumber => _mobileNumber;
  VerificationStatus _mobileStatus = VerificationStatus.notStarted;
  VerificationStatus get mobileStatus => _mobileStatus;

  String _emailAddress = '';
  String get emailAddress => _emailAddress;
  VerificationStatus _emailStatus = VerificationStatus.notStarted;
  VerificationStatus get emailStatus => _emailStatus;

  // Step 3: Personal Identity
  String _legalName = '';
  String get legalName => _legalName;
  DateTime? _dob;
  DateTime? get dob => _dob;
  String? _gender;
  String? get gender => _gender;
  VerificationStatus _identityStatus = VerificationStatus.notStarted;
  VerificationStatus get identityStatus => _identityStatus;

  // Step 4: Government ID Verification
  String _panNumber = '';
  String get panNumber => _panNumber;
  VerificationStatus _panStatus = VerificationStatus.notStarted;
  VerificationStatus get panStatus => _panStatus;

  String _aadhaarNumber = '';
  String get aadhaarNumber => _aadhaarNumber;
  VerificationStatus _aadhaarStatus = VerificationStatus.notStarted;
  VerificationStatus get aadhaarStatus => _aadhaarStatus;

  String? _idDocumentPath; // path to mock ID doc image
  String? get idDocumentPath => _idDocumentPath;

  VerificationStatus _govIdStatus = VerificationStatus.notStarted;
  VerificationStatus get govIdStatus => _govIdStatus;

  // Step 5: Biometric / Liveness
  String? _selfiePath; // path to mock selfie image
  String? get selfiePath => _selfiePath;
  String _livenessPrompt = 'Blink slowly';
  String get livenessPrompt => _livenessPrompt;
  VerificationStatus _biometricStatus = VerificationStatus.notStarted;
  VerificationStatus get biometricStatus => _biometricStatus;

  // Step 6: Address
  String _permAddress = '';
  String get permAddress => _permAddress;
  String _permCity = '';
  String get permCity => _permCity;
  String _permState = '';
  String get permState => _permState;
  String _permPinCode = '';
  String get permPinCode => _permPinCode;

  bool _isCurrentSameAsPermanent = true;
  bool get isCurrentSameAsPermanent => _isCurrentSameAsPermanent;

  String _currAddress = '';
  String get currAddress => _currAddress;
  String _currCity = '';
  String get currCity => _currCity;
  String _currState = '';
  String get currState => _currState;
  String _currPinCode = '';
  String get currPinCode => _currPinCode;

  VerificationStatus _addressStatus = VerificationStatus.notStarted;
  VerificationStatus get addressStatus => _addressStatus;

  // Step 7: Bank Verification
  String _bankAccountNumber = '';
  String get bankAccountNumber => _bankAccountNumber;
  String _bankIfsc = '';
  String get bankIfsc => _bankIfsc;
  String _bankName = '';
  String get bankName => _bankName;
  String _bankBranch = '';
  String get bankBranch => _bankBranch;
  VerificationStatus _bankStatus = VerificationStatus.notStarted;
  VerificationStatus get bankStatus => _bankStatus;

  // Step 8: Consent
  bool _hasConsented = false;
  bool get hasConsented => _hasConsented;
  VerificationStatus _consentStatus = VerificationStatus.notStarted;
  VerificationStatus get consentStatus => _consentStatus;

  // Global verification summary status
  VerificationStatus get overallStatus {
    final list = [
      _mobileStatus,
      _emailStatus,
      _identityStatus,
      _govIdStatus,
      _biometricStatus,
      _addressStatus,
      _bankStatus,
      _consentStatus,
    ];

    if (list.contains(VerificationStatus.failed)) {
      return VerificationStatus.failed;
    }
    if (list.every((s) => s == VerificationStatus.verified)) {
      return VerificationStatus.verified;
    }
    return VerificationStatus.inProgress;
  }

  // --- Step 1: Role Selection ---
  void selectRole(UserRole selectedRole) {
    _role = selectedRole;
    notifyListeners();
  }

  bool isRoleSelectionValid() {
    return _role != null;
  }

  // --- Step 2: Account Setup ---
  void setMobileNumber(String num) {
    _mobileNumber = num;
    if (_mobileStatus == VerificationStatus.verified) {
      _mobileStatus = VerificationStatus.notStarted;
    }
    notifyListeners();
  }

  Future<void> sendMobileOtp() async {
    _mobileStatus = VerificationStatus.inProgress;
    notifyListeners();
    // Simulate API request delay
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  Future<bool> verifyMobileOtp(String otp) async {
    // Simulating checking OTP
    _mobileStatus = VerificationStatus.inProgress;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (otp == '123456' || otp.length == 6) {
      _mobileStatus = VerificationStatus.verified;
      notifyListeners();
      return true;
    } else {
      _mobileStatus = VerificationStatus.failed;
      notifyListeners();
      return false;
    }
  }

  void setEmailAddress(String email) {
    _emailAddress = email;
    if (_emailStatus == VerificationStatus.verified) {
      _emailStatus = VerificationStatus.notStarted;
    }
    notifyListeners();
  }

  Future<bool> verifyEmail() async {
    if (_emailAddress.isEmpty || !_emailAddress.contains('@')) {
      _emailStatus = VerificationStatus.failed;
      notifyListeners();
      return false;
    }
    _emailStatus = VerificationStatus.inProgress;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1500));
    _emailStatus = VerificationStatus.verified;
    notifyListeners();
    return true;
  }

  bool isAccountSetupValid() {
    return _mobileStatus == VerificationStatus.verified &&
        _emailStatus == VerificationStatus.verified;
  }

  // --- Step 3: Personal Identity ---
  void setPersonalIdentity({
    required String name,
    required DateTime? dateOfBirth,
    String? selectGender,
  }) {
    _legalName = name;
    _dob = dateOfBirth;
    _gender = selectGender;
    
    if (_legalName.isNotEmpty && _dob != null) {
      _identityStatus = VerificationStatus.verified;
    } else {
      _identityStatus = VerificationStatus.notStarted;
    }
    notifyListeners();
  }

  bool isPersonalIdentityValid() {
    return _legalName.isNotEmpty && _dob != null && _identityStatus == VerificationStatus.verified;
  }

  // --- Step 4: Government ID Verification ---
  void setPanNumber(String pan) {
    _panNumber = pan.toUpperCase();
    notifyListeners();
  }

  void setAadhaarNumber(String aadhaar) {
    _aadhaarNumber = aadhaar;
    notifyListeners();
  }

  void setIdDocumentPath(String? path) {
    _idDocumentPath = path;
    notifyListeners();
  }

  Future<bool> verifyGovernmentIds() async {
    _govIdStatus = VerificationStatus.inProgress;
    notifyListeners();

    // Simulate government database query/OCR check
    await Future.delayed(const Duration(seconds: 2));

    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    final isPanValid = panRegex.hasMatch(_panNumber);
    final isAadhaarValid = _aadhaarNumber.length == 12 && RegExp(r'^[0-9]+$').hasMatch(_aadhaarNumber);
    final hasDoc = _idDocumentPath != null;

    if (isPanValid && isAadhaarValid && hasDoc) {
      _govIdStatus = VerificationStatus.verified;
      notifyListeners();
      return true;
    } else {
      _govIdStatus = VerificationStatus.failed;
      notifyListeners();
      return false;
    }
  }

  bool isGovIdValid() {
    return _govIdStatus == VerificationStatus.verified;
  }

  // --- Step 5: Biometric / Liveness ---
  void setSelfiePath(String? path) {
    _selfiePath = path;
    notifyListeners();
  }

  void setLivenessPrompt(String prompt) {
    _livenessPrompt = prompt;
    notifyListeners();
  }

  Future<void> confirmSelfieLiveness() async {
    if (_selfiePath == null) return;
    _biometricStatus = VerificationStatus.inProgress;
    notifyListeners();

    // Mock liveness analysis check
    await Future.delayed(const Duration(milliseconds: 1500));
    _biometricStatus = VerificationStatus.verified;
    notifyListeners();
  }

  void resetBiometrics() {
    _selfiePath = null;
    _biometricStatus = VerificationStatus.notStarted;
    notifyListeners();
  }

  bool isBiometricValid() {
    return _biometricStatus == VerificationStatus.verified;
  }

  // --- Step 6: Address ---
  void setPermanentAddress({
    required String address,
    required String city,
    required String state,
    required String pinCode,
  }) {
    _permAddress = address;
    _permCity = city;
    _permState = state;
    _permPinCode = pinCode;
    _checkAddressStatus();
  }

  void setCurrentAddress({
    required String address,
    required String city,
    required String state,
    required String pinCode,
  }) {
    _currAddress = address;
    _currCity = city;
    _currState = state;
    _currPinCode = pinCode;
    _checkAddressStatus();
  }

  void setSameAsPermanent(bool val) {
    _isCurrentSameAsPermanent = val;
    if (_isCurrentSameAsPermanent) {
      _currAddress = _permAddress;
      _currCity = _permCity;
      _currState = _permState;
      _currPinCode = _permPinCode;
    } else {
      _currAddress = '';
      _currCity = '';
      _currState = '';
      _currPinCode = '';
    }
    _checkAddressStatus();
  }

  void _checkAddressStatus() {
    final isPermValid = _permAddress.isNotEmpty &&
        _permCity.isNotEmpty &&
        _permState.isNotEmpty &&
        _permPinCode.length == 6;

    final isCurrValid = _isCurrentSameAsPermanent ||
        (_currAddress.isNotEmpty &&
            _currCity.isNotEmpty &&
            _currState.isNotEmpty &&
            _currPinCode.length == 6);

    if (isPermValid && isCurrValid) {
      _addressStatus = VerificationStatus.verified;
    } else {
      _addressStatus = VerificationStatus.notStarted;
    }
    notifyListeners();
  }

  bool isAddressValid() {
    return _addressStatus == VerificationStatus.verified;
  }

  // --- Step 7: Bank Verification ---
  void setBankDetails(String accountNo, String ifsc) {
    _bankAccountNumber = accountNo;
    _bankIfsc = ifsc.toUpperCase();
    
    // Reset autofill if IFSC changes
    if (_bankIfsc.length < 11) {
      _bankName = '';
      _bankBranch = '';
      _bankStatus = VerificationStatus.notStarted;
    }
    notifyListeners();
  }

  Future<bool> lookupIfsc(String ifsc) async {
    _bankIfsc = ifsc.toUpperCase();
    if (_bankIfsc.length != 11) {
      _bankStatus = VerificationStatus.failed;
      notifyListeners();
      return false;
    }

    _bankStatus = VerificationStatus.inProgress;
    notifyListeners();

    // Mock IFSC Lookup API
    await Future.delayed(const Duration(milliseconds: 1500));

    // Assume standard pattern checks out
    if (RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(_bankIfsc)) {
      final bankCode = _bankIfsc.substring(0, 4);
      if (bankCode == 'SBIN') {
        _bankName = 'State Bank of India';
        _bankBranch = 'Indiranagar Bangalore Branch';
      } else if (bankCode == 'HDFC') {
        _bankName = 'HDFC Bank';
        _bankBranch = 'Koramangala 4th Block Branch';
      } else if (bankCode == 'ICIC') {
        _bankName = 'ICICI Bank';
        _bankBranch = 'M.G. Road Branch';
      } else {
        _bankName = '${_bankIfsc.substring(0, 4)} Cooperative Bank';
        _bankBranch = 'Metro Hub Main Branch';
      }
      _bankStatus = VerificationStatus.verified;
      notifyListeners();
      return true;
    } else {
      _bankName = '';
      _bankBranch = '';
      _bankStatus = VerificationStatus.failed;
      notifyListeners();
      return false;
    }
  }

  bool isBankValid() {
    return _bankStatus == VerificationStatus.verified && _bankAccountNumber.isNotEmpty;
  }

  // --- Step 8: Consent ---
  void setConsent(bool val) {
    _hasConsented = val;
    _consentStatus = val ? VerificationStatus.verified : VerificationStatus.notStarted;
    notifyListeners();
  }

  bool isConsentValid() {
    return _consentStatus == VerificationStatus.verified;
  }

  // --- Step 10: Account Credentials (Username & Password) ---
  String _username = '';
  String get username => _username;

  String _password = '';
  String get password => _password;

  VerificationStatus _credentialsStatus = VerificationStatus.notStarted;
  VerificationStatus get credentialsStatus => _credentialsStatus;

  void setCredentials(String username, String password) {
    _username = username.trim();
    _password = password;
    _credentialsStatus = (_username.isNotEmpty && _password.length >= 6)
        ? VerificationStatus.verified
        : VerificationStatus.notStarted;
    notifyListeners();
  }

  bool isCredentialsValid() {
    return _username.isNotEmpty && _password.length >= 6 && _credentialsStatus == VerificationStatus.verified;
  }

  // Navigation controls based on current step requirements
  bool isStepValid(int step) {
    switch (step) {
      case 1:
        return isRoleSelectionValid();
      case 2:
        return isAccountSetupValid();
      case 3:
        return isPersonalIdentityValid();
      case 4:
        return isGovIdValid();
      case 5:
        return isBiometricValid();
      case 6:
        return isAddressValid();
      case 7:
        return isBankValid();
      case 8:
        return isConsentValid();
      case 9:
        return true; // Step 9: Verification Summary
      case 10:
        return isCredentialsValid(); // Step 10: Username & Password Credentials
      default:
        return false;
    }
  }

  void nextStep() {
    if (_currentStep < 10) {
      _currentStep++;
      notifyListeners();
    }
  }

  void prevStep() {
    if (_currentStep > 1) {
      _currentStep--;
      notifyListeners();
    }
  }

  // Set step directly if validation permits
  bool tryNavigateTo(int step) {
    // Check if previous steps are valid
    for (int i = 1; i < step; i++) {
      if (!isStepValid(i)) {
        return false;
      }
    }
    _currentStep = step;
    notifyListeners();
    return true;
  }
}
