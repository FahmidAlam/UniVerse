import { create } from "zustand";
import {
  computeDistributionSessions,
  isLabCourseCode,
  type CourseDistributionOfferingRow,
} from "@/features/routine/services/distributionXlsxBuilder";
import type { RoutineRow } from "@/features/routine/types";

export const DISTRIBUTION_DRAFT_STORAGE_KEY =
  "universe-distribution-sheet-draft-v1";

interface PersistedDraft {
  termLabel: string;
  weeksInTerm: number;
  rows: CourseDistributionOfferingRow[];
}

export function createFall2026SampleRows(
  weeksInTerm = 14,
): CourseDistributionOfferingRow[] {
  const specs: Array<
    [
      batch: string,
      section: string,
      code: string,
      title: string,
      credit: number,
      dept: string,
      students: number | null,
      teacher: string,
    ]
  > = [
    ["69", "A", "CSE-1101", "Structured Programming", 3, "CSE", 45, "EBH"],
    ["69", "A", "CSE-1102", "Structured Programming Sessional", 1.5, "CSE", 45, "EBH"],
    ["69", "B", "CSE-1101", "Structured Programming", 3, "CSE", 44, "MFR"],
    ["69", "B", "MAT-1101", "Differential & Integral Calculus", 3, "MAT", 44, "SKR"],
    ["68", "A", "CSE-1201", "Discrete Mathematics", 3, "CSE", 42, "MSA"],
    ["68", "B", "CSE-1202", "Object Oriented Programming Sessional", 1.5, "CSE", 42, "FK"],
    ["67", "F+G", "CSE-2101", "Data Structures", 3, "CSE", 68, "MFR"],
    ["67", "F+G", "CSE-2102", "Data Structures Sessional", 1.5, "CSE", 68, "MFR / FK"],
    ["65", "A", "CSE-3101", "Database Management Systems", 3, "CSE", 40, "MSA"],
    ["65", "A", "CSE-3102", "Database Management Systems Sessional", 1.5, "CSE", 40, ""],
    ["64", "A", "CSE-3201", "Operating Systems", 3, "CSE", 38, "EBH"],
    ["63", "A", "CSE-4101", "Artificial Intelligence", 3, "CSE", 36, "MFR"],
    ["62", "A", "CSE-4201", "Computer Networks", 3, "CSE", 34, "FK"],
    ["61", "A", "CSE-4301", "Software Engineering", 3, "CSE", 32, "MSA"],
    ["M. Sc.", "A", "CSE-5101", "Advanced Algorithms", 3, "CSE", 22, "EBH"],
  ];

  return specs.map(
    (
      [batch, section, courseCode, courseTitle, credit, conductingDept, students, teacher],
      idx,
    ) => {
      const isLab = isLabCourseCode(courseCode, courseTitle);
      const derived = computeDistributionSessions(credit, weeksInTerm, isLab);
      return {
        id: `sample-${idx + 1}`,
        batch,
        section,
        courseCode,
        courseTitle,
        credit,
        prerequisite: "",
        conductingDept,
        students,
        teacher,
        totalClasses: derived.totalClasses,
        classDuration: 1.5,
        classesPerWeek: derived.classesPerWeek,
      };
    },
  );
}

export function mapPublishedRoutinesToDistribution(
  routineRows: readonly RoutineRow[],
  weeksInTerm = 14,
): CourseDistributionOfferingRow[] {
  const grouped = new Map<
    string,
    {
      batch: string;
      section: string;
      courseCode: string;
      courseTitle: string;
      teachers: Set<string>;
      weeklyCount: number;
      isLab: boolean;
      isService: boolean;
    }
  >();

  for (const r of routineRows) {
    if (!r.is_active) continue;
    const key = `${r.batch}::${r.section}::${r.subject_code}`;
    let entry = grouped.get(key);
    if (!entry) {
      entry = {
        batch: r.batch,
        section: r.section,
        courseCode: r.subject_code,
        courseTitle: r.subject || r.subject_code,
        teachers: new Set<string>(),
        weeklyCount: 0,
        isLab: r.is_lab ?? isLabCourseCode(r.subject_code, r.subject),
        isService: r.is_service,
      };
      grouped.set(key, entry);
    }
    entry.weeklyCount += 1;
    if (r.teacher_code?.trim()) {
      entry.teachers.add(r.teacher_code.trim());
    }
  }

  let idx = 0;
  return Array.from(grouped.values()).map((g) => {
    idx += 1;
    const credit = g.isLab ? 1.5 : 3;
    const classesPerWeek = Math.max(1, g.weeklyCount);
    const totalClasses = classesPerWeek * Math.max(1, weeksInTerm);
    const prefix = g.courseCode.split("-")[0]?.trim() || "CSE";
    const dept =
      g.isService && prefix && prefix !== "CSE" ? prefix : prefix || "CSE";
    return {
      id: `imported-${idx}-${g.batch}-${g.section}-${g.courseCode}`,
      batch: g.batch,
      section: g.section,
      courseCode: g.courseCode,
      courseTitle: g.courseTitle,
      credit,
      prerequisite: "",
      conductingDept: dept,
      students: null,
      teacher: Array.from(g.teachers).join(" / "),
      totalClasses,
      classDuration: 1.5,
      classesPerWeek,
    };
  });
}

function readInitialDraft(): PersistedDraft {
  if (typeof window !== "undefined") {
    try {
      const raw = window.localStorage.getItem(DISTRIBUTION_DRAFT_STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<PersistedDraft>;
        if (Array.isArray(parsed.rows)) {
          return {
            termLabel:
              typeof parsed.termLabel === "string" && parsed.termLabel.trim()
                ? parsed.termLabel
                : "Fall 2026",
            weeksInTerm:
              typeof parsed.weeksInTerm === "number" && parsed.weeksInTerm > 0
                ? parsed.weeksInTerm
                : 14,
            rows: parsed.rows,
          };
        }
      }
    } catch {
      // Fall back to sample rows
    }
  }
  return {
    termLabel: "Fall 2026",
    weeksInTerm: 14,
    rows: createFall2026SampleRows(14),
  };
}

function persistDraft(draft: PersistedDraft): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(
      DISTRIBUTION_DRAFT_STORAGE_KEY,
      JSON.stringify(draft),
    );
  } catch {
    // Ignore storage quota errors
  }
}

interface DistributionDraftState {
  termLabel: string;
  weeksInTerm: number;
  rows: CourseDistributionOfferingRow[];
  past: CourseDistributionOfferingRow[][];
  setTermLabel: (label: string) => void;
  setWeeksInTerm: (weeks: number) => void;
  addRow: (row?: Partial<CourseDistributionOfferingRow>) => string;
  duplicateRow: (id: string) => void;
  updateRow: (id: string, patch: Partial<CourseDistributionOfferingRow>) => void;
  deleteRows: (ids: readonly string[]) => void;
  bulkUpdateRows: (
    ids: readonly string[],
    patch: Partial<CourseDistributionOfferingRow>,
  ) => void;
  appendRows: (newRows: readonly CourseDistributionOfferingRow[]) => void;
  replaceRows: (newRows: readonly CourseDistributionOfferingRow[]) => void;
  loadFall2026Sample: () => void;
  clearAllRows: () => void;
  undo: () => void;
}

const initial = readInitialDraft();

export const useDistributionDraftStore = create<DistributionDraftState>(
  (set, get) => {
    const commit = (
      nextRows: CourseDistributionOfferingRow[],
      recordUndo = true,
      nextTermLabel?: string,
      nextWeeks?: number,
    ) => {
      const state = get();
      const termLabel = nextTermLabel ?? state.termLabel;
      const weeksInTerm = nextWeeks ?? state.weeksInTerm;
      const past = recordUndo
        ? [...state.past.slice(-19), state.rows]
        : state.past;
      persistDraft({ termLabel, weeksInTerm, rows: nextRows });
      set({ rows: nextRows, past, termLabel, weeksInTerm });
    };

    return {
      termLabel: initial.termLabel,
      weeksInTerm: initial.weeksInTerm,
      rows: initial.rows,
      past: [],

      setTermLabel: (label) => {
        const state = get();
        persistDraft({
          termLabel: label,
          weeksInTerm: state.weeksInTerm,
          rows: state.rows,
        });
        set({ termLabel: label });
      },

      setWeeksInTerm: (weeks) => {
        const safe = Math.max(1, Math.min(26, Math.round(weeks || 14)));
        const state = get();
        persistDraft({
          termLabel: state.termLabel,
          weeksInTerm: safe,
          rows: state.rows,
        });
        set({ weeksInTerm: safe });
      },

      addRow: (partial) => {
        const state = get();
        const id = `offering-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
        const credit = partial?.credit ?? 3;
        const code = partial?.courseCode ?? "CSE-";
        const title = partial?.courseTitle ?? "";
        const derived = computeDistributionSessions(
          credit,
          state.weeksInTerm,
          isLabCourseCode(code, title),
        );
        const newRow: CourseDistributionOfferingRow = {
          id,
          batch: partial?.batch ?? "69",
          section: partial?.section ?? "A",
          courseCode: code,
          courseTitle: title,
          credit,
          prerequisite: partial?.prerequisite ?? "",
          conductingDept: partial?.conductingDept ?? "CSE",
          students: partial?.students ?? 40,
          teacher: partial?.teacher ?? "",
          totalClasses: partial?.totalClasses ?? derived.totalClasses,
          classDuration: partial?.classDuration ?? 1.5,
          classesPerWeek: partial?.classesPerWeek ?? derived.classesPerWeek,
        };
        commit([newRow, ...state.rows]);
        return id;
      },

      duplicateRow: (id) => {
        const state = get();
        const idx = state.rows.findIndex((r) => r.id === id);
        if (idx < 0) return;
        const src = state.rows[idx]!;
        const copy: CourseDistributionOfferingRow = {
          ...src,
          id: `offering-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
        };
        const next = [...state.rows];
        next.splice(idx + 1, 0, copy);
        commit(next);
      },

      updateRow: (id, patch) => {
        const state = get();
        const next = state.rows.map((r) => {
          if (r.id !== id) return r;
          const merged = { ...r, ...patch };
          const shouldRecompute =
            ("credit" in patch || "courseCode" in patch || "courseTitle" in patch) &&
            !("totalClasses" in patch) &&
            !("classesPerWeek" in patch);
          if (shouldRecompute) {
            const derived = computeDistributionSessions(
              merged.credit,
              state.weeksInTerm,
              isLabCourseCode(merged.courseCode, merged.courseTitle),
            );
            merged.totalClasses = derived.totalClasses;
            merged.classesPerWeek = derived.classesPerWeek;
          }
          return merged;
        });
        commit(next);
      },

      deleteRows: (ids) => {
        const idSet = new Set(ids);
        commit(get().rows.filter((r) => !idSet.has(r.id)));
      },

      bulkUpdateRows: (ids, patch) => {
        const idSet = new Set(ids);
        commit(
          get().rows.map((r) => (idSet.has(r.id) ? { ...r, ...patch } : r)),
        );
      },

      appendRows: (newRows) => {
        commit([...get().rows, ...newRows]);
      },

      replaceRows: (newRows) => {
        commit([...newRows]);
      },

      loadFall2026Sample: () => {
        const weeks = get().weeksInTerm;
        commit(createFall2026SampleRows(weeks));
      },

      clearAllRows: () => {
        commit([]);
      },

      undo: () => {
        const state = get();
        if (state.past.length === 0) return;
        const previous = state.past[state.past.length - 1]!;
        const remainingPast = state.past.slice(0, -1);
        persistDraft({
          termLabel: state.termLabel,
          weeksInTerm: state.weeksInTerm,
          rows: previous,
        });
        set({ rows: previous, past: remainingPast });
      },
    };
  },
);
