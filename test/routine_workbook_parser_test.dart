import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/features/admin/services/routine_workbook_parser.dart';
import 'package:xml/xml.dart';

// Synthetic OOXML only: no original workbook bytes, teacher names or source
// records. The two grids below are test inputs, not approved seasonal timings.
String _text(String ref, String value) =>
    '<c r="$ref" t="inlineStr"><is><t>${XmlText(value)}</t></is></c>';

Uint8List _workbook(String sheet, String rows, {String? sharedHeader}) {
  final archive = Archive();
  void add(String path, String contents) {
    final bytes = utf8.encode(contents);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add('[Content_Types].xml', '''
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
${sharedHeader == null ? '' : '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'}
</Types>''');
  add('_rels/.rels', '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''');
  add('xl/workbook.xml', '''
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="$sheet" sheetId="1" r:id="rId1"/></sheets></workbook>''');
  add('xl/_rels/workbook.xml.rels', '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
${sharedHeader == null ? '' : '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'}
</Relationships>''');
  add('xl/styles.xml', '''
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="1"><font/></fonts><fills count="1"><fill><patternFill patternType="none"/></fill></fills>
<borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs>
<cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="18" applyNumberFormat="1"/></cellXfs>
</styleSheet>''');
  if (sharedHeader != null) {
    add('xl/sharedStrings.xml', '''
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="1" uniqueCount="1">
<si><t>${XmlText(sharedHeader)}</t></si></sst>''');
  }
  add('xl/worksheets/sheet1.xml', '''
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>$rows</sheetData></worksheet>''');
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Uint8List _day(String? header, {bool shared = false, String teacher = 'SYN'}) =>
    _workbook(
      'Sunday',
      '<row r="2">${_text('B2', 'Batch')}${_text('C2', 'Section')}'
          '${header == null ? '' : shared ? '<c r="D2" t="s"><v>0</v></c>' : _text('D2', header)}</row>'
          '<row r="3">${_text('B3', '66')}${_text('C3', 'B+C')}'
          '${_text('D3', 'CSE-1101 $teacher ROOM-1')}</row>',
      sharedHeader: shared ? header : null,
    );

Uint8List _tabular(String start, String end, {bool numeric = false}) {
  final headers = [
    'Day',
    'Batch',
    'Section',
    'Course Code',
    'Teacher',
    'Room',
    'Start',
    'End',
    'Semester',
  ];
  final values = ['Sunday', '66', 'B+C', 'CSE-1101', 'SYN', 'ROOM-1'];
  String cell(String ref, String value) =>
      numeric ? '<c r="$ref" s="1"><v>$value</v></c>' : _text(ref, value);
  return _workbook(
    'Assignments',
    '<row r="1">${[
      for (var i = 0; i < headers.length; i++)
        _text('${String.fromCharCode(65 + i)}1', headers[i])
    ].join()}</row>'
        '<row r="2">${[
      for (var i = 0; i < values.length; i++)
        _text('${String.fromCharCode(65 + i)}2', values[i])
    ].join()}'
        '${cell('G2', start)}${cell('H2', end)}${_text('I2', '3')}</row>',
  );
}

RoutineWorkbookParseResult _parse(Uint8List bytes,
        {List<Map<String, Object>> periods = const []}) =>
    RoutineWorkbookParser().parse(
      bytes: bytes,
      periods: periods,
      teacherNames: const {},
      subjectTitles: const {},
    );

void _interval(RoutineEntry row, String start, String end) {
  expect(row.timeStart, start);
  expect(row.timeEnd, end);
}

void main() {
  group('publication correctness', () {
    test(
        'explicit faculty name without an acronym is not mistaken for blank faculty',
        () {
      final bytes = _workbook(
          'Assignments',
          '<row r="1">${_text('A1', 'Day')}${_text('B1', 'Batch')}${_text('C1', 'Section')}${_text('D1', 'Course Code')}${_text('E1', 'Teacher Name')}${_text('F1', 'Room')}${_text('G1', 'Start')}${_text('H1', 'End')}</row>'
              '${[
            for (final r in [2, 3])
              '<row r="$r">${_text('A$r', 'Sunday')}${_text('B$r', '66')}${_text('C$r', r == 2 ? 'A' : 'B')}${_text('D$r', r == 2 ? 'CSE-1101' : 'CSE-1201')}${_text('E$r', 'Same Person')}${_text('F$r', 'ROOM-$r')}${_text('G$r', '09:00')}${_text('H$r', '10:00')}</row>'
          ].join()}');
      final result = _parse(bytes);
      expect(result.rows, hasLength(2));
      expect(result.rows.first.teacherCode, isNull,
          reason: 'No acronym may be invented');
      expect(result.validation['teacher_clashes'], 1);
      expect(result.validation['pending_faculty_assignments'], 0);
      expect(result.validation['ok'], false);
    });
    test('blank faculty retains the tabular assignment and marks it pending',
        () {
      final bytes = _workbook(
          'Assignments',
          '<row r="1">${_text('A1', 'Day')}${_text('B1', 'Batch')}${_text('C1', 'Section')}${_text('D1', 'Course Code')}${_text('E1', 'Teacher')}${_text('F1', 'Room')}${_text('G1', 'Start')}${_text('H1', 'End')}</row>'
              '<row r="2">${_text('A2', 'Sunday')}${_text('B2', 'Retake')}${_text('C2', 'A')}${_text('D2', 'CSE-1101')}${_text('F2', 'ROOM-1')}${_text('G2', '09:00')}${_text('H2', '10:00')}</row>');
      final result = _parse(bytes);
      expect(result.rows, hasLength(1));
      expect(result.rows.single.teacherCode, isNull);
      expect(result.rows.single.room, 'ROOM-1');
      expect(result.validation['pending_faculty_assignments'], 1);
      expect(result.validation['ok'], true);
    });
    Uint8List pair(String firstGroup, String secondGroup,
        {String secondStart = '09:30',
        String secondEnd = '10:30',
        String secondTeacher = 'SYN',
        String secondRoom = 'ROOM-1',
        String firstRoom = 'ROOM-1'}) {
      final headers = [
        'Day',
        'Batch',
        'Section',
        'Course Code',
        'Teacher',
        'Room',
        'Start',
        'End'
      ];
      final values = [
        [
          'Sunday',
          '66',
          firstGroup,
          'CSE-1101',
          'SYN',
          firstRoom,
          '09:00',
          '10:00'
        ],
        [
          'Sunday',
          '66',
          secondGroup,
          'CSE-1201',
          secondTeacher,
          secondRoom,
          secondStart,
          secondEnd
        ],
      ];
      return _workbook(
          'Assignments',
          '<row r="1">${[
            for (var i = 0; i < headers.length; i++)
              _text('${String.fromCharCode(65 + i)}1', headers[i])
          ].join()}</row>'
              '${[
            for (var r = 0; r < values.length; r++)
              '<row r="${r + 2}">${[
                for (var c = 0; c < values[r].length; c++)
                  _text('${String.fromCharCode(65 + c)}${r + 2}', values[r][c])
              ].join()}</row>'
          ].join()}');
    }

    test('reversed source clocks remain visible but cannot pass validation',
        () {
      final result = _parse(_day('11:10-12:15AM'));
      expect(result.rows, hasLength(1));
      expect(result.validation['invalid_time_slots'], 1);
      expect(result.validation['ok'], false);
    });
    test('rendered pending marker is not treated as a real teacher', () {
      final result = _parse(_day('09:00-10:00AM', teacher: 'FACULTY-PENDING'));
      expect(result.rows.single.teacherCode, isNull);
      expect(result.rows.single.teacherDisplay, 'Faculty pending');
      expect(result.validation['pending_faculty_assignments'], 1);
      expect(result.validation['ok'], true);
    });
    test('physical aliases collide while room purpose remains run scoped', () {
      final bytes = pair('A', 'B',
          firstRoom: 'RAB-106', secondRoom: 'phy lab', secondTeacher: 'OTHER');
      final current =
          RoutineWorkbookParser(roomAliases: {'PHY LAB': 'RAB-106'});
      final result = current.parse(
          bytes: bytes, periods: [], teacherNames: {}, subjectTitles: {});
      expect(result.validation['room_clashes'], 1);
      final facultyRoom = pair('A', 'B',
          firstRoom: 'RAB-104', secondRoom: 'ROOM-2', secondTeacher: 'OTHER');
      expect(_parse(facultyRoom).validation['ok'], true);
      final scoped = RoutineWorkbookParser(unavailableRooms: {'rab-104'}).parse(
          bytes: facultyRoom, periods: [], teacherNames: {}, subjectTitles: {});
      expect(scoped.validation['unavailable_room_assignments'], 1);
      expect(scoped.validation['ok'], false);
    });
    test('partial actual-time overlap detects teacher and room conflicts', () {
      final v = _parse(pair('A', 'B')).validation;
      expect(v['teacher_clashes'], 1);
      expect(v['room_clashes'], 1);
      expect(v['ok'], false);
    });
    test('source combined section conflicts with either participating section',
        () {
      final v =
          _parse(pair('B+C', 'C', secondTeacher: 'OTHER', secondRoom: 'ROOM-2'))
              .validation;
      expect(v['cohort_clashes'], 1);
      expect(v['ok'], false);
    });
    test('adjacent intervals share resources without overlapping', () {
      final v = _parse(pair('A', 'A', secondStart: '10:00', secondEnd: '11:00'))
          .validation;
      expect(v['ok'], true);
    });
  });
  group('source-preserving workbook clocks', () {
    test('attached PM across noon is read from a shared-string header', () {
      final row = _parse(_day('11:10-12:15PM', shared: true)).rows.single;
      _interval(row, '11:10:00', '12:15:00');
      expect(row.startLabel, '11:10 AM');
      expect(row.endLabel, '12:15 PM');
    });

    test('spaced PM across noon has the same intended interval', () {
      _interval(
          _parse(_day('11:10-12:15 PM')).rows.single, '11:10:00', '12:15:00');
    });

    test('explicit independent endpoint meridiems survive tabular import', () {
      _interval(_parse(_tabular('11:10 AM', '12:15 PM')).rows.single,
          '11:10:00', '12:15:00');
    });

    test('a shared evening PM suffix still qualifies both bare endpoints', () {
      _interval(
          _parse(_day('9:10-10:15PM')).rows.single, '21:10:00', '22:15:00');
    });

    test('a shared AM suffix preserves the hour after midnight', () {
      _interval(
          _parse(_day('12:10-1:15 AM')).rows.single, '00:10:00', '01:15:00');
    });

    test('parenthesized evening and midnight ranges retain shared meridiems',
        () {
      _interval(
          _parse(_day('(9:10-10:15 PM)')).rows.single, '21:10:00', '22:15:00');
      _interval(
          _parse(_day('(12:10-1:15 AM)')).rows.single, '00:10:00', '01:15:00');
    });

    test('fallback times are not reported as supplied seasonal configuration',
        () {
      expect(_parse(_day('11:10-12:15PM')).warnings, isEmpty);
    });

    test('dotted meridiems also handle noon without shifting the start', () {
      _interval(
          _parse(_day('11:10-12:15 p.m.')).rows.single, '11:10:00', '12:15:00');
    });

    test('numeric Excel endpoint is not reinterpreted using the other meridiem',
        () {
      _interval(_parse(_tabular('0.25', '7:00 AM')).rows.single, '06:00:00',
          '07:00:00');
    });

    test('explicit 24-hour endpoint is not reinterpreted by a shared suffix',
        () {
      _interval(_parse(_tabular('06:10:00', '7:15 AM')).rows.single, '06:10:00',
          '07:15:00');
    });

    test('explicit midnight is preserved without silently repairing the source',
        () {
      final row = _parse(_day('11:10-12:15AM')).rows.single;
      _interval(row, '11:10:00', '00:15:00');
      expect(row.endLabel, '12:15 AM');
      // Parsing is not institutional approval or same-day validity certification.
    });

    test('styled numeric Excel fractions retain noon and afternoon values', () {
      _interval(
          _parse(_tabular('0.5', '0.5520833333333334', numeric: true))
              .rows
              .single,
          '12:00:00',
          '13:15:00');
    });

    test('explicit afternoon 24-hour values are not shifted', () {
      _interval(_parse(_tabular('13:10:00', '14:25:00')).rows.single,
          '13:10:00', '14:25:00');
    });

    test('explicit early-morning 24-hour values are not shifted', () {
      _interval(_parse(_tabular('06:10:00', '07:15:00')).rows.single,
          '06:10:00', '07:15:00');
    });

    test(
        'import preserves source bytes, supplied teacher, group label and stage',
        () {
      final bytes = _tabular('11:10 AM', '12:15 PM');
      final original = Uint8List.fromList(bytes);
      final row = _parse(bytes).rows.single;
      expect(bytes, orderedEquals(original));
      expect(row.teacherCode, 'SYN');
      expect(row.section, 'B+C');
      expect(row.semester, 3);
      // Literal-label preservation is not proof of atomic-group query support.
    });
  });

  group('explicit synthetic timing revisions', () {
    const summer = [
      {'idx': 1, 'col': 'D', 'start': '08:30', 'end': '09:45'},
    ];
    const winter = [
      {'idx': 1, 'col': 'D', 'start': '09:00', 'end': '10:05'},
    ];

    test('same column follows the supplied grid when no header overrides it',
        () {
      final bytes = _day(null);
      _interval(
          _parse(bytes, periods: summer).rows.single, '08:30:00', '09:45:00');
      _interval(
          _parse(bytes, periods: winter).rows.single, '09:00:00', '10:05:00');
    });

    test('matching source header and explicit timing grid agree', () {
      final result = _parse(_day('09:00-10:05AM'), periods: winter);
      _interval(result.rows.single, '09:00:00', '10:05:00');
      expect(result.warnings, isEmpty);
    });

    test('a later grid does not mutate an earlier parsed row', () {
      final bytes = _day(null);
      final earlier = _parse(bytes, periods: summer).rows.single;
      final snapshot = Map<String, dynamic>.of(earlier.toMap());
      _parse(bytes, periods: winter);
      expect(earlier.toMap(), snapshot);
      _interval(RoutineEntry.fromMap({...snapshot, 'id': 'synthetic'}),
          '08:30:00', '09:45:00');
      // This covers detached parser output, not persistent policy versioning.
    });

    test(
        'conflicting source header and supplied grid produce a visible warning',
        () {
      final result = _parse(_day('08:30-09:45AM'), periods: winter);
      expect(result.warnings, isNotEmpty,
          reason:
              'A different season/config must not silently reinterpret input');
      _interval(result.rows.single, '08:30:00', '09:45:00');
      expect(result.warnings.single, contains('09:00:00-10:05:00'));
      expect(result.warnings.single, contains('workbook time retained'));
    });
  });
}
