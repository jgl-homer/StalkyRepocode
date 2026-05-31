# Stalky

Stalky is a Flutter reminder app focused on fast task capture, AI-assisted study workflows, voice dictation, and reliable scheduled notifications.

The idea is simple: the app helps detect or capture the task, but the user decides when they want to be reminded.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [App Flow](#app-flow)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Firebase Setup](#firebase-setup)
- [Google Sign-In](#google-sign-in)
- [Notifications](#notifications)
- [AI Assistant](#ai-assistant)
- [Voice Dictation](#voice-dictation)
- [Run Locally](#run-locally)
- [Build APK](#build-apk)
- [Security Notes](#security-notes)
- [Roadmap](#roadmap)

## Overview

Stalky combines a task manager with AI tools designed for students and users who need quick reminders. A user can create a reminder manually, scan an image with the AI study assistant, or dictate a reminder by voice.

Detected tasks are saved to Firestore and scheduled locally on the device using native notification APIs.

## Features

- Email/password login with Firebase Auth.
- Google Sign-In with Firebase Auth.
- User profile and account settings.
- Manual task creation with date and time.
- AI task detection from uploaded images.
- Voice dictation with AI parsing.
- Per-user Firestore task storage.
- Local scheduled notifications.
- Android 13+ notification permission handling.
- Android exact alarm permission handling.
- Device timezone detection.
- Custom app launcher icon.
- Dark interface with gold accents.

## App Flow

```text
User signs in
  |
  v
Dashboard
  |
  +-- Manual task
  |     +-- User writes title/details
  |     +-- User selects date and time
  |     +-- App saves task
  |     +-- App schedules notification
  |
  +-- AI study assistant
  |     +-- User uploads image
  |     +-- AI detects tasks
  |     +-- User selects date/time per task
  |     +-- App saves selected reminders
  |
  +-- Voice dictation
        +-- User dictates reminder
        +-- AI extracts task/date/time
        +-- App saves and schedules reminder
```

## Tech Stack

- Flutter
- Dart
- Firebase Auth
- Cloud Firestore
- Firebase Messaging
- Firebase App Check
- Google Sign-In
- Gemini API with `google_generative_ai`
- `flutter_local_notifications`
- `speech_to_text`
- `flutter_timezone`
- `image_picker`
- `google_fonts`

## Architecture

The app is organized around screens, services, and reusable widgets.

- Screens handle UI and user interaction.
- Services handle authentication, AI parsing, Firestore writes, and notification scheduling.
- Widgets provide reusable UI pieces such as the voice dictation button.
- Firebase stores users and tasks.
- Local notifications are scheduled on-device so reminders can fire even after the task is saved.

## Project Structure

```text
.
├── android/
│   └── app/
│       ├── google-services.example.json
│       └── src/main/AndroidManifest.xml
│
├── assets/
│   ├── icon/
│   ├── logo/
│   └── sounds/
│
├── ios/
│   └── Runner/
│
├── lib/
│   ├── add_task_page.dart
│   ├── dashboard.dart
│   ├── edit_task_page.dart
│   ├── firebase_options.example.dart
│   ├── flashcards_page.dart
│   ├── gemini_assistant_page.dart
│   ├── login.dart
│   ├── main.dart
│   ├── profile.dart
│   ├── register.dart
│   │
│   ├── services/
│   │   ├── ai_service.dart
│   │   ├── auth_service.dart
│   │   ├── notification_service.dart
│   │   └── tools_registry.dart
│   │
│   └── widgets/
│       └── voice_dictation_button.dart
│
├── linux/
├── macos/
├── web/
├── windows/
├── pubspec.yaml
└── README.md
```

## Important Files

| File | Purpose |
| --- | --- |
| `lib/main.dart` | App bootstrap, Firebase init, timezone setup, notifications init. |
| `lib/login.dart` | Email/password and Google login UI. |
| `lib/dashboard.dart` | Main task dashboard and voice reminder entry point. |
| `lib/add_task_page.dart` | Manual reminder creation. |
| `lib/gemini_assistant_page.dart` | AI image analysis and detected task confirmation. |
| `lib/profile.dart` | Profile, password changes, logout, and danger zone. |
| `lib/services/auth_service.dart` | Firebase Auth and Google Sign-In logic. |
| `lib/services/ai_service.dart` | Gemini task detection, voice parsing, Firestore saves. |
| `lib/services/notification_service.dart` | Local notification permissions and scheduling. |
| `lib/widgets/voice_dictation_button.dart` | Reusable voice dictation control. |

## Firebase Setup

Create a Firebase project and enable:

- Authentication
- Email/password provider
- Google provider
- Cloud Firestore
- Firebase Messaging
- Firebase App Check, if used in your environment

Android package name:

```text
com.TaskingTech.android
```

Place the Android Firebase config here:

```text
android/app/google-services.json
```

This file is intentionally ignored by Git. Use `android/app/google-services.example.json` only as a placeholder reference.

Generate the Flutter Firebase options locally:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This creates:

```text
lib/firebase_options.dart
```

That file is also ignored by Git because it contains project-specific Firebase keys.

## Google Sign-In

For Android Google Sign-In, add the SHA fingerprints from your local build environment in Firebase Project Settings.

Useful command:

```bash
cd android
./gradlew signingReport
```

After adding SHA-1/SHA-256 fingerprints in Firebase:

1. Download a fresh `google-services.json`.
2. Replace `android/app/google-services.json`.
3. Rebuild the APK.

## Notifications

Stalky uses `flutter_local_notifications` to schedule reminders.

Implemented notification handling:

- Runtime notification permission request on Android 13+.
- Exact alarm permission request for modern Android.
- Fallback to inexact scheduling when exact alarms are blocked.
- Device timezone detection with `flutter_timezone`.
- Boot receiver support through Android manifest entries.

Recommended real-device test:

1. Install APK on an Android device.
2. Allow notifications.
3. Create a task 2 or 3 minutes in the future.
4. Close the app.
5. Confirm the notification fires.

## AI Assistant

The AI study assistant is designed for images of notes, boards, or school material.

Flow:

1. User uploads an image.
2. Gemini analyzes the content.
3. Detected tasks are displayed as cards.
4. User selects date and time.
5. User saves the reminder manually.

This prevents tasks from being saved without a reminder date.

## Voice Dictation

Voice dictation uses speech-to-text plus AI parsing.

Example:

```text
Recuerdame entregar la tarea de matematicas manana a las 6 pm
```

The AI extracts:

- Task title
- Category
- Notes
- Due date and time

If the dictation does not include a clear date and time, the app shows an error instead of saving an incomplete reminder.

## Run Locally

Install dependencies:

```bash
flutter pub get
```

Run on a connected device or emulator:

```bash
flutter run
```

Analyze code:

```bash
flutter analyze
```

Format code:

```bash
dart format .
```

## Build APK

Build release APK:

```bash
flutter build apk
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Security Notes

Before making this repository public, review:

- API keys
- Firebase config
- App Check settings
- Firestore rules
- Android signing files
- Any local environment files

Do not commit production keystores, private service accounts, unrestricted API keys, `google-services.json`, or generated Firebase options.

Local-only files ignored by Git:

```text
.env
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
public/
```

## Roadmap

- Better reminder testing screen.
- Notification history.
- Task filters and search.
- Better offline sync.
- More AI parsing controls.
- Cleaner onboarding for first-time users.
- iOS notification polish.

## Status

Active development. Current focus is reliability, clean UX, and making reminder creation feel fast.
