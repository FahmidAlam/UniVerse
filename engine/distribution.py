"""Immutable, revisioned Course Distribution source contract.

This boundary deliberately preserves the uploaded workbook bytes.  Accepted
corrections are row/column overlays with audit metadata; normalization receives
only a freshly rendered in-memory effective copy, never a rewritten source.
"""
from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import datetime, timezone
import hashlib
import io
from types import MappingProxyType
from typing import Mapping
from uuid import UUID

import openpyxl

import ingest


SHEET = 'Course Distribution'
FORMULA_COLUMNS = frozenset({'J', 'L'})
EDITABLE_COLUMNS = frozenset('ABCDEFGHIJKL')


class ValidationError(ValueError):
    pass


class StaleRevisionError(ValidationError):
    pass


@dataclass(frozen=True)
class SourceCell:
    row: int
    column: str
    value: object
    formula: str | None
    cached_value: object


@dataclass(frozen=True)
class SourceWorkbook:
    bytes: bytes
    sha256: str
    sheet: str
    cells: MappingProxyType


@dataclass(frozen=True)
class CellCorrection:
    row: int
    column: str
    value: object

    def __post_init__(self):
        if self.row < ingest.DATA_START or self.column not in EDITABLE_COLUMNS:
            raise ValidationError('Correction needs a Course Distribution data cell')


@dataclass(frozen=True)
class CorrectionRevision:
    revision: int
    parent_revision: int
    author_id: str
    created_at: datetime
    reason: str
    changes: tuple[CellCorrection, ...]


@dataclass(frozen=True)
class DistributionDraft:
    source: SourceWorkbook
    current_revision: int
    history: tuple[CorrectionRevision, ...]
    effective_values: MappingProxyType
    invalidated_artifacts: frozenset[str]

    @classmethod
    def create(cls, raw: bytes) -> 'DistributionDraft':
        if not raw:
            raise ValidationError('Workbook bytes are required')
        formulas = openpyxl.load_workbook(io.BytesIO(raw), data_only=False)
        cached = openpyxl.load_workbook(io.BytesIO(raw), data_only=True)
        if SHEET not in formulas.sheetnames:
            raise ValidationError(f'Workbook has no {SHEET!r} sheet')
        formula_sheet, cached_sheet = formulas[SHEET], cached[SHEET]
        cells = {}
        for row in range(ingest.DATA_START, (formula_sheet.max_row or ingest.DATA_START) + 1):
            for column in EDITABLE_COLUMNS:
                formula_value = formula_sheet[f'{column}{row}'].value
                if formula_value is None:
                    continue
                formula = formula_value if isinstance(formula_value, str) and formula_value.startswith('=') else None
                cells[(row, column)] = SourceCell(row, column, formula_value, formula,
                                                   cached_sheet[f'{column}{row}'].value)
        return cls(SourceWorkbook(raw, hashlib.sha256(raw).hexdigest(), SHEET,
                                  MappingProxyType(cells)), 0, (), MappingProxyType({}), frozenset())

    def mark_derived(self, artifact: str) -> 'DistributionDraft':
        if not artifact.strip():
            raise ValidationError('Derived artifact name is required')
        return replace(self, invalidated_artifacts=self.invalidated_artifacts | {artifact})

    def correct(self, *, expected_revision: int, author_id: str, reason: str,
                changes: list[CellCorrection]) -> 'DistributionDraft':
        if expected_revision != self.current_revision:
            raise StaleRevisionError(f'Expected revision {expected_revision}, current revision is {self.current_revision}')
        if not author_id.strip() or not reason.strip() or not changes:
            raise ValidationError('Correction author, reason, and at least one change are required')
        keys = [(change.row, change.column) for change in changes]
        if len(set(keys)) != len(keys) or any(key not in self.source.cells for key in keys):
            raise ValidationError('Corrections must target distinct existing source cells')
        values = dict(self.effective_values)
        for change in changes:
            values[(change.row, change.column)] = change.value
        revision = CorrectionRevision(self.current_revision + 1, self.current_revision, author_id,
                                      datetime.now(timezone.utc), reason, tuple(changes))
        return DistributionDraft(self.source, revision.revision, self.history + (revision,),
                                 MappingProxyType(values), self.invalidated_artifacts)

    def effective_bytes(self) -> bytes:
        workbook = openpyxl.load_workbook(io.BytesIO(self.source.bytes), data_only=False)
        sheet = workbook[self.source.sheet]
        for (row, column), value in self.effective_values.items():
            sheet[f'{column}{row}'] = value
        output = io.BytesIO(); workbook.save(output)
        return output.getvalue()


def normalize(draft: DistributionDraft, *, weeks_in_term: int = 14,
              fixed_sessions_per_week: int | None = None) -> dict:
    """Validate formula provenance then return legacy-engine compatible input.

    The legacy solver still consumes the ingest dictionary.  This adapter keeps
    that one parser/normalizer as the compatibility boundary until all solver
    consumers accept ``domain.NormalizedInput`` directly.
    """
    for key, cell in draft.source.cells.items():
        if cell.column in FORMULA_COLUMNS and cell.formula and key not in draft.effective_values and cell.cached_value is None:
            raise ValidationError(f'Row {cell.row} column {cell.column} formula has no cached value')
    result = ingest.ingest_bytes(draft.effective_bytes(), weeks_in_term, fixed_sessions_per_week)
    result['source_contract'] = {
        'source_sha256': draft.source.sha256,
        'revision': draft.current_revision,
        'invalidated_artifacts': sorted(draft.invalidated_artifacts),
    }
    return result


def draft_from_persisted_revision(raw: bytes, contract: Mapping[str, object]) -> DistributionDraft:
    """Build an effective draft only from an accepted, hash-bound DB bundle.

    The bundle is intentionally data, not an authority token. The caller must
    obtain it through the capability-checked database RPC; this boundary then
    verifies that the immutable bytes and every correction provenance record
    actually describe the workbook it is about to normalize.
    """
    required = {
        'source_id', 'revision_id', 'revision_number', 'revision_version',
        'status', 'source_sha256', 'corrections',
    }
    if not required.issubset(contract):
        raise ValidationError('Persisted source contract is incomplete')
    try:
        UUID(str(contract['source_id']))
        UUID(str(contract['revision_id']))
    except (TypeError, ValueError, AttributeError) as error:
        raise ValidationError('Persisted source contract has an invalid identity') from error
    if contract['status'] != 'accepted':
        raise ValidationError('Persisted source contract is not accepted')
    revision_number = contract['revision_number']
    revision_version = contract['revision_version']
    if (isinstance(revision_number, bool) or not isinstance(revision_number, int)
            or isinstance(revision_version, bool) or not isinstance(revision_version, int)
            or revision_number < 1 or revision_version < 1):
        raise ValidationError('Persisted source contract has an invalid revision')

    draft = DistributionDraft.create(raw)
    source_hash = contract['source_sha256']
    if not isinstance(source_hash, str) or source_hash != draft.source.sha256:
        raise ValidationError('Persisted source contract hash does not match workbook bytes')
    corrections = contract['corrections']
    if not isinstance(corrections, list):
        raise ValidationError('Persisted source contract corrections must be a list')

    effective_values: dict[tuple[int, str], object] = {}
    for correction in corrections:
        if not isinstance(correction, Mapping):
            raise ValidationError('Persisted correction is invalid')
        required_correction = {
            'source_row', 'source_column', 'original_formula',
            'original_cached_value', 'effective_value',
        }
        if not required_correction.issubset(correction):
            raise ValidationError('Persisted correction provenance is incomplete')
        row, column = correction['source_row'], correction['source_column']
        if isinstance(row, bool) or not isinstance(row, int) or not isinstance(column, str):
            raise ValidationError('Persisted correction location is invalid')
        key = (row, column)
        cell = draft.source.cells.get(key)
        if cell is None or key in effective_values:
            raise ValidationError('Persisted correction does not target one source cell')
        if (correction['original_formula'] != cell.formula
                or correction['original_cached_value'] != cell.cached_value):
            raise ValidationError('Persisted correction provenance does not match workbook')
        value = correction['effective_value']
        if value is None or not isinstance(value, (str, int, float, bool)):
            raise ValidationError('Persisted correction effective value is invalid')
        effective_values[key] = value

    return replace(
        draft,
        current_revision=revision_version,
        effective_values=MappingProxyType(effective_values),
    )


def normalize_persisted_revision(raw: bytes, contract: Mapping[str, object], *,
                                 weeks_in_term: int = 14,
                                 fixed_sessions_per_week: int | None = None) -> dict:
    """Normalize an accepted database revision without mutating source bytes."""
    draft = draft_from_persisted_revision(raw, contract)
    result = normalize(
        draft,
        weeks_in_term=weeks_in_term,
        fixed_sessions_per_week=fixed_sessions_per_week,
    )
    result['source_contract'].update({
        'source_id': str(contract['source_id']),
        'revision_id': str(contract['revision_id']),
        'revision_number': contract['revision_number'],
        'revision_version': contract['revision_version'],
    })
    return result
