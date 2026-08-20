# 🛡️ ChitGuard (Safe Chit) Onboarding

ChitGuard is a secure, state-of-the-art onboarding and KYC (Know Your Customer) flow designed to verify and register members and hosts (foremen) for decentralized and transparent chit fund cycles. Built with Flutter, it ensures safety, regulatory compliance, and a seamless user experience.

---

## 📱 Features

The application orchestrates a comprehensive **9-step onboarding and verification journey**:

1. **Role Selection**: Select whether you are joining as a **Member** (saving/borrowing) or a **Host/Foreman** (creating/managing cycles).
2. **Account Setup**: Double verification of mobile number (mock OTP: `123456`) and email address.
3. **Personal Identity**: Input of legal name, date of birth (min. 18 years restriction), and gender.
4. **Government ID Verification**: Formatted PAN Card validation and Aadhaar checking with secure mock document upload scanning.
5. **Selfie & Liveness**: A guided, interactive facial liveness scanning simulator ("Blink slowly", "Hold still") to prevent spoofing/identity theft.
6. **Address Details**: Integrated fields for Permanent and Current addresses, with a quick toggle to copy details if they match.
7. **Bank Account Verification**: Mock penny-drop check with IFSC code lookup (autofills state-specific bank details for codes like `SBIN0001234` or `HDFC0000104`).
8. **KYC Consent**: Comprehensive scrollable legal terms agreement and explicit user consent checkbox.
9. **Verification Summary**: Live visual dashboard displaying the status of each verification component with a option to reset/restart the onboarding flow.

---

## 🏗️ Architecture & State Management

* **State Model (`lib/models/onboarding_state.dart`)**: Uses a central `OnboardingState` class extending `ChangeNotifier` to hold inputs and verification statuses. It simulates server-side delays (`Future.delayed`) to model realistic API query times for OCR, government registry lookups, and bank checks.
* **UI Rebuilds**: Listens to state changes using Flutter's high-performance `ListenableBuilder` to selectively rebuild the scaffold when the user updates information.
* **Transitions**: Features smooth visual transitions between steps using `AnimatedSwitcher` containing custom `FadeTransition` and `SlideTransition`.
* **Robust Lifecycle**: Fully guarded async and focus node handlers with `mounted` state assertions to ensure zero layout-freeze or `_dependents.isEmpty` crashes during fast navigation.

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the Flutter SDK installed on your machine. To verify, run:
```powershell
flutter doctor
```

### Running the App

1. Clone the repository and navigate to the project directory.
2. Fetch dependencies:
   ```powershell
   flutter pub get
   ```
3. Check connected devices:
   ```powershell
   flutter devices
   ```
4. Run the application on your preferred mobile device, emulator, or browser:
   ```powershell
   flutter run -d <DEVICE_ID>
   ```

### Running Tests

Run the widget and unit smoke tests to verify the layout integrity:
```powershell
flutter test
```
