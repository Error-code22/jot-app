-- Jot App Schema Migration 003
-- Release 2.4.0 features:
--   * note audio attachments and hidden previews
--   * revocable public share links
--   * a public release manifest for in-app update checks
--   * the note-audio storage bucket
--   * the missing UPDATE policy on the images bucket (upsert fallback)

-- ---------------------------------------------------------------------------
-- Notes: audio attachments + preview privacy
-- ---------------------------------------------------------------------------

ALTER TABLE notes
  ADD COLUMN IF NOT EXISTS audio_ids JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE notes
  ADD COLUMN IF NOT EXISTS hide_preview BOOLEAN NOT NULL DEFAULT FALSE;

-- ---------------------------------------------------------------------------
-- Public share links
--
-- The note is copied into `snapshot` when the link is created. The public page
-- is rendered by the `shared-note` Edge Function, which reads this table with
-- the service role. Direct table access stays owner-only, and the snapshot
-- never exposes the note's PIN hash to the public renderer.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS shared_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  note_id TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,
  snapshot JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  revoked BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_shared_notes_user_id
  ON shared_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_shared_notes_note_id
  ON shared_notes(note_id);
CREATE INDEX IF NOT EXISTS idx_shared_notes_token
  ON shared_notes(token);

ALTER TABLE shared_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own share links" ON shared_notes
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own share links" ON shared_notes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own share links" ON shared_notes
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own share links" ON shared_notes
  FOR DELETE
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Release manifest
--
-- Read-only for everyone (including signed-out clients so the startup update
-- check works). Rows are published with the service role key or the SQL
-- editor; there is deliberately no client write policy.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS app_releases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'all'
    CHECK (platform IN ('all', 'android', 'ios', 'windows', 'macos', 'linux')),
  notes TEXT,
  download_url TEXT,
  published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_app_releases_version_platform
  ON app_releases(version, platform);
CREATE INDEX IF NOT EXISTS idx_app_releases_published_at
  ON app_releases(published_at DESC);

ALTER TABLE app_releases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read app releases" ON app_releases
  FOR SELECT
  USING (TRUE);

-- Seed the current release so a fresh project reports "up to date" instead of
-- "no releases". Replace download_url with the published artifact when ready.
INSERT INTO app_releases (version, platform, notes, published_at)
VALUES (
  '2.4.0',
  'all',
  'Audio notes, biometric note locks, private previews, update checks, and share links.',
  NOW()
)
ON CONFLICT (version, platform) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Storage: note-audio bucket
-- ---------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'note-audio',
  'note-audio',
  TRUE,
  52428800,
  ARRAY['audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Authenticated users can upload note audio" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'note-audio'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Public can listen to note audio" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'note-audio');

CREATE POLICY "Users can update own note audio" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'note-audio'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own note audio" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'note-audio'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ---------------------------------------------------------------------------
-- Storage: images bucket
--
-- Migration 001 created INSERT/SELECT/DELETE policies. Upserts from the
-- Cloudinary fallback path also need UPDATE.
-- ---------------------------------------------------------------------------

CREATE POLICY "Authenticated users can update images" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'images'
    AND auth.role() = 'authenticated'
  );
