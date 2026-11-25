export type ScheduleCategory = "theory" | "lab" | "joint" | "block";
export type SandboxLens = "section" | "faculty" | "room";

export interface PeriodDef {
  idx: number;
  code: string;
  time: string;
}

export interface SandboxSlot {
  id: string;
  day: string;
  period: number;
  code: string;
  actorOrGroup: string;
  room: string;
  category: ScheduleCategory;
  overrideNote?: string;
}

export interface SandboxConfig {
  jummah: boolean;
  r7Enforced: boolean;
  slots: 6 | 7;
  lens: SandboxLens;
}

export const INITIAL_SPECIMEN_CONFIG: SandboxConfig = {
  jummah: true,
  r7Enforced: true,
  slots: 6,
  lens: "section",
};

export const PERIODS_ALL: readonly PeriodDef[] = [
  { idx: 1, code: "P1", time: "08:50" },
  { idx: 2, code: "P2", time: "10:05" },
  { idx: 3, code: "P3", time: "11:20" },
  { idx: 4, code: "P4", time: "13:10" },
  { idx: 5, code: "P5", time: "14:25" },
  { idx: 6, code: "P6", time: "15:50" },
  { idx: 7, code: "P7", time: "17:10" },
] as const;

export const SANDBOX_DAYS = ["Sun", "Mon", "Tue", "Thu", "Fri"] as const;

export function buildSandboxSlots(cfg: SandboxConfig): SandboxSlot[] {
  const { jummah, r7Enforced, slots, lens } = cfg;

  if (lens === "section") {
    const items: SandboxSlot[] = [
      {
        id: "cse-3101-sun",
        day: "Sun",
        period: 1,
        code: "CSE-3101",
        actorOrGroup: "EBH",
        room: "RAB-302",
        category: "joint",
        overrideNote:
          "Joint B+C theory offering shared across Sections 58 B and 58 C.",
      },
      {
        id: "cse-3102-sun",
        day: "Sun",
        period: 2,
        code: "CSE-3102",
        actorOrGroup: "MSR",
        room: "ACL-1",
        category: "lab",
        overrideNote:
          "58 B+C lab split exception: Batch 58 B+C paired in ACL-1 consecutive block.",
      },
      {
        id: "cse-3105-mon",
        day: "Mon",
        period: 1,
        code: "CSE-3105",
        actorOrGroup: "KJH",
        room: "RAB-304",
        category: "theory",
      },
      {
        id: "cse-3101-ebh-shift",
        day: r7Enforced ? "Mon" : "Thu",
        period: 2,
        code: "CSE-3101",
        actorOrGroup: r7Enforced ? "EBH" : "EBH (R7 Clash)",
        room: "RAB-302",
        category: r7Enforced ? "joint" : "block",
        overrideNote: r7Enforced
          ? "Moved from Thu into Monday slot to satisfy EBH Thu–Fri off-day policy."
          : "Conflict flagged: permanent faculty off-day enforcement is disabled.",
      },
      {
        id: "cse-3201-tue",
        day: "Tue",
        period: 2,
        code: "CSE-3201",
        actorOrGroup: "SPJ",
        room: "RKB-401",
        category: "joint",
      },
      {
        id: "cse-3106-tue",
        day: "Tue",
        period: 3,
        code: "CSE-3106",
        actorOrGroup: "SAB",
        room: "ACL-2",
        category: "lab",
      },
      {
        id: "eee-2101-thu",
        day: "Thu",
        period: 4,
        code: "EEE-2101",
        actorOrGroup: "MRI",
        room: "ECL-1",
        category: "lab",
      },
      {
        id: "cse-3202-fri-shift",
        day: "Fri",
        period: jummah ? (slots === 7 ? 7 : 5) : 4,
        code: "CSE-3202",
        actorOrGroup: "MSR",
        room: "ACL-1",
        category: "lab",
      },
      {
        id: "cse-3105-fri",
        day: "Fri",
        period: 2,
        code: "CSE-3105",
        actorOrGroup: "KJH",
        room: "RAB-304",
        category: "theory",
      },
    ];

    if (jummah) {
      items.push({
        id: "jummah-lock",
        day: "Fri",
        period: 4,
        code: "JUMMAH",
        actorOrGroup: "Prayer Block",
        room: "Campus",
        category: "block",
      });
    }
    if (slots === 7) {
      items.push({
        id: "cse-3201-p7",
        day: "Mon",
        period: 7,
        code: "CSE-3201",
        actorOrGroup: "SPJ",
        room: "RAB-304",
        category: "theory",
      });
    }
    return items;
  }

  if (lens === "faculty") {
    const items: SandboxSlot[] = [
      {
        id: "cse-3101-sun",
        day: "Sun",
        period: 1,
        code: "CSE-3101",
        actorOrGroup: "58 B+C",
        room: "RAB-302",
        category: "joint",
        overrideNote:
          "Joint 58 B+C cohort assigned to single lecture session.",
      },
      {
        id: "cse-4101-sun",
        day: "Sun",
        period: 3,
        code: "CSE-4101",
        actorOrGroup: "56 A",
        room: "RAB-306",
        category: "theory",
      },
      {
        id: "cse-3101-ebh-shift",
        day: r7Enforced ? "Mon" : "Thu",
        period: 2,
        code: "CSE-3101",
        actorOrGroup: r7Enforced ? "58 B+C" : "R7 Violation",
        room: "RAB-302",
        category: r7Enforced ? "joint" : "block",
      },
      {
        id: "cse-4101-tue",
        day: "Tue",
        period: 1,
        code: "CSE-4101",
        actorOrGroup: "56 A",
        room: "RAB-306",
        category: "theory",
      },
      {
        id: "cse-4102-tue",
        day: "Tue",
        period: 4,
        code: "CSE-4102",
        actorOrGroup: "56 A",
        room: "ACL-3",
        category: "lab",
      },
    ];
    if (r7Enforced) {
      items.push({
        id: "ebh-r7-thu",
        day: "Thu",
        period: 1,
        code: "OFF-DAY",
        actorOrGroup: "EBH Bound",
        room: "R7 Held",
        category: "block",
      });
    }
    if (jummah) {
      items.push({
        id: "jummah-lock",
        day: "Fri",
        period: 4,
        code: "JUMMAH",
        actorOrGroup: "Prayer Block",
        room: "Campus",
        category: "block",
      });
    }
    if (slots === 7) {
      items.push({
        id: "cse-4101-p7",
        day: "Tue",
        period: 7,
        code: "CSE-4101",
        actorOrGroup: "Makeup 56 A",
        room: "RAB-306",
        category: "theory",
      });
    }
    return items;
  }

  // Room lens: Lab ACL-1
  const items: SandboxSlot[] = [
    {
      id: "cse-3102-sun",
      day: "Sun",
      period: 2,
      code: "CSE-3102",
      actorOrGroup: "58 B · MSR",
      room: "ACL-1",
      category: "lab",
      overrideNote: "Batch 58 B+C lab sequence pinned to ACL-1 workstations.",
    },
    {
      id: "cse-3102-c-sun",
      day: "Sun",
      period: 3,
      code: "CSE-3102",
      actorOrGroup: "58 C · MSR",
      room: "ACL-1",
      category: "lab",
    },
    {
      id: "cse-2204-mon",
      day: "Mon",
      period: 4,
      code: "CSE-2204",
      actorOrGroup: "59 A · SAB",
      room: "ACL-1",
      category: "lab",
    },
    {
      id: "cse-1202-tue",
      day: "Tue",
      period: 2,
      code: "CSE-1202",
      actorOrGroup: "61 B · AFZ",
      room: "ACL-1",
      category: "lab",
    },
    {
      id: "cse-2204-thu",
      day: "Thu",
      period: 2,
      code: "CSE-2204",
      actorOrGroup: "59 B · SAB",
      room: "ACL-1",
      category: "lab",
    },
    {
      id: "cse-3202-fri-shift",
      day: "Fri",
      period: jummah ? (slots === 7 ? 7 : 5) : 4,
      code: "CSE-3202",
      actorOrGroup: "58 C · MSR",
      room: "ACL-1",
      category: "lab",
    },
  ];
  if (jummah) {
    items.push({
      id: "jummah-lock",
      day: "Fri",
      period: 4,
      code: "JUMMAH",
      actorOrGroup: "Prayer Block",
      room: "Campus",
      category: "block",
    });
  }
  return items;
}
