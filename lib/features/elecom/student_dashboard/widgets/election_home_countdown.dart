import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/notifications/local_push_service.dart';
import '../../../../core/notifications/notification_center_store.dart';
import '../../../../core/session/user_session.dart';
import '../../data/elecom_mobile_api.dart';

/// Home-tab election countdown fed by [GET /api/mobile/election/window/] (same schedule as the web).
class ElectionHomeCountdown extends StatefulWidget {
  const ElectionHomeCountdown({
    super.key,
    required this.orgName,
    this.embeddedInProfileCard = false,
    this.onVoteNow,
    this.onViewResults,
  });

  final String orgName;

  /// When true, spacing is tightened for use directly under the profile row.
  final bool embeddedInProfileCard;

  /// Opens voting (e.g. switch bottom nav to Election).
  final VoidCallback? onVoteNow;
  final VoidCallback? onViewResults;

  @override
  State<ElectionHomeCountdown> createState() => _ElectionHomeCountdownState();
}

class _ElectionHomeCountdownState extends State<ElectionHomeCountdown> {
  final ElecomMobileApi _api = ElecomMobileApi();
  Map<String, dynamic> _election = const <String, dynamic>{};
  String? _loadError;
  Timer? _secondTicker;
  Timer? _pollTicker;

  @override
  void initState() {
    super.initState();
    _refreshFromServer();
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
    _pollTicker = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshFromServer(),
    );
  }

  @override
  void dispose() {
    _secondTicker?.cancel();
    _pollTicker?.cancel();
    super.dispose();
  }

  DateTime? _parseIso(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  DateTime? _countdownTarget(Map<String, dynamic> e) {
    final status = (e['status'] ?? '').toString();
    final rs = (e['results_status'] ?? e['results_state'] ?? '')
        .toString()
        .toLowerCase();
    final start = _parseIso(e['start_at']?.toString());
    final end = _parseIso(e['end_at']?.toString());
    final results = _parseIso(e['results_at']?.toString());
    if (status == 'Upcoming' && start != null) return start.toLocal();
    if (status == 'Active' && end != null) return end.toLocal();
    if (status == 'Closed' && rs == 'pending' && results != null)
      return results.toLocal();
    return null;
  }

  String _statusLine(Map<String, dynamic> e, Duration? remaining) {
    final status = (e['status'] ?? '').toString();
    final rs = (e['results_status'] ?? e['results_state'] ?? '')
        .toString()
        .toLowerCase();
    final days = remaining?.inDays ?? 0;
    if (status == 'Active') {
      return 'You have ${days.clamp(0, 9999)} days left to vote. Don\'t miss your chance!';
    }
    if (status == 'Upcoming') {
      return 'Voting has not started yet. Get ready before the window opens.';
    }
    if (status == 'Closed' && rs == 'pending') {
      return 'Voting is closed. Results will be published soon.';
    }
    if (status == 'Closed' && rs == 'published') {
      return 'Results are published. Open the Results tab for details.';
    }
    return 'Election schedule will appear here when it is configured.';
  }

  bool _isActive(Map<String, dynamic> e) {
    return (e['status'] ?? '').toString() == 'Active';
  }

  bool _isResultsPublished(Map<String, dynamic> e) {
    final status = (e['status'] ?? '').toString();
    final rs = (e['results_status'] ?? e['results_state'] ?? '')
        .toString()
        .toLowerCase();
    return status == 'Closed' && rs == 'published';
  }

  bool _isClosedWithoutPublishedResults(Map<String, dynamic> e) {
    final status = (e['status'] ?? '').toString();
    final rs = (e['results_status'] ?? e['results_state'] ?? '')
        .toString()
        .toLowerCase();
    return status == 'Closed' && rs != 'published';
  }

  Future<void> _maybeReactToPhaseChange(Map<String, dynamic> e) async {
    final sid = (UserSession.studentId ?? '').trim();
    final suffix = sid.isEmpty ? 'anon' : sid;
    final w = '${e['window_id'] ?? ''}';
    final st = '${e['status'] ?? ''}';
    final rs = ((e['results_status'] ?? e['results_state']) ?? '')
        .toString()
        .toLowerCase();
    final phaseKey = '$w|$st|$rs';
    final sched = (e['schedule_sig'] ?? '').toString();

    final prefs = await SharedPreferences.getInstance();
    final phasePref = 'elecom_election_phase_v2_$suffix';
    final schedPref = 'elecom_election_sched_v2_$suffix';

    final prevPhase = prefs.getString(phasePref);
    final prevSched = prefs.getString(schedPref);

    var refreshed = false;
    Future<void> ensureRefresh() async {
      if (!refreshed) {
        refreshed = true;
        await NotificationCenterStore.refresh();
      }
    }

    // Backend `schedule_sig` changes when vote_windows row or start/end/results times change.
    if (prevSched != null && sched.isNotEmpty && prevSched != sched) {
      await ensureRefresh();
      await LocalPushService.show(
        id: 91004,
        title: 'Voting schedule updated',
        body:
            'Election dates were changed. Check the Home countdown for the latest schedule.',
      );
    }

    if (prevPhase != null && prevPhase != phaseKey) {
      await ensureRefresh();
      final a = prevPhase.split('|');
      final b = phaseKey.split('|');
      if (a.length == 3 && b.length == 3) {
        final st0 = a[1];
        final st1 = b[1];
        final rs0 = a[2].toLowerCase();
        final rs1 = b[2].toLowerCase();
        if (st1 == 'Active' && st0 != 'Active') {
          await LocalPushService.show(
            id: 91001,
            title: 'Voting has started',
            body: 'The voting window is now open in ELECOM.',
          );
        }
        if (st1 == 'Closed' && st0 == 'Active') {
          await LocalPushService.show(
            id: 91002,
            title: 'Voting has ended',
            body: 'The voting window is now closed.',
          );
        }
        if (rs1 == 'published' && rs0 == 'pending') {
          await LocalPushService.show(
            id: 91003,
            title: 'Results are available',
            body: 'Election results are now published.',
          );
        }
      }
    }

    await prefs.setString(phasePref, phaseKey);
    await prefs.setString(schedPref, sched);
  }

  Future<void> _refreshFromServer() async {
    try {
      final res = await _api.getElectionWindow();
      final election = res['election'];
      final map = election is Map<String, dynamic>
          ? election
          : const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _election = map;
        _loadError = null;
      });
      await _maybeReactToPhaseChange(map);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load election schedule';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;
    final e = _election;

    final target = _countdownTarget(e);
    final now = DateTime.now();
    Duration diff = target != null ? target.difference(now) : Duration.zero;
    if (diff.isNegative) diff = Duration.zero;
    final d = diff.inDays;
    final h = diff.inHours.remainder(24);
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    final isActive = _isActive(e);
    final showViewResults =
        _isClosedWithoutPublishedResults(e) || _isResultsPublished(e);
    final ctaText = isActive ? 'Vote Now' : (showViewResults ? 'View Results' : 'Vote Now');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: widget.embeddedInProfileCard ? 10 : 8),
        Text(
          'Election Countdown',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        if (_loadError != null)
          Text(
            _loadError!,
            style: TextStyle(
              color: isDark ? Colors.orangeAccent : Colors.red.shade800,
              fontWeight: FontWeight.w700,
            ),
          ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0c1e70), Color(0xFFfea501)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.orgName.trim().isEmpty
                    ? 'ELECOM Election'
                    : '${widget.orgName.trim()} Election',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'General election schedule',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _timeCell(d, 'days'),
                  const SizedBox(width: 8),
                  _timeCell(h, 'hours'),
                  const SizedBox(width: 8),
                  _timeCell(m, 'mins'),
                  const SizedBox(width: 8),
                  _timeCell(s, 'sec'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _statusLine(e, target != null ? diff : null),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              _voteNowButton(context, ctaText: ctaText, showViewResults: showViewResults),
            ],
          ),
        ),
      ],
    );
  }

  Widget _voteNowButton(
    BuildContext context, {
    required String ctaText,
    required bool showViewResults,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          if (showViewResults) {
            widget.onViewResults?.call();
            return;
          }
          widget.onVoteNow?.call();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.how_to_vote_rounded,
                color: Color(0xFF0c1e70),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                ctaText,
                style: TextStyle(
                  color: const Color(0xFF0c1e70),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeCell(int value, String label) {
    final String text = label == 'days' && value > 99
        ? '$value'
        : value.clamp(0, 99).toString().padLeft(2, '0');
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
