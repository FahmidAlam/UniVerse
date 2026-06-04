-- ============================================================
-- SEED — resources
-- PURPOSE: 16 demo resources for the Resource Hub, across the
--   stored categories (PYQ / Notes / Slides / Assignments) and
--   semester 6 CSE subjects, so the hub's semester + category
--   filters have data to show.
-- Links are illustrative Google Drive URLs (drive_link); a couple
--   use file_url to exercise the PDF-vs-Drive split in the card.
-- uploaded_by is left NULL (FK to profiles, nullable).
-- Idempotent: fixed UUIDs + ON CONFLICT DO NOTHING.
--
-- NOTE: semester 6 is used to match the demo student profile
--   (batch 62 / section G / semester 6). Change `semester` here
--   if your demo student is in a different semester.
-- ============================================================

insert into public.resources
  (id, title, category, semester, subject_code, drive_link, file_url, created_at)
values
  -- ── Operating Systems (CSE-3201) ──
  ('33333333-3333-3333-3333-333333330001', 'Operating Systems — Full Lecture Notes', 'Notes', 6, 'CSE-3201', 'https://drive.google.com/file/d/1OSnotes_demo/view', null, now() - interval '1 day'),
  ('33333333-3333-3333-3333-333333330002', 'OS — Process Scheduling Slides', 'Slides', 6, 'CSE-3201', 'https://drive.google.com/file/d/1OSslides_demo/view', null, now() - interval '2 days'),
  ('33333333-3333-3333-3333-333333330003', 'OS Mid-term 2025 — Question Paper', 'PYQ', 6, 'CSE-3201', null, 'https://example.com/storage/os_midterm_2025.pdf', now() - interval '6 days'),

  -- ── Database Management Systems (CSE-3203) ──
  ('33333333-3333-3333-3333-333333330004', 'DBMS — Normalization Notes (1NF–BCNF)', 'Notes', 6, 'CSE-3203', 'https://drive.google.com/file/d/1DBnotes_demo/view', null, now() - interval '1 day'),
  ('33333333-3333-3333-3333-333333330005', 'DBMS — SQL & Joins Slides', 'Slides', 6, 'CSE-3203', 'https://drive.google.com/file/d/1DBslides_demo/view', null, now() - interval '3 days'),
  ('33333333-3333-3333-3333-333333330006', 'DBMS Final 2024 — Question Paper', 'PYQ', 6, 'CSE-3203', 'https://drive.google.com/file/d/1DBpyq_demo/view', null, now() - interval '8 days'),
  ('33333333-3333-3333-3333-333333330007', 'DBMS — Assignment 2 (ER Modeling)', 'Assignments', 6, 'CSE-3203', 'https://drive.google.com/file/d/1DBassign_demo/view', null, now() - interval '4 hours'),

  -- ── Computer Networks (CSE-3205) ──
  ('33333333-3333-3333-3333-333333330008', 'Computer Networks — OSI & TCP/IP Notes', 'Notes', 6, 'CSE-3205', 'https://drive.google.com/file/d/1CNnotes_demo/view', null, now() - interval '2 days'),
  ('33333333-3333-3333-3333-333333330009', 'CN — Routing Algorithms Slides', 'Slides', 6, 'CSE-3205', 'https://drive.google.com/file/d/1CNslides_demo/view', null, now() - interval '5 days'),
  ('33333333-3333-3333-3333-333333330010', 'CN Mid-term 2025 — Question Paper', 'PYQ', 6, 'CSE-3205', null, 'https://example.com/storage/cn_midterm_2025.pdf', now() - interval '7 days'),

  -- ── Software Engineering (CSE-3207) ──
  ('33333333-3333-3333-3333-333333330011', 'Software Engineering — SDLC & Agile Notes', 'Notes', 6, 'CSE-3207', 'https://drive.google.com/file/d/1SEnotes_demo/view', null, now() - interval '1 day'),
  ('33333333-3333-3333-3333-333333330012', 'SE — UML Diagrams Slides', 'Slides', 6, 'CSE-3207', 'https://drive.google.com/file/d/1SEslides_demo/view', null, now() - interval '3 days'),
  ('33333333-3333-3333-3333-333333330013', 'SE — Assignment 1 (Requirement Spec)', 'Assignments', 6, 'CSE-3207', 'https://drive.google.com/file/d/1SEassign_demo/view', null, now() - interval '1 day'),

  -- ── Microprocessors (CSE-3209) ──
  ('33333333-3333-3333-3333-333333330014', 'Microprocessors — 8086 Architecture Notes', 'Notes', 6, 'CSE-3209', 'https://drive.google.com/file/d/1MPnotes_demo/view', null, now() - interval '2 days'),
  ('33333333-3333-3333-3333-333333330015', 'MP — Assembly Instruction Set Slides', 'Slides', 6, 'CSE-3209', 'https://drive.google.com/file/d/1MPslides_demo/view', null, now() - interval '4 days'),
  ('33333333-3333-3333-3333-333333330016', 'Microprocessors Final 2024 — Question Paper', 'PYQ', 6, 'CSE-3209', 'https://drive.google.com/file/d/1MPpyq_demo/view', null, now() - interval '9 days')
on conflict (id) do nothing;
