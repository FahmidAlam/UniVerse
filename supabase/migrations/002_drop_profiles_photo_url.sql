-- ============================================================
-- MIGRATION 002 — drop profiles.photo_url
-- PURPOSE: profiles had BOTH avatar_url and photo_url (duplicates).
--   Standardise on avatar_url (matches the avatars bucket + UAvatar
--   widget) and drop the redundant photo_url column.
-- NOTE: auth_service.dart no longer writes photo_url (updated in the
--   same change), so this is safe to run.
-- Run once in the Supabase SQL editor.
-- ============================================================

alter table public.profiles drop column if exists photo_url;
