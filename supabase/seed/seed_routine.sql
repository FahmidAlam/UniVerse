-- ============================================================
-- SEED — routines (weekly class schedule)
-- PURPOSE: A full Sun–Thu schedule for ONE demo section so the
--   student routine screen, dashboard live-class card, and the
--   AI assistant all have a real timetable to work with.
-- Requires migration 003 (routines.teacher_name / teacher_code).
-- teacher_id is left NULL (no auth account needed); the teacher
--   shows via teacher_name, matching generated_timetable's style.
-- Idempotent: fixed UUIDs + ON CONFLICT DO NOTHING.
--
-- DEMO TARGET: batch 62 / section G / semester 5.
--   Set your demo student's profile to these values (matches the
--   notification + resource seeds) or edit batch/section/semester
--   below to match your student.
--
-- Teacher day-offs honoured (per the timetable engine spec):
--   JIM (Jaminur Rahman) has no Sunday class.
--   EBH (Emran B. Hossain) has no Thursday class.
-- Time slots (Sun–Thu, 5/day):
--   1) 09:30–10:50  2) 10:50–12:10  3) 12:10–13:30
--   4) 14:10–15:30  5) 15:30–16:50
-- ============================================================

insert into public.routines
  (id, day, time_start, time_end, subject, subject_code,
   teacher_name, teacher_code, teacher_id, room, batch, section, semester, is_active)
values
  -- ─── Sunday (no JIM) ───
  ('22222222-2222-2222-2222-222222220001', 'Sunday',   '09:30', '10:50', 'Operating Systems',          'CSE-3201', 'Dr. Aminul Islam',  'AMI', null, '401',   '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220002', 'Sunday',   '10:50', '12:10', 'Computer Networks',          'CSE-3205', 'Shahriar Kabir',    'SHK', null, '305',   '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220003', 'Sunday',   '12:10', '13:30', 'Software Engineering',       'CSE-3207', 'Rabeya Khatun',     'RBK', null, '401',   '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220004', 'Sunday',   '14:10', '15:30', 'Microprocessors & Interfacing', 'CSE-3209', 'Emran B. Hossain', 'EBH', null, '303', '62', 'G', 5, true),

  -- ─── Monday ───
  ('22222222-2222-2222-2222-222222220005', 'Monday',   '09:30', '12:10', 'Operating Systems Lab',      'CSE-3202', 'Dr. Aminul Islam',  'AMI', null, 'ACL-1', '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220006', 'Monday',   '12:10', '13:30', 'Database Management Systems','CSE-3203', 'Jaminur Rahman',    'JIM', null, '402',   '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220007', 'Monday',   '14:10', '15:30', 'Computer Networks',          'CSE-3205', 'Shahriar Kabir',    'SHK', null, '305',   '62', 'G', 5, true),

  -- ─── Tuesday ───
  ('22222222-2222-2222-2222-222222220008', 'Tuesday',  '09:30', '10:50', 'Database Management Systems','CSE-3203', 'Jaminur Rahman',    'JIM', null, '402',   '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220009', 'Tuesday',  '10:50', '12:10', 'Microprocessors & Interfacing', 'CSE-3209', 'Emran B. Hossain', 'EBH', null, '303', '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220010', 'Tuesday',  '12:10', '13:30', 'Operating Systems',          'CSE-3201', 'Dr. Aminul Islam',  'AMI', null, '401',   '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220011', 'Tuesday',  '14:10', '15:30', 'Software Engineering',       'CSE-3207', 'Rabeya Khatun',     'RBK', null, '401',   '62', 'G', 5, true),

  -- ─── Wednesday ───
  ('22222222-2222-2222-2222-222222220012', 'Wednesday','09:30', '10:50', 'Software Engineering',       'CSE-3207', 'Rabeya Khatun',     'RBK', null, '401',   '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220013', 'Wednesday','10:50', '12:10', 'Operating Systems',          'CSE-3201', 'Dr. Aminul Islam',  'AMI', null, '401',   '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220014', 'Wednesday','14:10', '16:50', 'Database Management Systems Lab', 'CSE-3204', 'Jaminur Rahman', 'JIM', null, 'NL',  '62', 'G', 5, true),

  -- ─── Thursday (no EBH) ───
  ('22222222-2222-2222-2222-222222220015', 'Thursday', '09:30', '10:50', 'Computer Networks',          'CSE-3205', 'Shahriar Kabir',    'SHK', null, '305',   '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220016', 'Thursday', '10:50', '12:10', 'Database Management Systems','CSE-3203', 'Jaminur Rahman',    'JIM', null, '402',   '62', 'G', 5, true),
  ('22222222-2222-2222-2222-222222220017', 'Thursday', '12:10', '13:30', 'Software Engineering',       'CSE-3207', 'Rabeya Khatun',     'RBK', null, '401',   '62', 'G', 5, true),

  -- ════════════════════════════════════════════════════════
  -- Section H — same teachers teach across sections, so a teacher
  -- login (e.g. JIM, AMI) shows classes spanning 62/G AND 62/H.
  -- A lighter set than G; enough for the teacher-side demo.
  -- ════════════════════════════════════════════════════════
  ('22222222-2222-2222-2222-222222220101', 'Sunday',   '10:50', '12:10', 'Database Management Systems','CSE-3203', 'Jaminur Rahman',    'JIM', null, '402',   '62', 'H', 5, true),
  ('22222222-2222-2222-2222-222222220102', 'Sunday',   '12:10', '13:30', 'Operating Systems',          'CSE-3201', 'Dr. Aminul Islam',  'AMI', null, '401',   '62', 'H', 5, true),
  ('22222222-2222-2222-2222-222222220103', 'Monday',   '09:30', '10:50', 'Computer Networks',          'CSE-3205', 'Shahriar Kabir',    'SHK', null, '305',   '62', 'H', 5, true),
  ('22222222-2222-2222-2222-222222220104', 'Monday',   '10:50', '12:10', 'Software Engineering',       'CSE-3207', 'Rabeya Khatun',     'RBK', null, '401',   '62', 'H', 5, true),
  ('22222222-2222-2222-2222-222222220105', 'Tuesday',  '09:30', '10:50', 'Operating Systems',          'CSE-3201', 'Dr. Aminul Islam',  'AMI', null, '401',   '62', 'H', 5, true),
  ('22222222-2222-2222-2222-222222220106', 'Tuesday',  '12:10', '13:30', 'Database Management Systems','CSE-3203', 'Jaminur Rahman',    'JIM', null, '402',   '62', 'H', 5, true),
  ('22222222-2222-2222-2222-222222220107', 'Wednesday','10:50', '12:10', 'Microprocessors & Interfacing', 'CSE-3209', 'Emran B. Hossain', 'EBH', null, '303', '62', 'H', 5, true),
  ('22222222-2222-2222-2222-222222220108', 'Wednesday','14:10', '16:50', 'Database Management Systems Lab', 'CSE-3204', 'Jaminur Rahman', 'JIM', null, 'NL',  '62', 'H', 5, true),
  ('22222222-2222-2222-2222-222222220109', 'Thursday', '09:30', '10:50', 'Software Engineering',       'CSE-3207', 'Rabeya Khatun',     'RBK', null, '401',   '62', 'H', 5, true),
  ('22222222-2222-2222-2222-222222220110', 'Thursday', '10:50', '12:10', 'Computer Networks',          'CSE-3205', 'Shahriar Kabir',    'SHK', null, '305',   '62', 'H', 5, true)
on conflict (id) do nothing;
