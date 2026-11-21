import { create } from "zustand";
import {
  INITIAL_SPECIMEN_CONFIG,
  type SandboxConfig,
  type SandboxLens,
} from "@/features/onboarding/data/routineFixtures";

export type SpecimenViewMode = "matrix" | "list";

export function getInitialSpecimenViewMode(): SpecimenViewMode {
  if (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(max-width: 767px)").matches
  ) {
    return "list";
  }
  return "matrix";
}

interface SpecimenStoreState {
  config: SandboxConfig;
  viewMode: SpecimenViewMode;
  toggleJummah: (next: boolean) => void;
  toggleR7: (next: boolean) => void;
  setSlots: (slots: 6 | 7) => void;
  setLens: (lens: SandboxLens) => void;
  setViewMode: (view: SpecimenViewMode) => void;
  resetSpecimen: () => void;
}

export const useSpecimenStore = create<SpecimenStoreState>((set) => ({
  config: INITIAL_SPECIMEN_CONFIG,
  viewMode: getInitialSpecimenViewMode(),
  toggleJummah: (next) =>
    set((s) => ({ config: { ...s.config, jummah: next } })),
  toggleR7: (next) =>
    set((s) => ({ config: { ...s.config, r7Enforced: next } })),
  setSlots: (slots) =>
    set((s) => ({ config: { ...s.config, slots } })),
  setLens: (lens) =>
    set((s) => ({ config: { ...s.config, lens } })),
  setViewMode: (viewMode) => set({ viewMode }),
  resetSpecimen: () =>
    set({
      config: INITIAL_SPECIMEN_CONFIG,
      viewMode: getInitialSpecimenViewMode(),
    }),
}));
