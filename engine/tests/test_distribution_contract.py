import hashlib
import io

import openpyxl
import pytest

import distribution
import ingest
from conftest import build_workbook, make_row


def source(rows):
    return build_workbook(rows)


def test_source_bytes_are_hashed_and_never_mutated():
    raw = source([make_row(code='CSE-1101', classes=14)])
    draft = distribution.DistributionDraft.create(raw)
    assert draft.source.sha256 == hashlib.sha256(raw).hexdigest()
    assert draft.source.bytes == raw
    assert draft.current_revision == 0


def test_correction_is_audited_and_rejects_a_stale_revision():
    draft = distribution.DistributionDraft.create(source([make_row(classes=14)]))
    next_draft = draft.correct(
        expected_revision=0, author_id='reviewer-1', reason='Committee confirmed count',
        changes=[distribution.CellCorrection(row=6, column='J', value=28)],
    )
    assert next_draft.current_revision == 1
    assert next_draft.history[-1].reason == 'Committee confirmed count'
    with pytest.raises(distribution.StaleRevisionError):
        draft.correct(expected_revision=1, author_id='reviewer-1', reason='stale',
                      changes=[distribution.CellCorrection(row=6, column='J', value=21)])


def test_effective_revision_invalidates_derived_artifacts_and_normalizes_split_teachers():
    raw = source([
        make_row(section='B+C', code='CSE-2101', teacher='AAA', classes=14),
        make_row(section='B+C', code='CSE-2101', teacher='BBB', classes=14),
    ])
    draft = distribution.DistributionDraft.create(raw).mark_derived('normalization').mark_derived('generation')
    changed = draft.correct(expected_revision=0, author_id='reviewer-1', reason='Reviewed total',
                            changes=[distribution.CellCorrection(row=6, column='J', value=21)])
    assert changed.invalidated_artifacts == frozenset({'normalization', 'generation'})
    normalized = distribution.normalize(changed)
    offering, = normalized['offerings']
    assert offering['section'] == 'B+C'
    assert offering['teachers'] == ['AAA', 'BBB']
    assert offering['classes_total'] == 35
    assert offering['source_rows'] == [6, 7]


def test_formula_cells_retain_formula_and_fail_validation_without_cached_value():
    raw = source([make_row(classes=14)])
    workbook = openpyxl.load_workbook(io.BytesIO(raw))
    workbook['Course Distribution']['J6'] = '=7*2'
    output = io.BytesIO(); workbook.save(output)
    draft = distribution.DistributionDraft.create(output.getvalue())
    cell = draft.source.cells[(6, 'J')]
    assert cell.formula == '=7*2'
    assert cell.cached_value is None
    with pytest.raises(distribution.ValidationError, match='cached value'):
        distribution.normalize(draft)
