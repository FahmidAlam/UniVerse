// ============================================================
// FILE: lib/features/admin/services/routine_workbook_parser.dart
// PURPOSE: Parses routine workbooks into rows shaped for the `routines`
// table. Supports both UniVerse rendered day sheets and regular tabular
// spreadsheets with routine columns.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/clock_time.dart';
import 'package:xml/xml.dart';

class RoutineWorkbookParseResult {
  final List<RoutineEntry> rows;
  final List<String> warnings;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> validation;
  final String sourceFormat;

  const RoutineWorkbookParseResult({
    required this.rows,
    required this.warnings,
    required this.stats,
    required this.validation,
    required this.sourceFormat,
  });

  bool get hasWarnings => warnings.isNotEmpty;
}

class RoutineWorkbookParser {
  static const int _firstDataRow = 3;
  static const Set<String> _fallbackSessionCols = {
    'D',
    'E',
    'F',
    'H',
    'I',
    'J',
    'K',
  };

  RoutineWorkbookParseResult parse({
    required Uint8List bytes,
    required List<dynamic> periods,
    required Map<String, String> teacherNames,
    required Map<String, String> subjectTitles,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final sharedStrings = _readSharedStrings(archive);
    final sheetPaths = _readSheetPaths(archive);
    final periodByCol = _periodsByColumn(periods);
    final rawRows = <_RawRoutineCell>[];
    final daySheetWarnings = <String>[];

    for (final sheet in _daySheetPaths(sheetPaths).entries) {
      final day = sheet.key;
      final path = sheet.value;
      final file = _findFile(archive, path);
      if (file == null) {
        daySheetWarnings.add('Worksheet file for "$day" was missing.');
        continue;
      }
      rawRows.addAll(
        _parseDaySheet(
          day: day,
          xmlText: _decode(file),
          sharedStrings: sharedStrings,
          periodByCol: periodByCol,
          warnings: daySheetWarnings,
        ),
      );
    }

    if (rawRows.isEmpty) {
      final tabularWarnings = <String>[];
      final tabular = _parseTabularSheets(
        archive: archive,
        sheetPaths: sheetPaths,
        sharedStrings: sharedStrings,
        teacherNames: teacherNames,
        subjectTitles: subjectTitles,
        warnings: tabularWarnings,
      );
      if (tabular.rows.isNotEmpty) return tabular;
      throw Exception(
        'No routine rows were found. Use columns like Day, Time/Start/End, '
        'Course Code, Teacher, Room, Batch, Section, and Semester.',
      );
    }

    return _finish(
      rawRows: rawRows,
      warnings: daySheetWarnings,
      teacherNames: teacherNames,
      subjectTitles: subjectTitles,
      sourceFormat: 'UniVerse day sheets',
    );
  }

  List<String> _readSharedStrings(Archive archive) {
    final file = _findFile(archive, 'xl/sharedStrings.xml');
    if (file == null) return const [];
    final doc = XmlDocument.parse(_decode(file));
    return doc.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'si')
        .map(
          (si) => si.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 't')
              .map((t) => t.innerText)
              .join(),
        )
        .toList();
  }

  Map<String, String> _readSheetPaths(Archive archive) {
    final workbook = _findFile(archive, 'xl/workbook.xml');
    final rels = _findFile(archive, 'xl/_rels/workbook.xml.rels');
    if (workbook == null || rels == null) return const {};

    final relDoc = XmlDocument.parse(_decode(rels));
    final relById = <String, String>{};
    for (final rel in relDoc.descendants.whereType<XmlElement>()) {
      if (rel.name.local != 'Relationship') continue;
      final id = _attr(rel, 'Id');
      final target = _attr(rel, 'Target');
      if (id == null || target == null) continue;
      relById[id] = _normalSheetPath(target);
    }

    final workbookDoc = XmlDocument.parse(_decode(workbook));
    final out = <String, String>{};
    for (final sheet in workbookDoc.descendants.whereType<XmlElement>()) {
      if (sheet.name.local != 'sheet') continue;
      final name = _attr(sheet, 'name');
      final relId = _attr(sheet, 'id');
      final path = relId == null ? null : relById[relId];
      if (name != null && path != null) out[name.trim()] = path;
    }
    return out;
  }

  Map<String, _PeriodSlot> _periodsByColumn(List<dynamic> periods) {
    final out = <String, _PeriodSlot>{};
    for (final raw in periods) {
      if (raw is! Map) continue;
      final col = raw['col']?.toString().trim().toUpperCase();
      final start = raw['start']?.toString();
      final end = raw['end']?.toString();
      if (col == null || col.isEmpty || start == null || end == null) {
        continue;
      }
      out[col] = _PeriodSlot(_dbTime(start), _dbTime(end));
    }
    if (out.isNotEmpty) return _repairSlotOrder(out);
    return {
      'D': const _PeriodSlot('08:50:00', '10:05:00'),
      'E': const _PeriodSlot('10:05:00', '11:20:00'),
      'F': const _PeriodSlot('11:20:00', '12:35:00'),
      'H': const _PeriodSlot('13:10:00', '14:25:00'),
      'I': const _PeriodSlot('14:25:00', '15:40:00'),
      'J': const _PeriodSlot('15:40:00', '16:55:00'),
      'K': const _PeriodSlot('19:00:00', '20:20:00'),
    };
  }

  /// Second AM/PM safety net over the whole period table: read the slots in
  /// column order (period 1 first) and make the day move forward. A slot that
  /// starts before the one preceding it lost its PM marker upstream — a
  /// single value can look fine on its own and still be wrong in sequence.
  Map<String, _PeriodSlot> _repairSlotOrder(Map<String, _PeriodSlot> slots) {
    final cols = slots.keys.toList()..sort(_compareColumns);
    final repaired = ClockTime.repairSequence([
      for (final col in cols) (start: slots[col]!.start, end: slots[col]!.end),
    ]);

    return {
      for (var i = 0; i < cols.length; i++)
        cols[i]: _PeriodSlot(repaired[i].start, repaired[i].end),
    };
  }

  Map<String, String> _daySheetPaths(Map<String, String> sheetPaths) {
    final out = <String, String>{};
    final usedPaths = <String>{};

    for (final day in AppConstants.weekDays) {
      final exact = sheetPaths[day];
      if (exact != null) {
        out[day] = exact;
        usedPaths.add(exact);
      }
    }

    for (final sheet in sheetPaths.entries) {
      if (usedPaths.contains(sheet.value)) continue;
      final day = _dayFromText(sheet.key);
      if (day == null || out.containsKey(day)) continue;
      out[day] = sheet.value;
      usedPaths.add(sheet.value);
    }

    return out;
  }

  List<_RawRoutineCell> _parseDaySheet({
    required String day,
    required String xmlText,
    required List<String> sharedStrings,
    required Map<String, _PeriodSlot> periodByCol,
    required List<String> warnings,
  }) {
    final values = _readGrid(xmlText, sharedStrings);
    if (values.isEmpty) return const [];
    final cohortCols = _cohortColumnsForDaySheet(values);
    final slotsByCol = _daySheetSlots(
      grid: values,
      periodByCol: periodByCol,
      cohortCols: cohortCols,
    );

    final rows = <_RawRoutineCell>[];
    final dataRows = values.keys.where((r) => r >= _firstDataRow).toList()
      ..sort();
    for (final rowNumber in dataRows) {
      final cells = values[rowNumber]!;
      final batch = _cleanBatch(cells[cohortCols.batchCol]);
      final section = _cleanSection(cells[cohortCols.sectionCol]);
      if (batch.isEmpty || section.isEmpty || _isCohortHeader(batch, section)) {
        continue;
      }

      for (final entry in slotsByCol.entries) {
        final col = entry.key;
        final slot = entry.value;
        final value = _cleanText(cells[col]);
        if (value.isEmpty) continue;

        final parsedCells = _parseSessionCells(value);
        if (parsedCells.isEmpty) {
          warnings.add('$day row $rowNumber column $col could not be read.');
          continue;
        }

        for (final parsed in parsedCells) {
          rows.add(
            _RawRoutineCell(
              day: day,
              batch: batch,
              section: section,
              timeStart: slot.start,
              timeEnd: slot.end,
              subjectCode: parsed.subjectCode,
              teacherCode: parsed.teacherCode,
              room: parsed.room,
            ),
          );
        }
      }
    }

    return rows;
  }

  _CohortColumns _cohortColumnsForDaySheet(
    Map<int, Map<String, String>> grid,
  ) {
    final rows = grid.keys.toList()..sort();
    for (final rowNo in rows.take(16)) {
      String? batchCol;
      String? sectionCol;
      for (final cell in grid[rowNo]!.entries) {
        final field = _fieldForHeader(cell.value);
        if (field == _TabularField.batch) batchCol = cell.key;
        if (field == _TabularField.section) sectionCol = cell.key;
      }
      if (batchCol != null && sectionCol != null) {
        return _CohortColumns(batchCol: batchCol, sectionCol: sectionCol);
      }
    }
    return const _CohortColumns(batchCol: 'B', sectionCol: 'C');
  }

  Map<String, _PeriodSlot> _daySheetSlots({
    required Map<int, Map<String, String>> grid,
    required Map<String, _PeriodSlot> periodByCol,
    required _CohortColumns cohortCols,
  }) {
    final slots = <String, _PeriodSlot>{...periodByCol};
    final rows = grid.keys.toList()..sort();

    for (final rowNo in rows.take(16)) {
      for (final cell in grid[rowNo]!.entries) {
        if (cell.key == cohortCols.batchCol ||
            cell.key == cohortCols.sectionCol) {
          continue;
        }
        final slot = _timeRange(combined: cell.value, start: '', end: '');
        if (slot != null) slots[cell.key] = slot;
      }
    }

    final routineCols = <String>{};
    for (final rowNo in rows.where((r) => r >= _firstDataRow)) {
      final cells = grid[rowNo]!;
      if (_cleanBatch(cells[cohortCols.batchCol]).isEmpty) continue;
      for (final cell in cells.entries) {
        if (cell.key == cohortCols.batchCol ||
            cell.key == cohortCols.sectionCol ||
            slots.containsKey(cell.key)) {
          continue;
        }
        if (_parseSessionCells(cell.value).isNotEmpty) {
          routineCols.add(cell.key);
        }
      }
    }

    final missing = routineCols.toList()..sort(_compareColumns);
    final fallbackSlots = _fallbackSlotsInOrder();
    var fallbackIndex = 0;
    for (final col in missing) {
      if (fallbackIndex >= fallbackSlots.length) break;
      slots[col] = fallbackSlots[fallbackIndex];
      fallbackIndex++;
    }

    return Map.fromEntries(
      slots.entries.toList()..sort((a, b) => _compareColumns(a.key, b.key)),
    );
  }

  RoutineWorkbookParseResult _parseTabularSheets({
    required Archive archive,
    required Map<String, String> sheetPaths,
    required List<String> sharedStrings,
    required Map<String, String> teacherNames,
    required Map<String, String> subjectTitles,
    required List<String> warnings,
  }) {
    final rawRows = <_RawRoutineCell>[];

    for (final sheet in sheetPaths.entries) {
      final file = _findFile(archive, sheet.value);
      if (file == null) continue;
      final grid = _readGrid(_decode(file), sharedStrings);
      if (grid.isEmpty) continue;
      final inferredDay = _dayFromText(sheet.key);
      final header = _findHeader(grid, inferredDay: inferredDay);
      if (header == null) continue;

      for (final rowNo in grid.keys.where((r) => r > header.row).toList()
        ..sort()) {
        final cells = grid[rowNo]!;
        if (cells.values.every((v) => _cleanText(v).isEmpty)) continue;

        final parsed = _parseTabularRow(
          cells: cells,
          header: header,
          rowNo: rowNo,
          inferredDay: inferredDay,
          warnings: warnings,
        );
        if (parsed != null) rawRows.add(parsed);
      }
    }

    if (rawRows.isEmpty) {
      return RoutineWorkbookParseResult(
        rows: const [],
        warnings: warnings,
        stats: const {'meetings': 0, 'cohorts': 0, 'teachers': 0, 'days': 0},
        validation: const {
          'teacher_clashes': 0,
          'cohort_clashes': 0,
          'room_clashes': 0,
          'ok': false,
        },
        sourceFormat: 'Tabular workbook',
      );
    }

    return _finish(
      rawRows: rawRows,
      warnings: warnings,
      teacherNames: teacherNames,
      subjectTitles: subjectTitles,
      sourceFormat: 'Tabular workbook',
    );
  }

  Map<int, Map<String, String>> _readGrid(
    String xmlText,
    List<String> sharedStrings,
  ) {
    final doc = XmlDocument.parse(xmlText);
    final grid = <int, Map<String, String>>{};
    for (final cell in doc.descendants.whereType<XmlElement>()) {
      if (cell.name.local != 'c') continue;
      final ref = _attr(cell, 'r');
      if (ref == null) continue;
      final row = _rowOf(ref);
      if (row == null) continue;
      final text = _cellText(cell, sharedStrings).trim();
      if (text.isEmpty) continue;
      grid.putIfAbsent(row, () => <String, String>{})[_colOf(ref)] = text;
    }
    return grid;
  }

  _TabularHeader? _findHeader(
    Map<int, Map<String, String>> grid, {
    required String? inferredDay,
  }) {
    final rows = grid.keys.toList()..sort();
    for (final rowNo in rows.take(40)) {
      final cols = <String, _TabularField>{};
      for (final cell in grid[rowNo]!.entries) {
        final field = _fieldForHeader(cell.value);
        if (field != null) cols[cell.key] = field;
      }
      final fields = cols.values.toSet();
      final hasDay = fields.contains(_TabularField.day) || inferredDay != null;
      final hasTime = fields.contains(_TabularField.time) ||
          (fields.contains(_TabularField.startTime) &&
              fields.contains(_TabularField.endTime));
      final hasClass = fields.contains(_TabularField.subjectCode) ||
          fields.contains(_TabularField.subject);
      final hasTeacher = fields.contains(_TabularField.teacherCode) ||
          fields.contains(_TabularField.teacherName);
      final hasCohort = fields.contains(_TabularField.batch) &&
          fields.contains(_TabularField.section);
      if (hasDay && hasTime && hasClass && hasTeacher && hasCohort) {
        return _TabularHeader(row: rowNo, columns: cols);
      }
    }
    return null;
  }

  _RawRoutineCell? _parseTabularRow({
    required Map<String, String> cells,
    required _TabularHeader header,
    required int rowNo,
    required String? inferredDay,
    required List<String> warnings,
  }) {
    String cell(_TabularField field) {
      for (final entry in header.columns.entries) {
        if (entry.value == field) return _cleanText(cells[entry.key]);
      }
      return '';
    }

    final day = _dayFromText(cell(_TabularField.day)) ?? inferredDay;
    final batch = _cleanBatch(cell(_TabularField.batch));
    final section = _cleanSection(cell(_TabularField.section));
    final subject = cell(_TabularField.subject);
    final code = _normalizeCourseCode(cell(_TabularField.subjectCode));
    final teacherCode = _teacherAcronym(
      cell(_TabularField.teacherCode),
      cell(_TabularField.teacherName),
    );
    final room = cell(_TabularField.room);
    final timeRange = _timeRange(
      combined: cell(_TabularField.time),
      start: cell(_TabularField.startTime),
      end: cell(_TabularField.endTime),
    );

    if (day == null ||
        batch.isEmpty ||
        section.isEmpty ||
        teacherCode.isEmpty ||
        room.isEmpty ||
        timeRange == null ||
        (code.isEmpty && subject.isEmpty)) {
      final hasAnyRoutineData = [
        day,
        batch,
        section,
        subject,
        code,
        teacherCode,
        room,
      ].any((v) => (v ?? '').isNotEmpty);
      if (hasAnyRoutineData) {
        warnings.add(
            'Tabular row $rowNo was skipped because required data is missing.');
      }
      return null;
    }

    return _RawRoutineCell(
      day: day,
      batch: batch,
      section: section,
      timeStart: timeRange.start,
      timeEnd: timeRange.end,
      subjectCode: code.isEmpty ? subject.toUpperCase() : code,
      subject: subject.isEmpty ? null : subject,
      teacherCode: teacherCode,
      room: room,
      semester: int.tryParse(cell(_TabularField.semester)),
      teacherName: cell(_TabularField.teacherName).isEmpty
          ? null
          : cell(_TabularField.teacherName),
    );
  }

  RoutineWorkbookParseResult _finish({
    required List<_RawRoutineCell> rawRows,
    required List<String> warnings,
    required Map<String, String> teacherNames,
    required Map<String, String> subjectTitles,
    required String sourceFormat,
  }) {
    final maxBatch = rawRows
        .map((r) => int.tryParse(r.batch))
        .whereType<int>()
        .fold<int?>(null, (max, v) => max == null || v > max ? v : max);

    final rows = <RoutineEntry>[
      for (var i = 0; i < rawRows.length; i++)
        RoutineEntry(
          id: 'upload-$i',
          day: rawRows[i].day,
          timeStart: rawRows[i].timeStart,
          timeEnd: rawRows[i].timeEnd,
          subject: rawRows[i].subject ??
              subjectTitles[rawRows[i].subjectCode] ??
              rawRows[i].subjectCode,
          subjectCode: rawRows[i].subjectCode,
          teacherName:
              rawRows[i].teacherName ?? teacherNames[rawRows[i].teacherCode],
          teacherCode: rawRows[i].teacherCode,
          room: rawRows[i].room,
          batch: rawRows[i].batch,
          section: rawRows[i].section,
          semester:
              rawRows[i].semester ?? _semesterFor(rawRows[i].batch, maxBatch),
          isActive: true,
        ),
    ];

    final validation = _validate(rows);
    final cohorts = rows.map((r) => '${r.batch}-${r.section}').toSet();
    final teachers = rows
        .map((r) => r.teacherCode)
        .where((v) => v != null && v.isNotEmpty)
        .toSet();
    final days = rows.map((r) => r.day).toSet();

    return RoutineWorkbookParseResult(
      rows: rows,
      warnings: warnings,
      stats: {
        'meetings': rows.length,
        'cohorts': cohorts.length,
        'teachers': teachers.length,
        'days': days.length,
      },
      validation: validation,
      sourceFormat: sourceFormat,
    );
  }

  _ParsedCell? _parseSessionText(String input) {
    final parts = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.length < 3) return null;
    final code = parts[0].trim().toUpperCase();
    final teacher = parts[1].trim().toUpperCase();
    final room = parts.sublist(2).join(' ').trim();
    if (!RegExp(r'^[A-Z]{2,5}[- ]?\d{3,4}[A-Z]?$').hasMatch(code)) {
      return null;
    }
    if (teacher.isEmpty || room.isEmpty) return null;
    return _ParsedCell(
      subjectCode: code.replaceFirst(' ', '-'),
      teacherCode: teacher,
      room: room,
    );
  }

  List<_ParsedCell> _parseSessionCells(String input) {
    final rows = <_ParsedCell>[];
    for (final line in input.split(RegExp(r'[\r\n;]+'))) {
      final parsed = _parseSessionText(line);
      if (parsed != null) rows.add(parsed);
    }
    if (rows.length > 1) return rows;

    final wholeCell =
        _parseSessionText(input.replaceAll(RegExp(r'[\r\n]+'), ' '));
    if (wholeCell != null) return [wholeCell];
    return rows;
  }

  List<_PeriodSlot> _fallbackSlotsInOrder() => _fallbackSessionCols
      .map((col) => _periodsByColumn(const [])[col]!)
      .toList();

  int _compareColumns(String a, String b) => _columnIndex(a) - _columnIndex(b);

  int _columnIndex(String col) {
    var value = 0;
    for (final unit in col.toUpperCase().codeUnits) {
      if (unit < 65 || unit > 90) continue;
      value = value * 26 + (unit - 64);
    }
    return value;
  }

  _TabularField? _fieldForHeader(String input) {
    final h = _headerKey(input);
    if (h.isEmpty) return null;
    if (_matches(h, ['day', 'weekday', 'week day', 'class day'])) {
      return _TabularField.day;
    }
    if (_matches(h, [
      'time',
      'time slot',
      'slot',
      'class time',
      'period',
      'schedule',
    ])) {
      return _TabularField.time;
    }
    if (_matches(h, ['start', 'start time', 'time start', 'from'])) {
      return _TabularField.startTime;
    }
    if (_matches(h, ['end', 'end time', 'time end', 'to'])) {
      return _TabularField.endTime;
    }
    if (_matches(h, [
      'subject',
      'course',
      'course title',
      'subject title',
      'title',
      'course name',
    ])) {
      return _TabularField.subject;
    }
    if (_matches(h, [
      'code',
      'course code',
      'subject code',
      'course no',
      'course number',
    ])) {
      return _TabularField.subjectCode;
    }
    if (_matches(h, [
      'teacher',
      'teacher code',
      'faculty',
      'faculty code',
      'acronym',
      'teacher acronym',
    ])) {
      return _TabularField.teacherCode;
    }
    if (_matches(h, [
      'teacher name',
      'faculty name',
      'instructor',
      'instructor name',
    ])) {
      return _TabularField.teacherName;
    }
    if (_matches(
        h, ['room', 'class room', 'room no', 'room number', 'venue'])) {
      return _TabularField.room;
    }
    if (_matches(h, ['batch', 'batch no', 'batch number'])) {
      return _TabularField.batch;
    }
    if (_matches(h, ['section', 'sec'])) return _TabularField.section;
    if (_matches(h, ['semester', 'sem'])) return _TabularField.semester;
    return null;
  }

  bool _matches(String header, List<String> aliases) {
    return aliases.any((a) => header == _headerKey(a));
  }

  String _headerKey(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-./()]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String? _dayFromText(String input) {
    final text = input.toLowerCase();
    for (final day in AppConstants.weekDays) {
      if (text == day.toLowerCase() ||
          text.startsWith(day.toLowerCase()) ||
          text.contains(day.toLowerCase())) {
        return day;
      }
    }
    for (var i = 0; i < AppConstants.weekDaysShort.length; i++) {
      final short = AppConstants.weekDaysShort[i].toLowerCase();
      if (text == short || text.startsWith(short)) {
        return AppConstants.weekDays[i];
      }
    }
    return null;
  }

  _PeriodSlot? _timeRange({
    required String combined,
    required String start,
    required String end,
  }) {
    var startText = start;
    var endText = end;
    final startMeridiem = _meridiemOf(startText);
    final endMeridiem = _meridiemOf(endText);
    if (startMeridiem == null && endMeridiem != null) {
      startText = '$startText $endMeridiem';
    } else if (endMeridiem == null && startMeridiem != null) {
      endText = '$endText $startMeridiem';
    }

    final parsedStart = _parseTimeValue(startText);
    final parsedEnd = _parseTimeValue(endText);
    if (parsedStart != null && parsedEnd != null) {
      return _PeriodSlot(parsedStart, parsedEnd);
    }

    final normalized = combined
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('to', '-');
    final parts = normalized.split(RegExp(r'\s*-\s*'));
    if (parts.length >= 2) {
      var startPart = parts[0];
      var endPart = parts[1];
      final startMeridiem = _meridiemOf(startPart);
      final endMeridiem = _meridiemOf(endPart);
      if (startMeridiem == null && endMeridiem != null) {
        startPart = '$startPart $endMeridiem';
      } else if (endMeridiem == null && startMeridiem != null) {
        endPart = '$endPart $startMeridiem';
      }

      final a = _parseTimeValue(startPart);
      final b = _parseTimeValue(endPart);
      if (a != null && b != null) return _PeriodSlot(a, b);
    }
    return null;
  }

  String? _meridiemOf(String input) =>
      RegExp(r'\b(am|pm)\b', caseSensitive: false)
          .firstMatch(input)
          ?.group(1)
          ?.toLowerCase();

  /// Reads a single clock value out of workbook text. Shares `ClockTime` with
  /// the settings path so a bare "1:50" means the same afternoon everywhere.
  String? _parseTimeValue(String input) => ClockTime.normalize(_cleanText(input));

  String _normalizeCourseCode(String input) {
    final text = _cleanText(input).toUpperCase();
    final match = RegExp(r'[A-Z]{2,5}[- ]?\d{3,4}[A-Z]?').firstMatch(text);
    return match == null ? text : match.group(0)!.replaceFirst(' ', '-');
  }

  String _teacherAcronym(String code, String name) {
    final cleanedCode = _cleanText(code).toUpperCase();
    if (cleanedCode.isNotEmpty) return cleanedCode;
    final words = _cleanText(name)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    if (words.length == 1) return words.first.toUpperCase();
    return words.take(4).map((w) => w[0].toUpperCase()).join();
  }

  Map<String, dynamic> _validate(List<RoutineEntry> rows) {
    final teacher = <String, int>{};
    final cohort = <String, int>{};
    final room = <String, int>{};

    for (final r in rows) {
      final slot = '${r.day}|${r.timeStart}';
      final teacherCode = r.teacherCode;
      if (teacherCode != null && teacherCode.isNotEmpty) {
        teacher.update('$teacherCode|$slot', (v) => v + 1, ifAbsent: () => 1);
      }
      cohort.update(
        '${r.batch}|${r.section}|$slot',
        (v) => v + 1,
        ifAbsent: () => 1,
      );
      if (r.room.toUpperCase() != 'TBA') {
        room.update('${r.room}|$slot', (v) => v + 1, ifAbsent: () => 1);
      }
    }

    int clashes(Map<String, int> m) =>
        m.values.where((v) => v > 1).fold(0, (sum, v) => sum + v - 1);

    final teacherClashes = clashes(teacher);
    final cohortClashes = clashes(cohort);
    final roomClashes = clashes(room);

    return {
      'teacher_clashes': teacherClashes,
      'cohort_clashes': cohortClashes,
      'room_clashes': roomClashes,
      'ok': teacherClashes == 0 && cohortClashes == 0 && roomClashes == 0,
    };
  }

  ArchiveFile? _findFile(Archive archive, String path) {
    final normalized = path.replaceAll('\\', '/');
    for (final file in archive.files) {
      if (file.name.replaceAll('\\', '/') == normalized) return file;
    }
    return null;
  }

  String _decode(ArchiveFile file) =>
      utf8.decode(file.readBytes() ?? Uint8List(0));

  String? _attr(XmlElement e, String localName) {
    for (final attr in e.attributes) {
      if (attr.name.local == localName) return attr.value;
    }
    return null;
  }

  String _cellText(XmlElement cell, List<String> sharedStrings) {
    final type = _attr(cell, 't');
    if (type == 'inlineStr') {
      return cell.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 't')
          .map((e) => e.innerText)
          .join();
    }

    final value = cell.children
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'v')
        .map((e) => e.innerText)
        .cast<String?>()
        .firstWhere((v) => v != null, orElse: () => null);

    if (value == null) return '';
    if (type == 's') {
      final index = int.tryParse(value);
      if (index == null || index < 0 || index >= sharedStrings.length) {
        return '';
      }
      return sharedStrings[index];
    }
    return value;
  }

  String _normalSheetPath(String target) {
    final clean = target.replaceAll('\\', '/');
    if (clean.startsWith('/')) return clean.substring(1);
    if (clean.startsWith('xl/')) return clean;
    return 'xl/$clean';
  }

  String _colOf(String ref) => ref.replaceAll(RegExp(r'\d'), '').toUpperCase();

  int? _rowOf(String ref) =>
      int.tryParse(ref.replaceAll(RegExp(r'[A-Za-z]'), ''));

  String _cleanBatch(String? v) {
    final text = _cleanText(v);
    if (text.endsWith('.0')) return text.substring(0, text.length - 2);
    final asNum = num.tryParse(text);
    if (asNum != null && asNum == asNum.roundToDouble()) {
      return asNum.toInt().toString();
    }
    final labeled = RegExp(
      r'\bbatch\s*[:#-]?\s*(\d+)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (labeled != null) return labeled.group(1)!;
    return text;
  }

  String _cleanSection(String? v) {
    final text = _cleanText(v).toUpperCase();
    final labeled = RegExp(
      r'\b(?:section|sec)\s*[:#-]?\s*([A-Z0-9]+)\b',
      caseSensitive: false,
    ).firstMatch(text);
    return labeled?.group(1) ?? text;
  }

  bool _isCohortHeader(String batch, String section) =>
      _fieldForHeader(batch) == _TabularField.batch ||
      _fieldForHeader(section) == _TabularField.section;

  String _cleanText(String? v) =>
      (v ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Canonical 24-hour literal for a period boundary out of settings.
  /// See `ClockTime` — a bare "1:50" here used to reach Postgres as
  /// 01:50 (1:50 AM) and put afternoon classes in the middle of the night.
  String _dbTime(String value) => ClockTime.normalizeOr(value);

  int _semesterFor(String batch, int? maxBatch) {
    final n = int.tryParse(batch);
    if (n == null || maxBatch == null) return 1;
    return (maxBatch - n + 1).clamp(1, 8);
  }
}

class _PeriodSlot {
  final String start;
  final String end;

  const _PeriodSlot(this.start, this.end);
}

class _CohortColumns {
  final String batchCol;
  final String sectionCol;

  const _CohortColumns({required this.batchCol, required this.sectionCol});
}

class _ParsedCell {
  final String subjectCode;
  final String teacherCode;
  final String room;

  const _ParsedCell({
    required this.subjectCode,
    required this.teacherCode,
    required this.room,
  });
}

class _RawRoutineCell {
  final String day;
  final String batch;
  final String section;
  final String timeStart;
  final String timeEnd;
  final String? subject;
  final String subjectCode;
  final String? teacherName;
  final String teacherCode;
  final String room;
  final int? semester;

  const _RawRoutineCell({
    required this.day,
    required this.batch,
    required this.section,
    required this.timeStart,
    required this.timeEnd,
    this.subject,
    required this.subjectCode,
    this.teacherName,
    required this.teacherCode,
    required this.room,
    this.semester,
  });
}

class _TabularHeader {
  final int row;
  final Map<String, _TabularField> columns;

  const _TabularHeader({required this.row, required this.columns});
}

enum _TabularField {
  day,
  time,
  startTime,
  endTime,
  subject,
  subjectCode,
  teacherCode,
  teacherName,
  room,
  batch,
  section,
  semester,
}
