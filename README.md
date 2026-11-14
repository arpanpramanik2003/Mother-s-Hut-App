# Mother's Hut Mobile App 🍽️

An enhanced, production-grade Flutter Android mobile application for **Mother's Hut** ([mothershut.com](https://mothershut.com)) — West Bengal's renowned mega kitchen and food destination.

---

## 🌟 Key Features

* **Authentic Native Skeleton Loader**: Shimmer-based skeleton placeholder mimicking the restaurant layout (header, search bar, hero food banner, category pills, and food item grid) with a smooth fade-in transition once the page finishes loading.
* **External Scheme & Intent Routing**:
  * 📞 **Phone Dialer (`tel:`)**: Directly launches the device phone dialer for reservations and queries.
  * 💬 **WhatsApp Integration (`wa.me` / `whatsapp://`)**: Opens inquiries in WhatsApp or WhatsApp Business.
  * 💳 **UPI Payment Support (`upi://`, PhonePe, Google Pay, Paytm)**: Automatically directs payment and checkout actions to installed UPI applications.
  * 🗺️ **Google Maps (`geo:`, Google Maps URLs)**: Direct navigation to the restaurant location.
  * 🌐 **Social Profiles (Instagram, Facebook, YouTube)**: Opens in native mobile apps rather than forcing re-login inside the web view.
* **Pull-to-Refresh Gesture**: Native swipe-down refresh indicator themed with Mother's Hut brand colors (`#8B4513`).
* **Offline Resilience & Auto-Reconnect**: Live network connectivity listener (`connectivity_plus`) that displays a branded offline screen and automatically recovers as soon as internet access is restored.
* **Double-Tap Back to Exit**: Prevents accidental app exits with a subtle floating SnackBar notification.
* **Edge-to-Edge System Theming**: Clean, transparent status bar and dark icons styled to match the Mother's Hut brand aesthetic.

---

## 🛠️ Tech Stack & Architecture

* **Framework**: Flutter 3.x (Dart 3.x)
* **Design System**: Material Design 3
* **Primary Dependencies**:
  * `webview_flutter: ^4.14.1` — Core web rendering engine
  * `shimmer: ^3.0.0` — Skeleton loading animations
  * `url_launcher: ^6.3.1` — External application intent routing
  * `connectivity_plus: ^6.1.1` — Network state monitoring
  * `flutter_native_splash: ^2.4.7` — Native Android splash screen
  * `flutter_launcher_icons: ^0.14.4` — Adaptive app icons

---

## 📂 Project Structure

```text
mothers_hut_app/
├── android/                  # Native Android configuration & Manifest queries
├── assets/
│   └── images/
│       └── mothers_hut_logo.png  # Brand logo asset
├── lib/
│   ├── main.dart             # Application entry point, WebView & intent handling
│   └── widgets/
│       └── skeleton_loader.dart  # Branded shimmer skeleton placeholder
├── test/
│   └── widget_test.dart      # Automated widget tests
├── pubspec.yaml              # Dependencies and asset declarations
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.x or higher)
* Android Studio / Android SDK (API 34+)
* Java 17 or higher

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/arpanpramanik2003/Mother-s-Hut-App.git
   cd Mother-s-Hut-App
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on an Android device or emulator:**
   ```bash
   flutter run
   ```

4. **Build release APK:**
   ```bash
   flutter build apk --release
   ```
   The generated APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 License
This project is proprietary and built for Mother's Hut. All rights reserved.
