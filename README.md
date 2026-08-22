# 🛡️ ChitGuard (Safe Chit) Onboarding

ChitGuard is a secure, state-of-the-art onboarding and KYC (Know Your Customer) flow designed to verify and register members and hosts (foremen) for decentralized and transparent chit fund cycles. Built with Flutter, it ensures safety, regulatory compliance, and a seamless user experience.

---

## 📱 Features

The application orchestrates a comprehensive **10-step onboarding and verification journey**:

1. **Role Selection**: Select whether you are joining as a **Member** (saving/borrowing) or a **Host/Foreman** (creating/managing cycles).
2. **Account Setup**: Double verification of mobile number (mock OTP: `123456`) and email address.
3. **Personal Identity**: Input of legal name, date of birth (min. 18 years restriction), and gender (strictly limited to Male and Female).
4. **Government ID Verification**: Formatted PAN Card validation and Aadhaar checking with real **ImagePicker** camera and photo gallery upload scanning.
5. **Selfie & Liveness**: A guided, interactive facial liveness scanner using **Google ML Kit face detection** and device **Camera stream** to detect blink, turn, and smile gestures.
6. **Address Details**: Integrated fields for Permanent and Current addresses, with a quick toggle to copy details if they match.
7. **Bank Account Verification**: Mock penny-drop check with IFSC code lookup (autofills state-specific bank details for codes like `SBIN0001234` or `HDFC0000104`).
8. **KYC Consent**: Comprehensive scrollable legal terms agreement and explicit user consent checkbox.
9. **Credentials Setup**: Form UI to establish a unique username and secure password, executing real-time uniqueness checks and password strength calculations.
10. **Verification Summary**: A verified passport dashboard summarizing all status details, executing direct **Supabase Database** integration to store full onboarding records.

---

## 🆕 Recent Updates

*   **Real Camera & Image Picker**: Integrated legacy and Android SDK 33+ permissions (`READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`) and real image picking for the Government ID upload step.
*   **CameraController Lifecycle Race Fix**: Resolved camera disposed exceptions by immediately transitioning UI state to success and synchronously clearing controller references before stream teardown.
*   **Supabase Real Integration**: Connected Step 9 credentials setup to perform real inserts/upserts into the `user_onboardings` table, fully supporting `onConflict: 'username'` updates.
*   **Error Diagnostics**: Added detailed alert dialog notifications directly in the Flutter UI to display exact database schema/constraint errors to developers.
*   **Color Palette Realignment**: Overhauled the color system to follow a professional, high-contrast fintech aesthetic featuring Navy (`#0A2540`), Blue (`#0F4C81`), Teal (`#007A87`), and neutral backgrounds (`#F8FAFC`, `#FFFFFF`).
*   **Branding Asset Optimization**: Cropped out excess padding from the brand logo file (reducing it from `680x470` to `395x83`) for perfect navigation bar sizing.

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
