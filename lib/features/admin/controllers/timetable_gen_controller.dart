// ============================================================
// FILE: lib/features/admin/controllers/timetable_gen_controller.dart
// PURPOSE: State between TimetableEngineService and the Generate
// Timetable screen. Kicks off a solve job, polls its status, holds
// the result for preview, and publishes it to `routines`.
// ChangeNotifier — the screen rebuilds via ListenableBuilder.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe_v1/features/admin/services/timetable_engine_service.dart';

enum GenPhase { idle, generating, polling, done, error }

class TimetableGenController extends ChangeNotifier {
  final TimetableEngineService _service = TimetableEngineService();

  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _maxPolls = 90; // ~3 min ceiling

  GenPhase _phase = GenPhase.idle;
  double _progress = 0;
  String? _errorMessage;
  TimetableResult? _result;

  bool _isPublishing = false;
  int? _publishedCount;
  String? _publishError;

  GenPhase get phase => _phase;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  TimetableResult? get result => _result;
  bool get isPublishing => _isPublishing;
  int? get publishedCount => _publishedCount;
  String? get publishError => _publishError;

  bool get isBusy => _phase == GenPhase.generating || _phase == GenPhase.polling;

  // ─── Generate + poll ──────────────────────────────────────
  Future<void> generate() async {
    _phase = GenPhase.generating;
    _progress = 0;
    _errorMessage = null;
    _result = null;
    _publishedCount = null;
    _publishError = null;
    notifyListeners();

    try {
      final jobId = await _service.generate();
      _phase = GenPhase.polling;
      notifyListeners();

      for (var i = 0; i < _maxPolls; i++) {
        final status = await _service.pollStatus(jobId);
        _progress = status.progress;
        notifyListeners();

        if (status.isFailed) {
          throw Exception(
              status.error ?? 'The solver could not build a timetable.');
        }
        if (status.isDone) {
          _result = await _service.fetchResult(jobId);
          _phase = GenPhase.done;
          _progress = 1;
          notifyListeners();
          return;
        }
        await Future.delayed(_pollInterval);
      }
      throw Exception('Timed out waiting for the timetable.');
    } catch (e) {
      _phase = GenPhase.error;
      _errorMessage = _clean(e);
      notifyListeners();
    }
  }

  // ─── Publish to routines ──────────────────────────────────
  Future<void> publish() async {
    final res = _result;
    if (res == null || res.rows.isEmpty) return;

    _isPublishing = true;
    _publishError = null;
    notifyListeners();

    try {
      _publishedCount = await _service.publishToRoutines(res.rows);
    } catch (e) {
      _publishError = _clean(e);
    }

    _isPublishing = false;
    notifyListeners();
  }

  void reset() {
    _phase = GenPhase.idle;
    _progress = 0;
    _errorMessage = null;
    _result = null;
    _publishedCount = null;
    _publishError = null;
    notifyListeners();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
}
