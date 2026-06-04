-- ============================================================
-- SEED — notifications
-- PURPOSE: 10 demo broadcasts spanning every NotifType, varied
--   created_at, and a mix of audience targets so the Alerts tab,
--   filter chips, and audience filtering all have data to show.
-- Read/unread state is per-user (notification_reads) and is NOT
--   seeded here — every notification starts unread for everyone.
-- Idempotent: fixed UUIDs + ON CONFLICT DO NOTHING, safe to re-run.
--
-- Targeting columns (NULL = everyone):
--   target_role    'student' | 'teacher' | 'admin'
--   target_batch   e.g. '62'
--   target_section e.g. 'G'
-- Adjust the batch/section values below to match your demo
-- student's profile so the targeted rows show up for them.
-- ============================================================

insert into public.notifications
  (id, title, body, type, target_role, target_batch, target_section, created_at)
values
  ('11111111-1111-1111-1111-111111111101',
   'Spring 2026 registration is open',
   'Course registration for the Spring 2026 semester is now open. Complete it before the deadline on the 18th.',
   'university', null, null, null, now() - interval '2 minutes'),

  ('11111111-1111-1111-1111-111111111102',
   'CSE-3240 class cancelled today',
   'The Project I class scheduled for 2:10 PM has been cancelled. It will be rescheduled next week.',
   'class_cancel', 'student', '62', 'G', now() - interval '35 minutes'),

  ('11111111-1111-1111-1111-111111111103',
   'Room change: Operating Systems',
   'Today''s Operating Systems lecture moves from Room 401 to ACL-1 (Advanced Computing Lab).',
   'room_change', 'student', '62', 'G', now() - interval '2 hours'),

  ('11111111-1111-1111-1111-111111111104',
   'Quiz reminder — Data Structures',
   'A short quiz on trees and graphs will be held in tomorrow''s DSA class. Come prepared.',
   'test_reminder', 'student', '62', null, now() - interval '5 hours'),

  ('11111111-1111-1111-1111-111111111105',
   'Assignment 3 posted',
   'Assignment 3 for Database Systems is now available. Submission deadline is the end of this week.',
   'assignment', 'student', null, null, now() - interval '1 day'),

  ('11111111-1111-1111-1111-111111111106',
   'Mid-term exam routine published',
   'The mid-term examination routine has been published. Check the routine tab for your schedule.',
   'exam', 'student', null, null, now() - interval '1 day' - interval '3 hours'),

  ('11111111-1111-1111-1111-111111111107',
   'Faculty meeting on Thursday',
   'All teachers are requested to attend the departmental meeting on Thursday at 11:00 AM in the conference room.',
   'university', 'teacher', null, null, now() - interval '2 days'),

  ('11111111-1111-1111-1111-111111111108',
   'Library hours extended',
   'During exam week the central library will remain open until 10:00 PM. Plan your study sessions accordingly.',
   'university', null, null, null, now() - interval '3 days'),

  ('11111111-1111-1111-1111-111111111109',
   'Section G — lab session moved',
   'The Section G sessional for this week has been moved to Friday''s first slot in NL (Networking Lab).',
   'room_change', 'student', '62', 'G', now() - interval '4 days'),

  ('11111111-1111-1111-1111-111111111110',
   'Project I final defense schedule',
   'The final defense for CSE-3240 Project I is tentatively set for the last week of the semester. Details to follow.',
   'exam', 'student', null, null, now() - interval '5 days')
on conflict (id) do nothing;
