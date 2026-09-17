# Jot? - Cross-Platform Notes App

A Flutter-based notes application with Supabase cloud sync, image uploads, and a Samsung Notes-inspired UI across Android and Desktop (Windows).

## Features

- **Email Authentication**: Sign in with email/password via Supabase Auth
- **Cloud Sync**: Automatic bidirectional synchronization across devices using Supabase
- **Image Attachments**: Pick, compress, and upload images via Cloudinary (through Supabase Edge Function)
- **Offline Support**: Create, edit, and delete notes without internet connectivity
- **Multi-Platform**: Runs on Android and Windows
- **Conflict Resolution**: Automatic conflict detection with last-write-wins resolution
- **Note Organization**: Tags, colors, pinning, search, and tag filtering
- **PIN Lock**: Protect sensitive notes with a PIN
- **Checklists**: Toggle between text and checklist note types
- **Todo System**: Separate todo lists with priorities, due dates, and progress tracking
- **Dark/Light Themes**: Platform-adaptive theming with system, light, and dark modes
- **3 View Modes**: Grid (masonry), List (with thumbnails), and Compact
- **Backup/Export**: Export notes as JSON or ZIP, share with other apps
- **Import**: Import .txt, .md files or entire folders with drag-and-drop

## Architecture

The app follows a service-based architecture with dependency injection via Provider:

1. **Presentation Layer**: Flutter UI screens and widgets
2. **Business Logic Layer**: Services for notes, sync, auth, todos, backup, and imports
3. **Data Layer**: Local SQLite database + Supabase cloud storage

## Setup

### Prerequisites

- Flutter SDK 3.x or higher
- Supabase project (free tier works)
- Visual Studio (for Windows development)
- Android Studio (for Android development)

### Supabase Configuration

1. Create a project at [Supabase](https://supabase.com)
2. Run the migration in `supabase/migrations/001_create_notes_table.sql`
3. Deploy the Edge Function: `supabase functions deploy image-proxy`
4. Set Cloudinary secrets: `supabase secrets set CLOUDINARY_CLOUD_NAME=xxx CLOUDINARY_UPLOAD_PRESET=xxx`
5. Update `lib/config.dart` with your Supabase URL and anon key

### Installation

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Run the app: `flutter run`

## Project Structure

```
lib/
├── main.dart                    # Entry point
├── config.dart                  # Supabase configuration
├── core/                        # App bootstrapper
├── services/                    # Business logic (auth, sync, notes, todos, backup)
├── models/                      # Data models
├── screens/                     # UI screens
├── widgets/                     # Reusable UI components
└── utils/                       # Utilities (theme, colors, connectivity)

supabase/
├── functions/image-proxy/       # Edge Function for Cloudinary uploads
└── migrations/                  # SQL migrations

test/
├── unit/                        # Unit tests
├── integration/                 # Integration tests
└── widget/                      # Widget tests
```

## Key Dependencies

- **supabase_flutter**: Auth, database, realtime sync
- **sqflite**: Local SQLite database
- **image_picker + flutter_image_compress**: Image handling
- **provider**: State management
- **flutter_staggered_grid_view**: Masonry grid layout
- **google_fonts**: Custom typography (Outfit + Inter)
- **url_launcher**: External links
- **connectivity_plus**: Network monitoring

## Testing

```bash
flutter test                    # All 195 tests
flutter test test/unit          # Unit tests only
flutter test test/widget        # Widget tests only
flutter test test/integration   # Integration tests only
```

## Building

```bash
flutter build apk --release     # Android APK
flutter build windows --release # Windows EXE
```

## License

[Add your license here]
