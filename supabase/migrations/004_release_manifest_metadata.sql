-- Jot App Schema Migration 004
-- Release manifest metadata for the in-app update page.
--
-- GitHub Releases provides asset size and a SHA-256 digest automatically.
-- These columns let the Supabase fallback manifest carry the same information
-- so the update page can show the download size and verify the APK.

ALTER TABLE app_releases
  ADD COLUMN IF NOT EXISTS size_bytes BIGINT;

ALTER TABLE app_releases
  ADD COLUMN IF NOT EXISTS sha256 TEXT;

-- Example of publishing a verified release:
--
-- insert into app_releases (version, platform, notes, download_url, size_bytes, sha256)
-- values (
--   '2.5.0', 'android', 'What changed…',
--   'https://…/jot-2.5.0.apk',
--   48234496,
--   'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
-- )
-- on conflict (version, platform)
-- do update set notes = excluded.notes,
--               download_url = excluded.download_url,
--               size_bytes = excluded.size_bytes,
--               sha256 = excluded.sha256,
--               published_at = now();
