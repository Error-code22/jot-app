# Jot? - Cross-Platform Notes App

A Flutter-based notes application with Gmail authentication and cloud synchronization across Android and Desktop platforms (Windows, Linux, macOS).

## Features

- **Gmail Authentication**: Sign in with your Gmail account via Firebase Authentication
- **Cloud Sync**: Automatic synchronization of notes across all your devices using Firebase Firestore
- **Offline Support**: Create, edit, and delete notes without internet connectivity
- **Multi-Platform**: Runs on Android, Windows, Linux, and macOS
- **Secure Storage**: Local notes encrypted with SQLite, credentials stored securely
- **Conflict Resolution**: Automatic conflict resolution using "most recent wins" strategy

## Architecture

The app follows a service-based architecture with three main layers:

1. **Presentation Layer**: Flutter UI components (screens and widgets)
2. **Business Logic Layer**: Services for note management, sync, and authentication
3. **Data Layer**: Local SQLite database and Firebase Firestore cloud storage

## Setup Instructions

### Prerequisites

- Flutter SDK 3.x or higher
- Firebase project with Authentication and Firestore enabled
- Android Studio (for Android development)
- Visual Studio (for Windows development)
- Xcode (for macOS development)

### Firebase Configuration

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Firebase Authentication with Google Sign-In provider
3. Enable Cloud Firestore database
4. Download configuration files:
   - For Android: Download `google-services.json` and place in `android/app/`
   - For other platforms: Run `flutterfire configure` to generate `lib/firebase_options.dart`

### Installation

1. Clone the repository
2. Navigate to the project directory: `cd flutter-projects/jot_app`
3. Install dependencies: `flutter pub get`
4. Configure Firebase (see above)
5. Run the app: `flutter run`

## Project Structure

```
lib/
├── main.dart                    # Application entry point
├── firebase_options.dart        # Firebase configuration
├── services/                    # Business logic services
├── models/                      # Data models
├── screens/                     # UI screens
├── widgets/                     # Reusable UI components
└── utils/                       # Utility functions

public/                          # Public assets
├── logo.png
└── images/

test/                            # Tests
├── unit/                        # Unit tests
├── property/                    # Property-based tests
├── integration/                 # Integration tests
└── widget/                      # Widget tests
```

## Dependencies

- **firebase_core**: Firebase SDK initialization
- **firebase_auth**: Firebase Authentication
- **cloud_firestore**: Cloud Firestore database
- **google_sign_in**: Google Sign-In for authentication
- **sqflite**: SQLite local database
- **flutter_secure_storage**: Secure credential storage
- **uuid**: Unique identifier generation
- **connectivity_plus**: Network connectivity detection

## Development

This project uses multi-IDE collaboration support. The `.ide-collaboration.json` file contains shared project metadata readable by Kiro, Antigravity, and Cursor IDEs.

Development progress is tracked in `PROGRESS.md` using an append-only format.

## Testing

Run tests with:
- Unit tests: `flutter test test/unit`
- Property tests: `flutter test test/property`
- Integration tests: `flutter test test/integration`
- Widget tests: `flutter test test/widget`
- All tests: `flutter test`

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]
