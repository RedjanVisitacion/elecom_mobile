import 'package:flutter/foundation.dart';

class ElectionWindowUtils {
  static const Duration manilaOffset = Duration(hours: 8);

  static final RegExp _timezoneSuffix = RegExp(
    r'(Z|z|[+-]\d{2}:?\d{2})$',
  );

  static Map<String, dynamic> normalizePayload(Map<String, dynamic> payload) {
    final raw = payload['election'] ?? payload['window'];
    final election = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return normalizeElection(election);
  }

  static Map<String, dynamic> normalizeElection(Map<String, dynamic> election) {
    final out = Map<String, dynamic>.from(election);
    out['start_at'] = _firstValue(out, const ['start_at', 'start_datetime']);
    out['end_at'] = _firstValue(out, const ['end_at', 'end_datetime']);
    out['results_at'] = _firstValue(
      out,
      const ['results_at', 'results_datetime'],
    );
    out['start_datetime'] = out['start_at'];
    out['end_datetime'] = out['end_at'];
    out['results_datetime'] = out['results_at'];
    return out;
  }

  static dynamic _firstValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return value;
    }
    return null;
  }

  /// Returns UTC. Backend datetimes without an offset are Asia/Manila values.
  static DateTime? parseServerDateTime(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;

    var normalized = s.replaceFirst(' ', 'T');
    if (!normalized.contains('T') &&
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
      normalized = '${normalized}T00:00:00';
    }
    if (!_timezoneSuffix.hasMatch(normalized)) {
      normalized = '$normalized+08:00';
    }
    return DateTime.tryParse(normalized)?.toUtc();
  }

  static DateTime get currentPhoneTimeUtc => DateTime.now().toUtc();

  static DateTime toManila(DateTime value) {
    return value.toUtc().add(manilaOffset);
  }

  static String _fmt(DateTime? value) {
    if (value == null) return 'null';
    final local = toManila(value);
    final iso = local.toIso8601String().replaceFirst(RegExp(r'Z$'), '');
    return '$iso+08:00';
  }

  static DateTime? startUtc(Map<String, dynamic> election) {
    return parseServerDateTime(
      election['start_at'] ?? election['start_datetime'],
    );
  }

  static DateTime? endUtc(Map<String, dynamic> election) {
    return parseServerDateTime(election['end_at'] ?? election['end_datetime']);
  }

  static DateTime? resultsUtc(Map<String, dynamic> election) {
    return parseServerDateTime(
      election['results_at'] ?? election['results_datetime'],
    );
  }

  static bool canVoteNow(Map<String, dynamic> election, {DateTime? nowUtc}) {
    final start = startUtc(election);
    final end = endUtc(election);
    final now = (nowUtc ?? currentPhoneTimeUtc).toUtc();
    if (start == null || end == null) return false;
    return !now.isBefore(start) && !now.isAfter(end);
  }

  static bool canViewResultsNow(
    Map<String, dynamic> election, {
    DateTime? nowUtc,
  }) {
    final results = resultsUtc(election);
    if (results == null) return false;
    final now = (nowUtc ?? currentPhoneTimeUtc).toUtc();
    return !now.isBefore(results);
  }

  static bool isResultsPublished(Map<String, dynamic> election) {
    final rs = (election['results_status'] ?? election['results_state'] ?? '')
        .toString()
        .toLowerCase();
    return rs == 'published';
  }

  static String computedStatus(Map<String, dynamic> election) {
    final start = startUtc(election);
    final end = endUtc(election);
    final now = currentPhoneTimeUtc;
    final backendStatus = (election['status'] ?? '').toString().toLowerCase();

    if (start != null && now.isBefore(start)) return 'upcoming';
    if (end != null && now.isAfter(end)) return 'closed';
    if (start != null && end != null) return 'active';
    if (backendStatus == 'active') return 'active';
    if (backendStatus == 'upcoming') return 'upcoming';
    return 'closed';
  }

  static bool isActiveNow(Map<String, dynamic> election) =>
      canVoteNow(election);

  static bool isUpcoming(Map<String, dynamic> election) =>
      computedStatus(election) == 'upcoming';

  static DateTime? countdownTargetUtc(Map<String, dynamic> election) {
    final status = computedStatus(election);
    final resultsStatus =
        (election['results_status'] ?? election['results_state'] ?? '')
            .toString()
            .toLowerCase();
    final start = startUtc(election);
    final end = endUtc(election);
    final results = resultsUtc(election);

    if (status == 'upcoming') return start;
    if (status == 'active') return end;
    if (status == 'closed' && resultsStatus == 'pending') return results;
    return null;
  }

  static void debugLog(
    Map<String, dynamic> election, {
    String source = 'election',
  }) {
    final start = startUtc(election);
    final end = endUtc(election);
    final results = resultsUtc(election);
    final now = currentPhoneTimeUtc;
    final status = computedStatus(election);
    final canVote = canVoteNow(election, nowUtc: now);
    final canViewResults = canViewResultsNow(election, nowUtc: now);
    debugPrint(
      'ELECOM $source: current phone time=${_fmt(now)} '
      'election start=${_fmt(start)} election end=${_fmt(end)} '
      'results time=${_fmt(results)} canVote=$canVote '
      'canViewResults=$canViewResults computed election status=$status',
    );
  }
}
