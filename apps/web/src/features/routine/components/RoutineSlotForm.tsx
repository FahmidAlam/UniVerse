import { WarningCircle } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { Button } from "@/components/ui/Button";
import { ClockTime } from "@/core/utils/clockTime";
import { ACADEMIC_WEEK_DAYS } from "@/features/admin/services/facultyService";
import type { TimetableSettingsRecord } from "@/features/admin/services/settingsService";
import { detectRoutineClashes } from "@/features/routine/services/routineService";
import type { RoutineRow, RoutineWriteInput } from "@/features/routine/types";

interface RoutineSlotFormProps {
  initialValue?: Partial<RoutineRow>;
  existingRows: readonly RoutineRow[];
  ignoreId?: string | null;
  settings: TimetableSettingsRecord;
  isSubmitting: boolean;
  submitLabel: string;
  onSubmit: (input: RoutineWriteInput) => Promise<void>;
  onCancel: () => void;
}

export function RoutineSlotForm({
  initialValue,
  existingRows,
  ignoreId,
  settings,
  isSubmitting,
  submitLabel,
  onSubmit,
  onCancel,
}: RoutineSlotFormProps) {
  const defaultPeriod = settings.periods[0];

  const [day, setDay] = useState(initialValue?.day ?? "Sunday");
  const [timeStart, setTimeStart] = useState(
    initialValue?.time_start
      ? ClockTime.toHm(initialValue.time_start)
      : (defaultPeriod?.start ?? "08:50"),
  );
  const [timeEnd, setTimeEnd] = useState(
    initialValue?.time_end
      ? ClockTime.toHm(initialValue.time_end)
      : (defaultPeriod?.end ?? "10:05"),
  );
  const [subjectCode, setSubjectCode] = useState(
    initialValue?.subject_code ?? "",
  );
  const [subject, setSubject] = useState(initialValue?.subject ?? "");
  const [teacherCode, setTeacherCode] = useState(
    initialValue?.teacher_code ?? "",
  );
  const [teacherName, setTeacherName] = useState(
    initialValue?.teacher_name ?? "",
  );
  const [room, setRoom] = useState(initialValue?.room ?? "");
  const [batch, setBatch] = useState(initialValue?.batch ?? "");
  const [section, setSection] = useState(initialValue?.section ?? "A");
  const [semester, setSemester] = useState(
    String(initialValue?.semester ?? 1),
  );
  const [isService, setIsService] = useState(
    Boolean(initialValue?.is_service),
  );
  const [isActive, setIsActive] = useState(initialValue?.is_active ?? true);
  const [formError, setFormError] = useState<string | null>(null);

  const normalizedTimeError = useMemo(() => {
    const s = ClockTime.normalize(timeStart);
    const e = ClockTime.normalize(timeEnd);
    if (!s || !e) return "Enter valid 24-hour HH:MM start and end times.";
    const sm = ClockTime.toMinutes(s);
    const em = ClockTime.toMinutes(e);
    if (sm === null || em === null || em <= sm) {
      return "End time must be strictly after start time.";
    }
    return null;
  }, [timeStart, timeEnd]);

  const isFridayP4Blocked = useMemo(() => {
    if (day !== "Friday" || !settings.friday_no_p4) return false;
    const p4 = settings.periods.find((p) => p.idx === 4);
    if (!p4) return false;
    const startNorm = ClockTime.toHm(ClockTime.normalizeOr(timeStart));
    return startNorm === ClockTime.toHm(p4.start);
  }, [day, settings.friday_no_p4, settings.periods, timeStart]);

  const liveClashes = useMemo(() => {
    if (normalizedTimeError || !batch.trim() || !section.trim()) return [];
    return detectRoutineClashes(
      {
        day,
        time_start: ClockTime.toHms(timeStart),
        time_end: ClockTime.toHms(timeEnd),
        teacher_code: teacherCode,
        room,
        batch,
        section,
      },
      existingRows,
      ignoreId,
    );
  }, [
    batch,
    day,
    existingRows,
    ignoreId,
    normalizedTimeError,
    room,
    section,
    teacherCode,
    timeEnd,
    timeStart,
  ]);

  const handlePeriodPreset = (periodIdx: number) => {
    const found = settings.periods.find((p) => p.idx === periodIdx);
    if (!found) return;
    setTimeStart(ClockTime.toHm(found.start));
    setTimeEnd(ClockTime.toHm(found.end));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    if (normalizedTimeError) {
      setFormError(normalizedTimeError);
      return;
    }
    if (isFridayP4Blocked) {
      setFormError(
        "Friday Period 4 is locked for the Jummah prayer window under committee policy.",
      );
      return;
    }
    if (!subjectCode.trim() || !subject.trim()) {
      setFormError("Course code and course title are required.");
      return;
    }
    if (!batch.trim() || !section.trim()) {
      setFormError("Batch and section are required.");
      return;
    }

    const semNum = Number.parseInt(semester, 10);
    try {
      await onSubmit({
        day,
        time_start: ClockTime.toHms(timeStart),
        time_end: ClockTime.toHms(timeEnd),
        subject: subject.trim(),
        subject_code: subjectCode.trim().toUpperCase(),
        teacher_code: teacherCode.trim() ? teacherCode.trim().toUpperCase() : null,
        teacher_name: teacherName.trim() ? teacherName.trim() : null,
        room: room.trim() ? room.trim().toUpperCase() : "TBA",
        batch: batch.trim(),
        section: section.trim().toUpperCase(),
        semester: Number.isFinite(semNum) && semNum >= 0 ? semNum : 1,
        is_active: isActive,
        is_service: isService,
        routine_version_id: initialValue?.routine_version_id,
      });
    } catch (err) {
      setFormError(
        err instanceof Error ? err.message : "Could not save routine slot.",
      );
    }
  };

  return (
    <form onSubmit={(e) => void handleSubmit(e)} className="space-y-3.5">
      {/* Period Preset Quick Strip */}
      <div>
        <div className="mb-1.5 text-[11.5px] font-medium text-[var(--ink-secondary)]">
          Quick Period Boundary
        </div>
        <div className="flex flex-wrap gap-1.5">
          {settings.periods.map((p) => {
            const active =
              ClockTime.toHm(ClockTime.normalizeOr(timeStart)) ===
                ClockTime.toHm(p.start) &&
              ClockTime.toHm(ClockTime.normalizeOr(timeEnd)) ===
                ClockTime.toHm(p.end);
            return (
              <button
                key={p.idx}
                type="button"
                onClick={() => handlePeriodPreset(p.idx)}
                className={`font-mono-tabular h-7 rounded-[5px] border px-2 text-[11.5px] transition-colors ${
                  active
                    ? "border-[var(--accent-pine)] bg-[var(--accent-pine-soft)] font-semibold text-[var(--accent-pine)]"
                    : "border-[var(--border-subtle)] bg-[var(--bg-surface)] text-[var(--ink-secondary)] hover:bg-[var(--surface-hover)]"
                }`}
              >
                {p.idx >= 8 ? `OL P${p.idx}` : `P${p.idx}`}
              </button>
            );
          })}
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <div>
          <label
            htmlFor="slot-day"
            className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
          >
            Day
          </label>
          <select
            id="slot-day"
            value={day}
            onChange={(e) => setDay(e.target.value)}
            className="h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
          >
            {ACADEMIC_WEEK_DAYS.map((d) => (
              <option key={d} value={d}>
                {d}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label
            htmlFor="slot-start"
            className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
          >
            Start (24h)
          </label>
          <input
            id="slot-start"
            type="text"
            value={timeStart}
            onChange={(e) => setTimeStart(e.target.value)}
            placeholder="08:50"
            className="font-mono-tabular h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
          />
        </div>

        <div>
          <label
            htmlFor="slot-end"
            className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
          >
            End (24h)
          </label>
          <input
            id="slot-end"
            type="text"
            value={timeEnd}
            onChange={(e) => setTimeEnd(e.target.value)}
            placeholder="10:05"
            className="font-mono-tabular h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
          />
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div>
          <label
            htmlFor="slot-subject-code"
            className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
          >
            Course Code
          </label>
          <input
            id="slot-subject-code"
            type="text"
            value={subjectCode}
            onChange={(e) => setSubjectCode(e.target.value)}
            placeholder="e.g. CSE-3101"
            className="font-mono-tabular h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
          />
        </div>

        <div>
          <label
            htmlFor="slot-room"
            className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
          >
            Room
          </label>
          <input
            id="slot-room"
            type="text"
            value={room}
            onChange={(e) => setRoom(e.target.value)}
            placeholder="e.g. RAB-302 or ACL-1"
            className="font-mono-tabular h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
          />
        </div>
      </div>

      <div>
        <label
          htmlFor="slot-subject"
          className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
        >
          Course Title
        </label>
        <input
          id="slot-subject"
          type="text"
          value={subject}
          onChange={(e) => setSubject(e.target.value)}
          placeholder="e.g. Database Management Systems"
          className="h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
        />
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div>
          <label
            htmlFor="slot-teacher-code"
            className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
          >
            Faculty Acronym
          </label>
          <input
            id="slot-teacher-code"
            type="text"
            value={teacherCode}
            onChange={(e) => setTeacherCode(e.target.value)}
            placeholder="e.g. EBH"
            className="font-mono-tabular h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
          />
        </div>

        <div>
          <label
            htmlFor="slot-teacher-name"
            className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
          >
            Faculty Full Name (optional)
          </label>
          <input
            id="slot-teacher-name"
            type="text"
            value={teacherName}
            onChange={(e) => setTeacherName(e.target.value)}
            placeholder="e.g. Md. Ebrahim Hossain"
            className="h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
          />
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2.5">
        <div>
          <label
            htmlFor="slot-batch"
            className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
          >
            Batch
          </label>
          <input
            id="slot-batch"
            type="text"
            value={batch}
            onChange={(e) => setBatch(e.target.value)}
            placeholder="58"
            className="font-mono-tabular h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
          />
        </div>

        <div>
          <label
            htmlFor="slot-section"
            className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
          >
            Section
          </label>
          <input
            id="slot-section"
            type="text"
            value={section}
            onChange={(e) => setSection(e.target.value)}
            placeholder="A or B+C"
            className="font-mono-tabular h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
          />
        </div>

        <div>
          <label
            htmlFor="slot-semester"
            className="mb-1 block text-[12px] font-medium text-[var(--ink-primary)]"
          >
            Semester
          </label>
          <input
            id="slot-semester"
            type="number"
            min={0}
            max={12}
            value={semester}
            onChange={(e) => setSemester(e.target.value)}
            className="font-mono-tabular h-9 w-full rounded-[var(--r-control)] border border-[var(--border-control)] bg-[var(--bg-elevated)] px-2.5 text-[13px] text-[var(--ink-primary)] focus:border-[var(--ink-primary)] focus:outline-none"
          />
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-4 pt-1 text-[12.5px]">
        <label className="inline-flex cursor-pointer items-center gap-2 text-[var(--ink-primary)]">
          <input
            type="checkbox"
            checked={isService}
            onChange={(e) => setIsService(e.target.checked)}
            className="h-4 w-4 accent-[var(--accent-pine)]"
          />
          <span>Service / GED course</span>
        </label>
        <label className="inline-flex cursor-pointer items-center gap-2 text-[var(--ink-primary)]">
          <input
            type="checkbox"
            checked={isActive}
            onChange={(e) => setIsActive(e.target.checked)}
            className="h-4 w-4 accent-[var(--accent-pine)]"
          />
          <span>Active slot</span>
        </label>
      </div>

      {/* Live Client-Side Clash Diagnostics */}
      {(liveClashes.length > 0 || isFridayP4Blocked) && (
        <div
          role="alert"
          data-testid="routine-slot-clash-warning"
          className="space-y-1.5 rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] p-3 text-[12px] text-[var(--sem-conflict-ink)]"
        >
          <div className="flex items-center gap-1.5 font-semibold">
            <WarningCircle size={15} className="shrink-0" aria-hidden="true" />
            <span>
              {isFridayP4Blocked
                ? "Friday P4 Jummah Hard Block"
                : `${liveClashes.length} schedule clash warning(s) detected`}
            </span>
          </div>
          {isFridayP4Blocked && (
            <p className="leading-[1.45]">
              Friday Period 4 is reserved for Jummah prayer and cannot be saved.
            </p>
          )}
          {liveClashes.map((c, idx) => (
            <p key={`${c.type}-${c.conflictingRow.id}-${idx}`} className="leading-[1.45]">
              {c.message}
            </p>
          ))}
        </div>
      )}

      {(formError || normalizedTimeError) && (
        <div
          role="alert"
          className="rounded-[var(--r-control)] border border-[var(--sem-conflict-border)] bg-[var(--sem-conflict-bg)] px-3 py-2 text-[12px] text-[var(--sem-conflict-ink)]"
        >
          {formError ?? normalizedTimeError}
        </div>
      )}

      <div className="flex flex-wrap justify-end gap-2 border-t border-[var(--border-subtle)] pt-3">
        <Button
          type="button"
          variant="secondary"
          size="sm"
          disabled={isSubmitting}
          onClick={onCancel}
        >
          Cancel
        </Button>
        <Button
          type="submit"
          variant="primary"
          size="sm"
          disabled={isSubmitting || isFridayP4Blocked || Boolean(normalizedTimeError)}
        >
          {isSubmitting ? "Saving..." : submitLabel}
        </Button>
      </div>
    </form>
  );
}
