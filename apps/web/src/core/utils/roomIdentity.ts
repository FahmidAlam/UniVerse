/**
 * Physical room identity resolution and joint section (`B+C`) matching.
 * Exact parity with `lib/core/utils/room_identity.dart` and
 * `RoutineEntry.matchesStudent` (`lib/core/models/routine_model.dart`).
 */

function normalizeLabel(text: string): string {
  return text.trim().toUpperCase().replace(/\s+/g, " ");
}

export const RoomIdentity = {
  currentKey(label: string): string {
    return RoomIdentity.key(label, { "PHY LAB": "RAB-106" });
  },

  key(
    label: string,
    aliases: Record<string, string> = {},
  ): string {
    const mapping = new Map<string, string>();
    for (const [k, v] of Object.entries(aliases)) {
      mapping.set(normalizeLabel(k), normalizeLabel(v));
    }

    let result = normalizeLabel(label);
    const seen = new Set<string>();
    while (mapping.has(result) && mapping.get(result) !== result) {
      if (seen.has(result)) {
        throw new Error(`Cyclic room aliases detected at "${result}".`);
      }
      seen.add(result);
      result = mapping.get(result)!;
    }
    return result;
  },
};

export function splitJointSections(section: string): string[] {
  return Array.from(
    new Set(
      section
        .split("+")
        .map((part) => part.trim().toUpperCase())
        .filter((part) => part.length > 0),
    ),
  );
}

/**
 * Matches `RoutineEntry.matchesStudent`: `"B+C"` matches `"B"`, `"C"`, and `"B+C"`.
 */
export function matchesJointSection(
  entrySection: string,
  filterSection: string,
): boolean {
  const normalizedEntry = entrySection.trim().toUpperCase();
  const normalizedFilter = filterSection.trim().toUpperCase();
  if (!normalizedFilter) return true;
  if (normalizedEntry === normalizedFilter) return true;

  const entryMembers = splitJointSections(normalizedEntry);
  const filterMembers = splitJointSections(normalizedFilter);
  if (filterMembers.length === 1) {
    return entryMembers.includes(filterMembers[0]!);
  }
  return filterMembers.every((m) => entryMembers.includes(m));
}

/**
 * Returns true if two section strings on the same batch share at least one member
 * (e.g., `"B+C"` overlaps `"B"`, `"C"`, and `"B+C"`).
 */
export function jointSectionsOverlap(a: string, b: string): boolean {
  const aMembers = splitJointSections(a);
  const bMembers = splitJointSections(b);
  if (aMembers.length === 0 || bMembers.length === 0) {
    return a.trim().toUpperCase() === b.trim().toUpperCase();
  }
  return aMembers.some((member) => bMembers.includes(member));
}
