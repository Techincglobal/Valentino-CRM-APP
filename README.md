# CRM Caller NxtGen

A premium Flutter application designed with a beautiful, modern **"Frosted Glass iOS"** design system. 

It connects to your Frappe CRM using APIs to automatically detect incoming calls, fetch caller details on the fly, and display a Truecaller-like floating window overlay over other apps.

![UI Sneak Peek](https://dummyimage.com/600x400/0f172a/ffffff&text=CRM+Caller)

## Features
- **Cinematic UI Overhaul**: Gorgeous aesthetic leveraging blurs, micro-animations, rich typography, and deep background gradients.
- **Truecaller-like Call Overlay**: When you receive an incoming call, the background service triggers an API call to your CRM. A frosted glass UI window floats near the top of your screen showing the caller's details if they are known, or offering one-click lead capture directly from the overlay!
- **Call Summary Notes**: Attach quick context notes to leads and customers immediately after calls.
- **Custom CRM Linking**: Supports easy integration with any Frappe CRM Backend securely.

## Getting Started

1. Clone this repository
2. Ensure you have Flutter SDK installed
3. Run `flutter pub get`
4. Use `flutter run` on an Android physical device or emulator (Android 10+ recommended for draw-over-apps).

*Note: The floating overlay feature specifically relies on the Android "Display over other apps" permission.*
