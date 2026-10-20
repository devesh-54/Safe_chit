# SafeChit — Complete Project State, Architecture & Handover Document

> **Project Name:** SafeChit (Decentralized & Transparent Digital Chit Fund Platform)  
> **Last Verified & Updated:** October 2026  
> **Target Platforms:** Android (Primary), Web, Desktop  
> **Workspace Path:** `c:\Users\deves\OneDrive\project_main\Safe_chit`  

---

## 1. Executive Summary & Core Mission

**SafeChit** transforms traditional Chit Funds (Rotating Savings and Credit Associations - ROSCA) into a modern, transparent, and legally compliant digital platform. It combines:
1. **0% Fee Direct Bank-to-Bank P2P Payments (YouPI)**: Members transfer monthly installments directly to the Foreman's bank account with zero intermediary commissions or wallet lockups.
2. **Deterministic 7-Step KYC & Onboarding**: Ensuring all participants (Foremen and Members) are vetted under the Chit Funds Act, 1982.
3. **Real-Time Reverse Auction Engine**: Live transparent bidding rooms with a statutory 30% discount cap and automated dividend distribution.
4. **Host Console & Exposure Risk Profiling**: Live risk modeling, default exposure tracking, and Section 20-compliant escrow disbursal.
5. **Cryptographic & Legal Compliance**: Dual-signed touch contracts, HMAC-SHA256 signature verification, and automated audit logging.

---

## 2. Verified Technology Stack & Directory Structure

```text
Safe_chit/
├── backend/
│   ├── .env                                       # Environment configuration
│   ├── 01_user_onboardings.sql                    # KYC & identity schemas
│   ├── 02_foreman_login_seed.sql                  # Foreman test seeds
│   ├── 03_chit_groups_and_join_requests.sql       # Groups & join request tables
│   ├── 04_waitlist.sql                            # Capacity waitlist management
│   ├── 05_scheme_types_agreements_and_marketplace.sql # Scheme rules & contracts
│   ├── 06_member_login_seed.sql                   # Member test seeds
│   ├── 07_chit_payments_and_transactions.sql      # YouPI transactions & RLS policies
│   ├── supabase_setup.sql                         # Consolidated Supabase migration script
│   ├── youpi_webhook_handler.js                   # Timing-safe HMAC webhook server (Port 3000)
│   └── server.js                                  # Razorpay gateway backup server
├── lib/
│   ├── main.dart                                  # Application entry & routing
│   ├── models/
│   │   ├── chit_group.dart                        # Chit group data model
│   │   ├── chit_join_request.dart                 # Join application model
│   │   ├── chit_payment_record.dart               # Ledger payment model
│   │   ├── digital_agreement.dart                 # Legal contract model
│   │   ├── member_risk.dart                       # Subscriber risk profiling model
│   │   └── onboarding_state.dart                  # KYC onboarding state model
│   ├── services/
│   │   ├── supabase_service.dart                  # Supabase client (Auth, DB, Realtime)
│   │   └── youpi_payment_service.dart             # Canonical UPI URIs, Intent packaging & HMAC
│   ├── widgets/
│   │   ├── youpi_payment_modal.dart               # Interactive 1-tap UPI launch, QR & single-slot queue
│   │   ├── premium_date_picker.dart               # Modern date picker
│   │   ├── progress_header.dart                   # Step progress bar
│   │   └── status_badge.dart                      # Pill status indicators
│   ├── screens/
│   │   ├── role_selection_screen.dart             # Role picker (Foreman vs Member)
│   │   ├── landing_page_screen.dart               # Marketing & overview landing
│   │   ├── sign_in_screen.dart                    # Auth login
│   │   ├── credentials_setup_screen.dart          # Pin & password setup
│   │   ├── personal_identity_screen.dart          # KYC Step 1: Personal Info
│   │   ├── gov_id_verification_screen.dart        # KYC Step 2: Aadhaar & PAN validation
│   │   ├── address_screen.dart                    # KYC Step 3: Address & Pincode
│   │   ├── bank_verification_screen.dart          # KYC Step 4: Bank account & IFSC
│   │   ├── biometric_liveness_screen.dart         # KYC Step 5: Camera face liveness test
│   │   ├── consent_screen.dart                    # KYC Step 6: T&C & legal consent
│   │   ├── verification_summary_screen.dart       # KYC Step 7: Summary review
│   │   ├── account_setup_screen.dart              # Post-KYC finalization
│   │   ├── common/
│   │   │   ├── digital_agreement_modal.dart       # Touch signature Pad & contract generator
│   │   │   └── group_details_modal.dart           # Multi-tab group & ledger inspector
│   │   ├── foreman/
│   │   │   ├── foreman_dashboard_screen.dart      # Real-time console, risk metrics & VPA card
│   │   │   ├── create_group_screen.dart           # Group creation with ₹5/₹1 testing presets
│   │   │   └── escrow_controls_screen.dart        # Escrow reserve management
│   │   └── member/
│   │       └── member_dashboard_screen.dart       # Installment cards, YouPI triggers & enrolled chits
│   └── features/
│       └── bidding/
│           ├── host_schedule_screen.dart          # Auction scheduling
│           ├── bidding_waiting_room.dart          # Countdown clock & attendance
│           ├── live_bidding_room.dart             # Live reverse auction room (30% cap)
│           ├── auction_close_payout.dart          # Prize & dividend calculation
│           └── bidding_session_service.dart       # Session state engine
├── test/
│   └── youpi_transaction_integration_test.dart    # 6 passing unit & integration tests
├── android/app/src/main/AndroidManifest.xml       # Android 11+ <queries> for NPCI UPI packages
├── PAYMENT_TRANSACTION_ARCHITECTURE_GUIDE.md      # Full architecture & security documentation
└── pubspec.yaml                                   # Dependencies & assets
```

---

## 3. Comprehensive Feature Verification & Inventory

### Pillar 1: Zero-Fee P2P UPI Payment Gateway (YouPI Integration)
- [x] **Direct Bank-to-Bank Transfers**: 0% intermediary fee routing directly to the Foreman's configured VPA.
- [x] **Foreman Receiving UPI ID Configuration**:
  - Configurable directly from the Host Console (`foreman_dashboard_screen.dart`) and during Group Creation (`create_group_screen.dart`).
  - Automatically injected into dynamic payment intents and vector QR codes.
- [x] **Micro-Testing Mode (₹5 Pool / ₹1 Installment)**:
  - Default group pool size reduced to ₹5.00 and monthly contribution to ₹1.00 for risk-free real-app testing.
  - Quick-preset chips available in the group creation wizard.
- [x] **Interactive Payment Modal (`YoupiPaymentModal`)**:
  - **1-Tap UPI Launch**: Deep-links to Google Pay, PhonePe, Paytm, BHIM, CRED, or Amazon Pay with exact amount, payee name, and note prefilled.
  - **Dynamic Vector QR Code**: Live SVG/Vector QR rendering for camera scan & pay.
  - **Deterministic 5-Minute Single-Slot Queue**: Active countdown window preventing attribution clashes between concurrent payers.
  - **Copy VPA Bar**: 1-click clipboard copy of the recipient's UPI ID.
  - **Simulate Credit Button**: Sandbox trigger for testing instant status confirmation.
- [x] **Foreman Cash Counter Settlement (`CASH_COUNTER`)**:
  - Ability to record and confirm physical in-person cash payments at monthly meetings with audit notes in the ledger.
- [x] **Cryptographic Security**:
  - HMAC-SHA256 signature verification with timing-safe comparison (`crypto.timingSafeEqual`) preventing timing and replay attacks.
- [x] **Android Intent Packaging**:
  - Configured `AndroidManifest.xml` with Android 11+ `<queries>` declarations for all NPCI UPI package schemes (`com.google.android.apps.nbu.paisa.user`, `net.one97.paytm`, `com.phonepe.app`, etc.).

---

### Pillar 2: Foreman / Host Management Console
- [x] **Host Dashboard Screen (`foreman_dashboard_screen.dart`)**:
  - **Real-Time Stream Listener**: Live Supabase channel streaming and background polling updating subscriber statuses dynamically.
  - **Primary Exposure Risk Metric**: Real-time calculation of total at-risk capital based on unprized default exposure.
  - **Receiving UPI VPA Card**: Prominent badge displaying the active UPI ID (`devesh1@oksbi`) with an interactive edit modal and suggestion chips.
  - **Subscriber Risk Profiling**: Default risk scoring, delayed payment trends, and guarantor verification indicators.
  - **Explainable Risk Modal**: Tap any member to view full default risk breakdowns.
  - **Group Management & Payout Order**: Locked assigned turns vs. re-orderable subscriber payout positions.
  - **Escrow Payout Disbursal**: Visual payout celebration dialog compliant with Section 20 of the Chit Funds Act, 1982.
- [x] **Create Chit Group Screen (`create_group_screen.dart`)**:
  - Scheme type selection: Reverse Bidding vs. Random Picking (Lucky Draw).
  - Total pool size slider with Quick Test presets (₹5 pool, ₹50K, ₹1L, ₹10L).
  - Capacity & duration sliders with auto-calculated monthly installments.
  - 6-digit numeric invite code generation (e.g. `849201`).
  - Mandatory Host Digital Agreement signing before group registration.

---

### Pillar 3: Member / Subscriber Experience
- [x] **Member Dashboard Screen (`member_dashboard_screen.dart`)**:
  - **Upcoming Installments Card**: Lists all due monthly contributions with a 1-tap "Pay via UPI" button opening `YoupiPaymentModal`.
  - **Live Join Request Tracking**: Real-time status tracking for pending, approved, or rejected applications.
  - **Group Discovery & Code Search**: Join groups using 6-digit invite codes or public marketplace discovery.
  - **My Enrolled Chits**: Visual progress cards displaying cycle progress, due dates, and payout positions.
- [x] **Group Details Modal (`group_details_modal.dart`)**:
  - Interactive multi-tab inspector: Overview, Member Roster, Bidding Room, and Dual Confirmation Payout Ledger.
  - Shows Foreman Receiving UPI ID and escrow security deposits.

---

### Pillar 4: Digital Legal Agreements (Chit Funds Act, 1982)
- [x] **Automated Contract Generation**: `DigitalAgreement` engine generating standard legal agreements containing Chit Funds Act 1982 clauses, subscriber commitments, and Foreman escrow liabilities.
- [x] **Digital Agreement Signing Modal (`digital_agreement_modal.dart`)**:
  - Interactive touch signature pad for both Host and Subscriber.
  - Dual-signed agreements stored in Supabase with timestamps and audit hashes.

---

### Pillar 5: Chit Fund Auction & Payout Engine
- [x] **Live Bidding Room (`live_bidding_room.dart`)**:
  - Real-time reverse auction countdown timer.
  - Statutory 30% discount cap enforcement.
  - Dynamic minimum bid increments scaled to the pool size (5% starting discount).
- [x] **Auction Close & Dividend Disbursal (`auction_close_payout.dart`)**:
  - Auto-calculates prize take-home payout (Pool Size minus Winning Bid Discount).
  - Distributes the winning discount evenly across all non-winning members as monthly dividends.
- [x] **Random Picking (Lucky Draw)**:
  - Automated transparent random draw for non-bidding chit schemes.

---

### Pillar 6: KYC & User Onboarding Pipeline
- [x] **Role Selection**: Toggle between Subscriber Member and Licensed Foreman / Host.
- [x] **Account Setup**: Mobile and Email verification with OTP simulation.
- [x] **Personal & Identity Verification**: Name, DOB, Gender, PAN, and Aadhaar collection with document upload to Supabase Storage.
- [x] **Address Capture**: Permanent and current address verification with PIN code validation.
- [x] **Bank Account Setup**: Account number, IFSC lookup, and auto-debit mandate setup.
- [x] **Offline / In-Memory Fallback**: Local simulation support for all credentials when developing without a cloud connection.

---

### Pillar 7: Backend, Webhooks & Automated Testing
- [x] **Database Schema (`07_chit_payments_and_transactions.sql`)**:
  - `chit_payments` table tracking payment method (`UPI`, `CASH_COUNTER`, `CARD_COUNTER`), transaction references, paise calculations, UTR numbers, and timestamp tracking.
  - Row Level Security (RLS) policies for members and foremen.
- [x] **Webhook Server (`backend/youpi_webhook_handler.js`)**:
  - Express server on port 3000 handling incoming payment webhook notifications with timing-safe HMAC validation.
- [x] **Automated Integration Tests (`test/youpi_transaction_integration_test.dart`)**:
  - **6 of 6 tests passing** (Exit Code: 0):
    1. `ChitPaymentRecord` serializes and deserializes accurately.
    2. Canonical UPI URI Generator creates valid NPCI format for ₹1.00 testing.
    3. Android Intent URI properly packages target UPI apps for ₹1.00 to `devesh1@oksbi`.
    4. Cryptographic HMAC-SHA256 signature verification blocks tampering.
    5. SafeChit Ledger handles UPI recording & Foreman Cash Confirmation (`CASH_COUNTER`).
    6. Chit Group pool defaults to ₹5.00 with ₹1.00 contribution & Foreman UPI configuration updates.
- [x] **Documentation (`PAYMENT_TRANSACTION_ARCHITECTURE_GUIDE.md`)**:
  - Technical guide detailing HMAC-SHA256, single-slot queues, debit vs credit rules, and banking observer architecture.

---

## 4. Verification Proof

Execution of the integration test suite confirms 100% pass rate:
```text
PS C:\Users\deves\OneDrive\project_main\Safe_chit> flutter test test/youpi_transaction_integration_test.dart
00:00 +0: loading test/youpi_transaction_integration_test.dart
00:00 +1: 1. ChitPaymentRecord serializes and deserializes accurately
00:00 +2: 2. Canonical UPI URI Generator creates valid NPCI format for ₹1.00 testing
00:00 +3: 3. Android Intent URI properly packages target UPI apps for ₹1.00 to devesh1@oksbi
00:00 +4: 4. Cryptographic HMAC-SHA256 signature verification blocks tampering
00:00 +5: 5. SafeChit Ledger handles UPI recording & Foreman Cash Confirmation (CASH_COUNTER)
00:00 +6: 6. Chit Group pool defaults to ₹5.00 with ₹1.00 contribution & Foreman UPI configuration updates
00:00 +6: All tests passed!
```
