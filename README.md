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
- **Private Notes**: PIN and biometric lock, with optional hidden previews
- **Voice Notes**: Audio recording stored privately in your own Supabase project (no third-party transcription)
- **Checklists**: Toggle between text and checklist note types
- **Todo System**: Separate todo lists with priorities, due dates, reminders, and progress tracking
- **Dark/Light Themes**: Platform-adaptive theming with system, light, and dark modes
- **Note Views**: Grid (masonry), List (with thumbnails), and Compact, plus a desktop split view
- **Backup/Export**: Export notes as JSON or ZIP, share with other apps
- **Import**: Import .txt, .md files or entire folders with drag-and-drop
- **Revocable Share Links**: Publish a read-only snapshot of a note; revoke or expire it at any time
- **In-App Updates**: Full-screen update page with release notes, download progress, optional checksum verification, and the system installer on Android; checks GitHub Releases first and falls back to a Supabase manifest

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
2. Link the CLI and push all migrations:
   ```bash
   supabase link --project-ref <your-project-ref>
   supabase db push
   ```
   This creates the notes/feedback tables, the `images` and `note-audio`
   storage buckets, the `shared_notes` and `app_releases` tables, and all RLS
   policies.
3. Deploy the Edge Functions:
   ```bash
   supabase functions deploy image-proxy
   supabase functions deploy shared-note --no-verify-jwt
   ```
   `shared-note` must run without JWT verification so recipients can open a
   link without an account; it validates the random share token itself.
4. Set Cloudinary secrets (used only by `image-proxy`):
   ```bash
   supabase secrets set CLOUDINARY_CLOUD_NAME=xxx CLOUDINARY_UPLOAD_PRESET=xxx
   ```
5. Update `lib/config.dart` with your Supabase URL and anon key.

### Publishing a release

The app checks for updates in two places, in order:

1. **GitHub Releases (preferred)** — the repository named by
   `AppConfig.githubReleasesRepo` in `lib/config.dart`. The app calls
   `GET /repos/{owner}/{repo}/releases/latest`, reads the tag as the version,
   the release body as the notes, and picks the asset that matches the platform
   (`.apk` on Android, `.exe`/`.zip` on Windows, `.dmg`/`.zip` on macOS,
   `.AppImage`/`.deb`/`.tar.gz` on Linux). Asset size and SHA-256 digest come
   from GitHub automatically. **The repository and its releases must be public**
   for anonymous checks; a private repo returns 404 and the app falls back.
2. **Supabase `app_releases` manifest (fallback)** — used when GitHub has no
   public release. Publish with:

```sql
insert into app_releases (version, platform, notes, download_url, size_bytes, sha256)
values (
  '2.5.0', 'android', 'What changed…',
  'https://…/jot-2.5.0.apk',
  48234496,
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
)
on conflict (version, platform)
do update set notes = excluded.notes,
              download_url = excluded.download_url,
              size_bytes = excluded.size_bytes,
              sha256 = excluded.sha256,
              published_at = now();
```

Use `platform = 'all'` for a release that applies to every platform, or the
specific key (`android`, `ios`, `windows`, `macos`, `linux`). Only the service
role can write to this table; clients have read-only access.

When a release includes a SHA-256 digest, the app verifies the downloaded APK
before handing it to the installer and shows a "Security verified" line on the
update page.

### Share links

`shared_notes` stores a snapshot of the note and an unguessable token. The
`shared-note` function refuses revoked or expired rows and renders escaped
HTML; it never returns the raw snapshot or the note's PIN hash. Revoking is a
single update from the app (or `update shared_notes set revoked = true`).

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
├── functions/shared-note/       # Public, revocable note share pages
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
- **record + audioplayers**: Voice note recording and playback
- **local_auth**: Biometric note unlock
- **package_info_plus**: Runtime version reporting
- **provider**: State management
- **flutter_staggered_grid_view**: Masonry grid layout
- **google_fonts**: Custom typography (Outfit + Inter)
- **url_launcher**: External links
- **connectivity_plus**: Network monitoring

## Testing

```bash
flutter test                    # Full test suite
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
