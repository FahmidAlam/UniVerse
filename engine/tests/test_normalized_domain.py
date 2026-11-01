from datetime import date
import pytest


def uid(n):
    return f'40000000-0000-0000-0000-{n:012d}'


def normalized():
    from domain import (SourceRef, TeacherAssignment, RoomCriteria, Offering,
                        NormalizedInput, Faculty, Room)
    day = date(2026, 10, 25)
    source = SourceRef(file_hash='a'*64, sheet='Synthetic', row=6, column='I')
    teacher = TeacherAssignment(faculty_id=uid(1), assignment_kind='co_teaching', effective_dates=(day,))
    offering = Offering(id=uid(2), course_id=uid(3), course_code='TEST', title='Synthetic',
        group_ids=(uid(4),uid(5)), teacher_assignments=(teacher,), teacher_state='assigned',
        meeting_count=1, contact_minutes=60, duration_minutes=60, delivery_mode='in_person',
        room_criteria=RoomCriteria(minimum_capacity=None, required_features=(), eligible_room_ids=(uid(6),)),
        source_refs=(source,), is_service=False)
    return NormalizedInput(schema_version=1,input_revision_id=uid(7),scope_id=uid(8),term_id=uid(9),
        policy_revision_id=uid(10),resource_revision=1,timezone='Asia/Dhaka',teaching_dates=(day,),
        offerings=(offering,),faculty=(Faculty(id=uid(1),home_department_id=None,display_name='Synthetic',is_active=True),),
        rooms=(Room(id=uid(6),name='Synthetic',campus=None,capacity=None,features=(),is_active=True),),
        external_reservations=(),approved_exclusions=())


def test_typed_normalized_input_round_trips_with_all_groups_and_provenance():
    from domain import NormalizedInput
    value = normalized()
    assert NormalizedInput.from_map(value.to_map()) == value
    assert len(value.offerings[0].group_ids) == 2
    assert value.offerings[0].source_refs[0].row == 6


def test_pending_is_preserved_without_fictitious_teacher():
    from domain import NormalizedInput
    data = normalized().to_map()
    data['offerings'][0].update(teacher_assignments=[], teacher_state='pending')
    value = NormalizedInput.from_map(data)
    assert value.offerings[0].teacher_state == 'pending'
    assert value.offerings[0].teacher_assignments == ()
    data['offerings'][0]['teacher_state'] = 'assigned'
    with pytest.raises(ValueError):
        NormalizedInput.from_map(data)


@pytest.mark.parametrize('mutate',[
    lambda d:d.update(resource_revision=True),
    lambda d:d.update(schema_version=2),
    lambda d:d['offerings'][0]['teacher_assignments'][0].update(faculty_id=uid(99)),
    lambda d:d['offerings'][0]['teacher_assignments'][0].update(effective_dates=['2027-01-01']),
    lambda d:d['offerings'][0].update(duration_minutes=0),
    lambda d:d['offerings'][0]['source_refs'][0].update(file_hash='not-a-checksum'),
])
def test_bad_revisions_unknown_identity_dates_or_requirements_reject(mutate):
    from domain import NormalizedInput
    data=normalized().to_map(); mutate(data)
    with pytest.raises(ValueError): NormalizedInput.from_map(data)


def test_assignments_reject_overnight_and_validation_reports_derive_ok():
    from domain import Assignment, ValidationIssue, ValidationReport
    with pytest.raises(ValueError):
        Assignment(id=uid(11),offering_id=uid(2),teaching_dates=(date(2026,10,25),),
            start_minute=1400,end_minute=60,room_id=uid(6),faculty_ids=(uid(1),),group_ids=(uid(4),uid(5)),pinned=False)
    issue=ValidationIssue(rule_id='teacher_conflict',severity='error',message='Synthetic conflict',
        offering_ids=(uid(2),),resource_ids=(uid(1),),source_refs=())
    report=ValidationReport(schema_version=1,input_revision_id=uid(7),policy_revision_id=uid(10),resource_revision=1,issues=(issue,))
    assert not report.ok
    assert ValidationReport.from_map(report.to_map())==report


def test_policy_identity_carrier_round_trips_without_inventing_academic_rules():
    from domain import PolicySnapshot
    value = PolicySnapshot(schema_version=1, policy_revision_id=uid(10),
        scope_id=uid(8), term_id=uid(9), resource_revision=1,
        teaching_dates=(date(2026,10,25),))
    assert PolicySnapshot.from_map(value.to_map()) == value
    data = value.to_map(); data['resource_revision'] = False
    with pytest.raises(ValueError): PolicySnapshot.from_map(data)
