import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/utils/toast_service.dart';

import '../../../core/notifications/local_push_service.dart';
import '../../../core/notifications/notification_center_store.dart';
import '../../../core/session/notification_preferences.dart';
import '../../../services/tutorial_service.dart';
import '../candidates/candidate_profile_screen.dart';
import '../data/elecom_mobile_api.dart';
import '../data/election_window_utils.dart';
import '../face/face_enrollment_screen.dart';
import '../face/live_face_capture_screen.dart';
import '../student_dashboard/utils/theme_notifier.dart';
import 'election_transparency_screen.dart';
import 'receipt_screen.dart';

const _premiumBlue = Color(0xFF2563EB);
const _premiumGold = Color(0xFFFACC15);
const _premiumInk = Color(0xFF0F172A);

/// Election / voting tab: ballot from [GET /api/mobile/ballot/], submit via [POST /api/mobile/vote/submit/].
/// Program-based organizations and USG representative rows are enforced server-side.
class ElectionScreen extends StatefulWidget {
  const ElectionScreen({
    super.key,
    this.onRequestTabIndex,
    this.onViewTransparency,
    this.onReceiptReady,
    this.voteIntentNonce = 0,
    this.isActive = false,
  });

  /// Optional hook for the parent dashboard to switch tabs (e.g. go to Receipt).
  final void Function(int index)? onRequestTabIndex;

  /// Optional hook to open an Election Transparency / Voting Ledger screen.
  final VoidCallback? onViewTransparency;

  /// Sends the freshly-created receipt to the parent dashboard so the Receipt
  /// tab can display it immediately without waiting for a refresh.
  final void Function(Map<String, dynamic> receipt)? onReceiptReady;

  /// Incremented when the user taps **Vote Now** on Home so this tab can run gates + face verification before loading the ballot.
  final int voteIntentNonce;

  /// True while the dashboard is showing this tab. Used to avoid showing coach marks behind another tab.
  final bool isActive;

  @override
  State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen>
    with SingleTickerProviderStateMixin {
  final ElecomMobileApi _api = ElecomMobileApi();

  bool _loading = true;
  bool _alreadyVoted = false;
  bool _checkingReceipt = false;
  bool _votingTutorialRequested = false;
  bool _submitInFlight = false;
  String? _loadError;
  Map<String, dynamic> _ballotPayload = const {};
  Map<String, dynamic> _electionWindow = const {};
  late final AnimationController _successIconController;
  Timer? _windowTicker;

  final Map<String, dynamic> _selections = {};
  final Set<String> _straightPartyKeys = <String>{};

  String _positionKey(String org, String position) =>
      '${org.toUpperCase().trim()}::${position.trim()}';

  bool _isMultiSelect(String org, String position) =>
      org.toUpperCase() == 'USG' &&
      position.toUpperCase().contains('REPRESENTATIVE');

  int _candidateId(Map<String, dynamic> candidate) {
    final idVal = candidate['id'];
    if (idVal is int) return idVal;
    return int.tryParse(idVal.toString()) ?? 0;
  }

  String _candidateParty(Map<String, dynamic> candidate) =>
      (candidate['party_name'] ?? '').toString().trim();

  String _candidatePartyLogo(Map<String, dynamic> candidate) {
    for (final key in const [
      'party_logo_url',
      'partyLogoUrl',
      'party_logo',
      'partyLogo',
      'logo_url',
      'logoUrl',
    ]) {
      final value = (candidate[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _straightPartyKey(String orgName, String partyLabel) =>
      '${orgName.trim().toUpperCase()}::${partyLabel.trim().toLowerCase()}';

  int _orgSortPriority(String orgName) =>
      orgName.trim().toUpperCase() == 'USG' ? 0 : 1;

  List<_StraightPartyOption> _straightPartyOptions() {
    final byParty = <String, _StraightPartyOption>{};
    for (final org in _orgList) {
      final orgName = (org['organization'] ?? '').toString().trim();
      final positions = org['positions'];
      if (orgName.isEmpty || positions is! List) continue;
      for (final raw in positions) {
        if (raw is! Map) continue;
        final p = Map<String, dynamic>.from(raw);
        final pos = (p['position'] ?? '').toString().trim();
        final cands = p['candidates'];
        if (pos.isEmpty || cands is! List) continue;

        final seenInPosition = <String>{};
        for (final rawCand in cands.whereType<Map>()) {
          final candidate = Map<String, dynamic>.from(rawCand);
          final party = _candidateParty(candidate);
          if (party.isEmpty || _candidateId(candidate) == 0) continue;
          final partyLogo = _candidatePartyLogo(candidate);
          final normalized = _straightPartyKey(orgName, party);
          final current = byParty.putIfAbsent(
            normalized,
            () => _StraightPartyOption(
              label: party,
              organization: orgName,
              logoUrl: partyLogo,
            ),
          );
          if (current.logoUrl.isEmpty && partyLogo.isNotEmpty) {
            current.logoUrl = partyLogo;
          }
          current.candidateCount++;
          if (seenInPosition.add(normalized)) {
            current.positionCount++;
          }
        }
      }
    }
    final out = byParty.values.toList()
      ..sort((a, b) {
        final byOrg = _orgSortPriority(
          a.organization,
        ).compareTo(_orgSortPriority(b.organization));
        if (byOrg != 0) return byOrg;
        final byOrgName = a.organization.toLowerCase().compareTo(
          b.organization.toLowerCase(),
        );
        if (byOrgName != 0) return byOrgName;
        final byPositions = b.positionCount.compareTo(a.positionCount);
        if (byPositions != 0) return byPositions;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    return out;
  }

  void _selectStraightParty(_StraightPartyOption option) {
    final normalized = option.label.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final targetOrg = option.organization.trim();
    final targetOrgKey = targetOrg.toUpperCase();
    var filled = 0;

    setState(() {
      for (final org in _orgList) {
        final orgName = (org['organization'] ?? '').toString();
        final positions = org['positions'];
        if (orgName.isEmpty || positions is! List) continue;
        if (orgName.trim().toUpperCase() != targetOrgKey) continue;
        for (final raw in positions) {
          if (raw is! Map) continue;
          final p = Map<String, dynamic>.from(raw);
          final pos = (p['position'] ?? '').toString();
          final cands = p['candidates'];
          if (pos.isEmpty || cands is! List) continue;

          final key = _positionKey(orgName, pos);
          final matches = cands
              .whereType<Map>()
              .map((c) => Map<String, dynamic>.from(c))
              .where((c) => _candidateParty(c).toLowerCase() == normalized)
              .map(_candidateId)
              .where((id) => id != 0)
              .toList();
          if (matches.isEmpty) continue;

          if (_isMultiSelect(orgName, pos)) {
            final ids = matches.take(2).toList();
            _selections[key] = ids;
            filled += ids.length;
          } else {
            _selections[key] = matches.first;
            filled++;
          }
        }
      }
      if (filled > 0) {
        _straightPartyKeys.removeWhere(
          (key) => key.startsWith('$targetOrgKey::'),
        );
        _straightPartyKeys.add(option.key);
      }
    });

    if (!mounted) return;
    AppToast.success(
      context,
      filled == 0
          ? 'No candidates found for ${option.label} in $targetOrg.'
          : '$targetOrg ${option.label} slate selected. You can still edit manually.',
    );
  }

  List<Map<String, dynamic>> get _orgList {
    final b = _ballotPayload['ballot'];
    if (b is! List) return <Map<String, dynamic>>[];
    return b.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<String> _eligibleOrganizationLabels() {
    final raw = _ballotPayload['eligible_organizations'];
    if (raw is! List) return <String>[];
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _whoYouCanVoteForExplanation() {
    final orgs = _eligibleOrganizationLabels();
    if (orgs.isEmpty) {
      return 'Only the candidates you are allowed to vote for are shown below.';
    }
    if (orgs.length == 1) {
      return 'You can only vote for ${orgs.first} candidates.';
    }
    final last = orgs.last;
    final head = orgs.sublist(0, orgs.length - 1);
    return 'You can only vote for ${head.join(', ')} and $last candidates.';
  }

  List<String> get _expectedKeys {
    final keys = <String>[];
    for (final org in _orgList) {
      final o = (org['organization'] ?? '').toString();
      final positions = org['positions'];
      if (positions is! List) continue;
      for (final raw in positions) {
        if (raw is! Map) continue;
        final p = Map<String, dynamic>.from(raw);
        final pos = (p['position'] ?? '').toString();
        if (pos.isEmpty) continue;
        keys.add(_positionKey(o, pos));
      }
    }
    return keys;
  }

  @override
  void initState() {
    super.initState();
    _successIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _load();
    _windowTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshWindowOnly();
    });
  }

  @override
  void dispose() {
    _successIconController.dispose();
    _windowTicker?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ElectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeStartVotingTutorial();
      });
    }
    if (widget.voteIntentNonce != oldWidget.voteIntentNonce &&
        widget.voteIntentNonce > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_handleVoteNowFromHome());
        }
      });
    }
  }

  Map<String, dynamic> _normalizeElectionWindow(Map<String, dynamic> payload) {
    final election = ElectionWindowUtils.normalizePayload(payload);
    ElectionWindowUtils.debugLog(election, source: 'voting screen');
    return election;
  }

  bool _isElectionActiveNow(Map<String, dynamic> election) {
    return ElectionWindowUtils.isActiveNow(election);
  }

  bool _isElectionUpcoming(Map<String, dynamic> election) {
    return ElectionWindowUtils.isUpcoming(election);
  }

  Future<void> _refreshWindowOnly() async {
    try {
      final payload = await _api.getElectionWindow();
      if (!mounted) return;
      final election = _normalizeElectionWindow(payload);
      final wasActive = _isElectionActiveNow(_electionWindow);
      final nowActive = _isElectionActiveNow(election);
      setState(() {
        _electionWindow = election;
      });
      if (wasActive != nowActive) {
        await _load(showLoading: false);
      }
    } catch (_) {
      // Keep existing state when periodic refresh fails.
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final windowPayload = await _api.getElectionWindow();
      final election = _normalizeElectionWindow(windowPayload);
      final activeNow = _isElectionActiveNow(election);

      if (!activeNow) {
        if (!mounted) return;
        setState(() {
          _electionWindow = election;
          _alreadyVoted = false;
          _loading = false;
          _ballotPayload = const {};
          _selections.clear();
          _straightPartyKeys.clear();
          _loadError = null;
        });
        return;
      }

      final status = await _api.getVoteStatus();
      if (!mounted) return;
      if (status['ok'] == true && status['voted'] == true) {
        setState(() {
          _electionWindow = election;
          _alreadyVoted = true;
          _loading = false;
          _ballotPayload = const {};
          _selections.clear();
          _straightPartyKeys.clear();
        });
        return;
      }

      setState(() {
        _electionWindow = election;
        _alreadyVoted = false;
        _ballotPayload = const {};
        _selections.clear();
        _straightPartyKeys.clear();
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  /// Home **Vote Now** drives enrollment check, face verification, then ballot load (not done on a plain Election tab open).
  Future<void> _handleVoteNowFromHome() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final windowPayload = await _api.getElectionWindow();
      final election = _normalizeElectionWindow(windowPayload);
      if (!_isElectionActiveNow(election)) {
        if (!mounted) return;
        setState(() {
          _electionWindow = election;
          _loading = false;
          _ballotPayload = const {};
          _selections.clear();
          _straightPartyKeys.clear();
        });
        AppToast.warning(context, 'Election is not active.');
        return;
      }

      final voteStatus = await _api.getVoteStatus();
      if (!mounted) return;
      if (voteStatus['ok'] == true && voteStatus['voted'] == true) {
        setState(() {
          _electionWindow = election;
          _alreadyVoted = true;
          _loading = false;
          _ballotPayload = const {};
          _selections.clear();
          _straightPartyKeys.clear();
        });
        AppToast.info(context, 'You already submitted your vote.');
        return;
      }

      final verified = await _ensureFaceVerifiedBeforeBallot();
      if (!mounted) return;
      if (!verified) {
        setState(() {
          _loading = false;
          _ballotPayload = const {};
          _selections.clear();
          _straightPartyKeys.clear();
          _loadError = 'Face verification did not complete.';
        });
        return;
      }

      final ballot = await _api.getBallot();
      if (!mounted) return;
      if (ballot['ok'] != true) {
        setState(() {
          _electionWindow = election;
          _loadError = (ballot['error'] ?? 'Could not load ballot').toString();
          _loading = false;
        });
        return;
      }

      setState(() {
        _electionWindow = election;
        _alreadyVoted = false;
        _ballotPayload = ballot;
        _selections.clear();
        _straightPartyKeys.clear();
        _loading = false;
        _loadError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeStartVotingTutorial();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  bool _keyFilled(String key) {
    final parts = key.split('::');
    if (parts.length != 2) return false;
    final org = parts[0];
    final pos = parts[1];
    final v = _selections[key];
    if (_isMultiSelect(org, pos)) {
      if (v is! List || v.isEmpty) return false;
      return v.length <= 2;
    }
    return v is int;
  }

  int get _filledCount => _expectedKeys.where(_keyFilled).length;

  Map<String, dynamic> _payloadOnlyFilled() {
    final out = <String, dynamic>{};
    for (final key in _expectedKeys) {
      if (!_keyFilled(key)) continue;
      final parts = key.split('::');
      final org = parts[0];
      final pos = parts[1];
      final v = _selections[key];
      if (_isMultiSelect(org, pos)) {
        final ids = (v as List)
            .map((e) => e is int ? e : int.tryParse(e.toString()))
            .whereType<int>()
            .toList();
        if (ids.isNotEmpty) out[key] = ids;
      } else {
        out[key] = v as int;
      }
    }
    return out;
  }

  ElectionThemePalette _electionPalette(
    BuildContext context,
    bool isDark,
    bool isPremiumMode,
  ) => ElectionThemePalette.fromBrightness(
    isDark ? Brightness.dark : Brightness.light,
    isPremiumMode: isPremiumMode,
  );

  Future<void> _maybeStartVotingTutorial({bool force = false}) async {
    if (!mounted || !widget.isActive) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (_loading || _alreadyVoted || _loadError != null) return;
    if (_expectedKeys.isEmpty) return;
    if (_votingTutorialRequested && !force) return;
    if (!force) _votingTutorialRequested = true;
    await TutorialService.showVotingTutorialIfNeeded(
      context: context,
      force: force,
    );
  }

  Map<int, Map<String, dynamic>> _candidateIndex() {
    final out = <int, Map<String, dynamic>>{};
    for (final org in _orgList) {
      final positions = org['positions'];
      if (positions is! List) continue;
      for (final raw in positions) {
        if (raw is! Map) continue;
        final p = Map<String, dynamic>.from(raw);
        final cands = p['candidates'];
        if (cands is! List) continue;
        for (final c in cands.whereType<Map>()) {
          final m = Map<String, dynamic>.from(c);
          final idVal = m['id'];
          final id = idVal is int ? idVal : int.tryParse(idVal.toString());
          if (id == null || id == 0) continue;
          out[id] = m;
        }
      }
    }
    return out;
  }

  String? _candidateName(Map<String, dynamic> c) {
    final n = (c['name'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    final parts = [
      (c['first_name'] ?? '').toString().trim(),
      (c['middle_name'] ?? '').toString().trim(),
      (c['last_name'] ?? '').toString().trim(),
    ].where((x) => x.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String _formatReceiptDate(String? iso) {
    final raw = (iso ?? '').trim();
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final local = dt.isUtc ? dt.toLocal() : dt;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _showVoteReceiptSheet({
    required Map receipt,
    required ElectionThemePalette palette,
  }) async {
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF18191A) : Colors.white;
    final fg = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.white70 : Colors.black54;

    final ref = (receipt['reference_number'] ?? '').toString().trim();
    final votedAt = _formatReceiptDate((receipt['voted_at'] ?? '').toString());
    final totalSelections = receipt['total_selections'];

    final selectionsRaw = receipt['selections'];
    final selections = selectionsRaw is Map
        ? Map<String, dynamic>.from(selectionsRaw)
        : <String, dynamic>{};

    final candidatesRaw = receipt['candidates'];
    final candidates = candidatesRaw is Map
        ? Map<String, dynamic>.from(candidatesRaw)
        : <String, dynamic>{};

    final ballotDataRaw = receipt['ballot_data'];
    final ballotData = ballotDataRaw is Map
        ? Map<String, dynamic>.from(ballotDataRaw)
        : <String, dynamic>{};
    final ballotRaw = ballotData['ballot'];
    final ballot = ballotRaw is List
        ? ballotRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    Widget receiptAvatar(dynamic photoUrlRaw) {
      final photo = resolvedCandidatePhotoUrl(photoUrlRaw);
      final stroke = isDark ? Colors.white24 : const Color(0xFFD7D7D7);
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: stroke, width: 2),
        ),
        padding: const EdgeInsets.all(1.5),
        child: CircleAvatar(
          radius: 20, // ~40px photo (same feel as Election)
          backgroundColor: isDark ? Colors.white12 : const Color(0xFFEAF1FF),
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null
              ? Icon(
                  Icons.person,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black54,
                )
              : null,
        ),
      );
    }

    List<Widget> buildLines() {
      final lines = <Widget>[];

      void addLine(String left, String right) {
        if (right.trim().isEmpty) return;
        lines.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    left,
                    style: TextStyle(
                      color: sub,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    right,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      addLine('Reference', ref);
      addLine('Voted at', votedAt);
      addLine(
        'Selections',
        totalSelections == null ? '' : totalSelections.toString(),
      );

      lines.add(const SizedBox(height: 14));
      lines.add(
        Divider(
          color: isDark ? Colors.white12 : const Color(0xFFE6E6E6),
          height: 1,
        ),
      );
      lines.add(const SizedBox(height: 10));
      lines.add(
        Text(
          'Summary',
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      );
      lines.add(const SizedBox(height: 6));

      // Render selected items (position -> candidate(s)).
      Iterable<String> orderedPositionKeys() sync* {
        // Prefer ballot order (same as Election screen). Fallback to natural map key order.
        if (ballot.isNotEmpty) {
          for (final org in ballot) {
            final orgName = (org['organization'] ?? '').toString().trim();
            final positionsRaw = org['positions'];
            if (orgName.isEmpty || positionsRaw is! List) continue;
            for (final p in positionsRaw.whereType<Map>()) {
              final posName = (p['position'] ?? '').toString().trim();
              if (posName.isEmpty) continue;
              yield '$orgName::$posName';
            }
          }
          return;
        }
        for (final k in selections.keys) {
          yield k.toString();
        }
      }

      final emitted = <String>{};
      for (final posKey in orderedPositionKeys()) {
        if (emitted.contains(posKey)) continue;
        emitted.add(posKey);

        final v = selections[posKey];
        final ids = v is List
            ? v.map((e) => e.toString()).where((x) => x.isNotEmpty).toList()
            : <String>[v?.toString() ?? ''].where((x) => x.isNotEmpty).toList();
        if (ids.isEmpty) continue;

        final orgLabel = posKey.contains('::')
            ? posKey.split('::').first.trim()
            : '';
        final posLabel = posKey.contains('::')
            ? posKey.split('::').last.trim()
            : posKey;

        lines.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              posLabel,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
              ),
            ),
          ),
        );

        for (final id in ids) {
          final candRaw = candidates[id];
          final cand = candRaw is Map
              ? Map<String, dynamic>.from(candRaw)
              : <String, dynamic>{};
          final name = (cand['name'] ?? '').toString().trim();
          final party = (cand['party_name'] ?? '').toString().trim();
          final photoUrl = cand['photo_url'];
          final subtitle = [
            if (party.isNotEmpty) party,
            if (orgLabel.isNotEmpty) orgLabel,
          ].join(' · ');

          lines.add(
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFD7D7D7),
                ),
              ),
              child: Row(
                children: [
                  receiptAvatar(photoUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Candidate' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            height: 1.15,
                          ),
                        ),
                        if (subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: sub,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      return lines;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height;
        return SafeArea(
          top: false,
          child: SizedBox(
            height: (h * 0.82).clamp(h * 0.65, h * 0.9),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Vote receipt',
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close, color: fg),
                      ),
                    ],
                  ),
                  Text(
                    'Thank you for voting. Your vote has been successfully recorded.',
                    style: TextStyle(
                      color: sub,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 8),
                      children: buildLines(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: palette.onAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit(ElectionThemePalette palette) async {
    if (_submitInFlight) return;
    setState(() => _submitInFlight = true);
    try {
      await _submitLocked(palette);
    } finally {
      if (mounted) {
        setState(() => _submitInFlight = false);
      } else {
        _submitInFlight = false;
      }
    }
  }

  Future<void> _submitLocked(ElectionThemePalette palette) async {
    try {
      final windowPayload = await _api.getElectionWindow();
      final election = _normalizeElectionWindow(windowPayload);
      if (!_isElectionActiveNow(election)) {
        if (!mounted) return;
        setState(() {
          _electionWindow = election;
          _ballotPayload = const {};
        });
        AppToast.warning(
          context,
          'Election is not open. Your vote was not submitted.',
        );
        return;
      }

      final status = await _api.getVoteStatus();
      if (!mounted) return;
      if (status['ok'] == true && status['voted'] == true) {
        setState(() {
          _alreadyVoted = true;
        });
        AppToast.info(context, 'You already submitted your vote.');
        return;
      }
    } on ElecomApiException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      AppToast.error(
        context,
        'Unable to validate election status. Please try again.',
      );
      return;
    }

    final payload = _payloadOnlyFilled();
    if (payload.isEmpty) {
      AppToast.warning(
        context,
        'Select at least one candidate before submitting.',
      );
      return;
    }

    final blankCount = _expectedKeys.length - _filledCount;

    final index = _candidateIndex();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final fg = Theme.of(ctx).brightness == Brightness.dark
            ? Colors.white
            : Colors.black;
        final sub = Theme.of(ctx).brightness == Brightness.dark
            ? Colors.white70
            : Colors.black54;
        final screenH = MediaQuery.sizeOf(ctx).height;
        final dialogH = (screenH * 0.82).clamp(screenH * 0.75, screenH * 0.85);
        final listController = ScrollController();

        Widget avatar(dynamic photoUrlRaw) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final photo = resolvedCandidatePhotoUrl(photoUrlRaw);
          final stroke = isDark ? Colors.white24 : const Color(0xFFD7D7D7);
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: stroke, width: 2),
            ),
            padding: const EdgeInsets.all(1.5),
            child: CircleAvatar(
              radius: 20, // ~40px photo, compact but readable
              backgroundColor: isDark
                  ? Colors.white12
                  : const Color(0xFFEAF1FF),
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? Icon(
                      Icons.person,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.black54,
                    )
                  : null,
            ),
          );
        }

        List<Widget> summaryWidgets() {
          final widgets = <Widget>[];
          for (final key in _expectedKeys) {
            final parts = key.split('::');
            if (parts.length != 2) continue;
            final org = parts[0].trim();
            final pos = parts[1].trim();

            widgets.add(
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Text(
                  pos,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: fg,
                    fontSize: 13.5,
                  ),
                ),
              ),
            );

            final v = _selections[key];
            if (v == null || (v is List && v.isEmpty)) {
              widgets.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'No candidate selected',
                    style: TextStyle(
                      color: sub,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
              continue;
            }

            final ids = v is List
                ? v
                      .map((e) => e is int ? e : int.tryParse(e.toString()))
                      .whereType<int>()
                      .toList()
                : <int>[
                    v is int ? v : (int.tryParse(v.toString()) ?? 0),
                  ].where((x) => x != 0).toList();

            for (final id in ids) {
              final c = index[id] ?? <String, dynamic>{'id': id};
              final name = _candidateName(c) ?? 'Candidate';
              final party = (c['party_name'] ?? '').toString().trim();
              widgets.add(
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white12
                          : const Color(0xFFD7D7D7),
                    ),
                  ),
                  child: Row(
                    children: [
                      avatar(c['photo_url']),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: fg,
                                fontSize: 14,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [if (party.isNotEmpty) party, org].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: sub,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
          return widgets;
        }

        // Avoid nested scrollables (can cause jank/ANR on some devices).
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF18191A) : Colors.white;
        final noteColor = isDark
            ? const Color(0xFFFF6B6B)
            : const Color(0xFFB00020);

        bool isAtBottom() {
          if (!listController.hasClients) return false;
          // Treat "near bottom" as bottom to avoid pixel-perfect issues.
          return listController.position.extentAfter <= 8;
        }

        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (ctx, setState) {
              var canContinue = isAtBottom();

              void syncBottom() {
                final next =
                    isAtBottom() ||
                    (listController.hasClients &&
                        listController.position.maxScrollExtent <= 0);
                if (next != canContinue) setState(() => canContinue = next);
              }

              // Initial computation after layout.
              WidgetsBinding.instance.addPostFrameCallback((_) => syncBottom());

              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                backgroundColor: dialogBg,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  height: dialogH.toDouble(),
                  width: double.maxFinite,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirm your vote',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are about to submit your ballot. Please review your selected candidates before continuing. '
                          'Once submitted, your vote cannot be changed.',
                          style: TextStyle(
                            color: sub,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                        if (blankCount > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Note: $blankCount position(s) will be left blank.',
                            style: TextStyle(
                              color: noteColor,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n is ScrollUpdateNotification ||
                                  n is ScrollEndNotification) {
                                syncBottom();
                              }
                              return false;
                            },
                            child: ListView(
                              controller: listController,
                              padding: const EdgeInsets.only(bottom: 8),
                              children: summaryWidgets(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: fg,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: palette.accent,
                                  ),
                                  onPressed: canContinue
                                      ? () => Navigator.pop(ctx, true)
                                      : null,
                                  child: Text(
                                    'Continue',
                                    style: TextStyle(
                                      color: palette.onAccent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    if (ok != true || !mounted) return;

    final verified = await _runFaceVerificationBeforeVote();
    if (!verified || !mounted) return;

    try {
      final windowPayload = await _api.getElectionWindow();
      final election = _normalizeElectionWindow(windowPayload);
      if (!_isElectionActiveNow(election)) {
        if (!mounted) return;
        setState(() {
          _electionWindow = election;
          _ballotPayload = const {};
        });
        AppToast.warning(
          context,
          'Election is not open. Your vote was not submitted.',
        );
        return;
      }
    } on ElecomApiException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      AppToast.error(
        context,
        'Unable to validate election status. Please try again.',
      );
      return;
    }

    if (!context.mounted) return;

    // Show a blocking progress dialog while we submit (prevents perceived \"freeze\").
    showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black;
        final bg = isDark ? const Color(0xFF18191A) : Colors.white;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFD7D7D7),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Submitting...',
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final deviceIp = await _deviceLocalIp();
      await _api.submitVote(<String, dynamic>{
        'selections': payload,
        if (deviceIp.isNotEmpty) ...{
          'device_ip': deviceIp,
          'local_ip': deviceIp,
        },
      });
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // close submitting dialog

      // Fetch receipt once to ensure it's available right away.
      Map<String, dynamic>? receiptMap;
      String? referenceNumber;
      try {
        final receiptRes = await _api.getVoteReceipt();
        final receipt = receiptRes['receipt'];
        if (receipt is Map) {
          receiptMap = Map<String, dynamic>.from(receipt);
          final ref = (receipt['reference_number'] ?? '').toString().trim();
          if (ref.isNotEmpty) referenceNumber = ref;
        }
      } catch (_) {
        // Ignore: receipt can still be viewed later from the Receipt tab.
      }

      final notifTitle = 'Vote recorded';
      final notifBody = referenceNumber == null
          ? 'Thank you for voting. Your vote has been successfully recorded.'
          : 'Thank you for voting. Your vote has been successfully recorded.\nReceipt: $referenceNumber';

      // In-app notification (server-backed).
      if (await NotificationPreferences.isInAppEnabled()) {
        try {
          await NotificationCenterStore.add(
            title: notifTitle,
            body: notifBody,
            type: 'receipt',
          );
        } catch (_) {}
      }

      // Push notification (local notification on-device).
      if (await NotificationPreferences.isPushEnabled()) {
        try {
          final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 30);
          await LocalPushService.show(
            id: id,
            title: notifTitle,
            body: notifBody,
          );
        } catch (_) {}
      }

      if (!mounted) return;
      AppToast.success(context, 'Your vote has been recorded.');

      if (receiptMap != null) {
        widget.onReceiptReady?.call(receiptMap);
        await _showVoteReceiptSheet(receipt: receiptMap, palette: palette);
      }

      await _load();
    } on ElecomApiException catch (e) {
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // close submitting dialog
      await _refreshWindowOnly();
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      AppToast.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // close submitting dialog
      AppToast.error(context, e.toString());
    }
  }

  Future<bool> _runFaceVerificationBeforeVote() async {
    const mismatchMsg =
        'Face verification failed. This face does not match the enrolled voter.';

    final status = await _api.getFaceEnrollmentStatus();
    if (status['enrolled'] != true) {
      if (!mounted) return false;
      AppToast.warning(context, 'Face enrollment is required before voting.');
      return false;
    }

    if (!mounted) return false;

    TutorialService.dismissActiveTutorial();
    final capture = await Navigator.of(context).push<LiveFaceCaptureResult>(
      MaterialPageRoute(
        builder: (_) =>
            const LiveFaceCaptureScreen(mode: LiveFaceMode.verification),
      ),
    );
    if (capture == null || !mounted) {
      return false;
    }
    if (capture.livenessPassed != true) {
      if (!mounted) return false;
      AppToast.warning(context, 'Blink/liveness check did not complete.');
      return false;
    }

    try {
      if (!mounted) return false;
      final verify = await _api.verifyFaceForVote(
        liveFaceImageFile: capture.capturedImage,
        livenessPassed: true,
      );
      final allow = verify['allow_to_vote'] == true;
      if (!allow && mounted) {
        final reason = (verify['failure_reason'] ?? '').toString().trim();
        final text = reason.isEmpty ? mismatchMsg : reason;
        AppToast.error(context, text);
      }
      return allow;
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Face verification error: $e');
      }
      return false;
    }
  }

  Future<bool> _ensureFaceVerifiedBeforeBallot() async {
    final enroll = await _api.getFaceEnrollmentStatus();
    if (!mounted) return false;
    if (enroll['enrolled'] != true) {
      setState(() => _loading = false);
      TutorialService.dismissActiveTutorial();
      final enrolled = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const FaceEnrollmentScreen(
            isMandatory: false,
            navigateToDashboardOnSuccess: false,
          ),
        ),
      );
      if (!mounted || enrolled != true) {
        return false;
      }
      setState(() => _loading = true);
    }

    return _runFaceVerificationBeforeVote();
  }

  Future<String> _deviceLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address.trim();
          if (ip.isEmpty || ip.startsWith('127.')) continue;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(ip)) {
            return ip;
          }
        }
      }
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address.trim();
          if (ip.isNotEmpty && !ip.startsWith('127.')) return ip;
        }
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremiumMode = themeNotifier.isPremiumMode;
    final titleColor = isPremiumMode
        ? _premiumInk
        : isDark
        ? Colors.white
        : Colors.black;
    final subtitleColor = isPremiumMode
        ? const Color(0xFF475569)
        : isDark
        ? Colors.white70
        : Colors.black54;
    final electionState = _isElectionActiveNow(_electionWindow)
        ? _ElectionAccessState.active
        : (_isElectionUpcoming(_electionWindow)
              ? _ElectionAccessState.upcoming
              : _ElectionAccessState.closed);

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      );
    }

    if (electionState != _ElectionAccessState.active) {
      final title = electionState == _ElectionAccessState.upcoming
          ? 'Election Not Started'
          : 'Election Closed';
      final message = electionState == _ElectionAccessState.upcoming
          ? 'Election has not started yet.\nVoting will open once the election begins.'
          : 'Election has ended.\nVoting is now closed. You may view the results when available.';
      return RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isPremiumMode)
                            Center(
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: _premiumBlue.withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _premiumBlue.withValues(alpha: 0.18),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _premiumBlue.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: HugeIcon(
                                  icon:
                                      electionState ==
                                          _ElectionAccessState.upcoming
                                      ? HugeIcons.strokeRoundedClock01
                                      : HugeIcons.strokeRoundedShieldBlockchain,
                                  size: 36,
                                  color: _premiumBlue,
                                  strokeWidth: 1.9,
                                ),
                              ),
                            )
                          else
                            Icon(
                              electionState == _ElectionAccessState.upcoming
                                  ? Icons.schedule
                                  : Icons.lock_clock_outlined,
                              size: 56,
                              color: subtitleColor,
                            ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: subtitleColor,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          if (electionState == _ElectionAccessState.closed) ...[
                            const SizedBox(height: 18),
                            isPremiumMode
                                ? _SecureActionButton(
                                    loading: false,
                                    label: 'View Results',
                                    icon: Icons.bar_chart_outlined,
                                    premiumIcon:
                                        HugeIcons.strokeRoundedChartBarLine,
                                    isPremiumMode: true,
                                    background: _premiumBlue,
                                    gold: _premiumBlue.withValues(alpha: 0.18),
                                    onPressed: () =>
                                        widget.onRequestTabIndex?.call(2),
                                  )
                                : FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      foregroundColor: isDark
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                    onPressed: () =>
                                        widget.onRequestTabIndex?.call(2),
                                    icon: const Icon(Icons.bar_chart_outlined),
                                    label: const Text(
                                      'View Results',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_alreadyVoted) {
      final pageBg = isPremiumMode
          ? Colors.transparent
          : isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF3F4F6);
      final cardBg = isPremiumMode
          ? Colors.white.withValues(alpha: 0.90)
          : isDark
          ? const Color(0xFF1E1E1E)
          : Colors.white;
      final cardBorder = isPremiumMode
          ? _premiumGold.withValues(alpha: 0.45)
          : isDark
          ? Colors.white12
          : const Color(0xFFE5E7EB);
      final iconBg = isPremiumMode
          ? _premiumBlue.withValues(alpha: 0.10)
          : isDark
          ? const Color(0xFF163427)
          : const Color(0xFFDCFCE7);
      final primary = isPremiumMode
          ? _premiumInk
          : isDark
          ? Colors.white
          : const Color(0xFF111111);
      final secondaryText = isPremiumMode
          ? const Color(0xFF475569)
          : isDark
          ? Colors.white70
          : const Color(0xFF6B7280);

      return RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(
                decoration: BoxDecoration(
                  color: pageBg,
                  gradient: isPremiumMode
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.20),
                            _premiumBlue.withValues(alpha: 0.08),
                            _premiumGold.withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isPremiumMode
                                            ? _premiumBlue
                                            : Colors.black)
                                        .withValues(
                                          alpha: isPremiumMode
                                              ? 0.18
                                              : isDark
                                              ? 0.30
                                              : 0.10,
                                        ),
                                blurRadius: isPremiumMode ? 30 : 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: AnimatedBuilder(
                                  animation: _successIconController,
                                  builder: (context, child) {
                                    final t = Curves.easeInOut.transform(
                                      _successIconController.value,
                                    );
                                    final dy = (t - 0.5) * 5;
                                    final scale = 1 + (0.035 * t);
                                    final glow = 0.14 + (0.12 * t);
                                    return Transform.translate(
                                      offset: Offset(0, -dy),
                                      child: Transform.scale(
                                        scale: scale,
                                        child: Container(
                                          width: 62,
                                          height: 62,
                                          decoration: BoxDecoration(
                                            color: iconBg,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark
                                                  ? const Color(
                                                      0xFF22C55E,
                                                    ).withValues(alpha: 0.35)
                                                  : const Color(
                                                      0xFF22C55E,
                                                    ).withValues(alpha: 0.28),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF22C55E,
                                                ).withValues(alpha: glow),
                                                blurRadius: 16,
                                                offset: const Offset(0, 7),
                                              ),
                                            ],
                                          ),
                                          child: isPremiumMode
                                              ? HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedShieldBlockchain,
                                                  size: 34,
                                                  color: _premiumBlue,
                                                  strokeWidth: 2,
                                                )
                                              : const Icon(
                                                  Icons.check_rounded,
                                                  size: 34,
                                                  color: Color(0xFF16A34A),
                                                ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Vote Submitted',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: primary,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your vote has been recorded successfully.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: secondaryText,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You can view your receipt once available.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black45,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _SecureActionButton(
                                loading: _checkingReceipt,
                                label: 'View Receipt',
                                icon: Icons.receipt_long_outlined,
                                premiumIcon: HugeIcons.strokeRoundedInvoice03,
                                isPremiumMode: isPremiumMode,
                                background: isPremiumMode
                                    ? _premiumBlue
                                    : const Color(0xFF0D0D0D),
                                gold: isPremiumMode
                                    ? _premiumGold
                                    : isDark
                                    ? Colors.white12
                                    : const Color(0xFFE5E7EB),
                                onPressed: () async {
                                  setState(() => _checkingReceipt = true);
                                  try {
                                    final res = await _api.getVoteReceipt();
                                    if (!mounted) return;
                                    final ok = res['ok'] == true;
                                    final receipt = res['receipt'];
                                    if (ok && receipt != null) {
                                      if (receipt is Map) {
                                        widget.onReceiptReady?.call(
                                          Map<String, dynamic>.from(receipt),
                                        );
                                      }
                                      if (widget.onRequestTabIndex != null) {
                                        widget.onRequestTabIndex!.call(3);
                                      } else {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ReceiptScreen(),
                                          ),
                                        );
                                      }
                                    } else {
                                      AppToast.info(
                                        context,
                                        'Your receipt is not yet available.',
                                      );
                                    }
                                  } catch (_) {
                                    if (!mounted) return;
                                    AppToast.info(
                                      context,
                                      'Your receipt is not yet available.',
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _checkingReceipt = false);
                                    }
                                  }
                                },
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: () {
                                  if (widget.onViewTransparency != null) {
                                    widget.onViewTransparency!.call();
                                    return;
                                  }
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ElectionTransparencyScreen(),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  isPremiumMode
                                      ? Icons.security_rounded
                                      : Icons.link_rounded,
                                  size: 16,
                                  color: isPremiumMode
                                      ? _premiumBlue
                                      : isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                                label: const Text('View Transparency'),
                                style: TextButton.styleFrom(
                                  foregroundColor: isDark
                                      ? Colors.white70
                                      : const Color(0xFF4B5563),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: subtitleColor),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                onPressed: _handleVoteNowFromHome,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final programCode = (_ballotPayload['program_code'] ?? '')
        .toString()
        .trim();

    final palette = _electionPalette(context, isDark, isPremiumMode);

    if (_expectedKeys.isEmpty) {
      return RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'No ballot positions are available for your account.',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'If you expect to vote, confirm your program is set correctly on your profile.',
              style: TextStyle(
                color: subtitleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final electionThemeData = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: palette.accent,
        secondary: palette.accent,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return isDark ? Colors.white54 : Colors.black45;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return null;
        }),
        checkColor: WidgetStateProperty.all(palette.onAccent),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.accent,
        selectedTileColor: isDark
            ? Colors.white10
            : Colors.black.withValues(alpha: 0.04),
      ),
    );

    return Theme(
      data: electionThemeData,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: Colors.black,
              backgroundColor: Colors.white,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    key: ElecomTutorialKeys.votingHeader,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Election',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          programCode.isEmpty
                              ? 'Your program: not detected from your account'
                              : 'Your program: $programCode',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _whoYouCanVoteForExplanation(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._straightPartySection(
                    isDark,
                    isPremiumMode,
                    palette,
                    titleColor,
                  ),
                  if (_straightPartyOptions().isNotEmpty)
                    const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final org in _orgList)
                        ..._orgSection(
                          context,
                          org,
                          isDark,
                          isPremiumMode,
                          palette,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                key: ElecomTutorialKeys.votingSubmit,
                width: double.infinity,
                child: _SecureActionButton(
                  loading: _submitInFlight,
                  label: _submitInFlight ? 'Submitting...' : 'Submit ballot',
                  icon: Icons.how_to_vote_outlined,
                  premiumIcon: HugeIcons.strokeRoundedSent,
                  isPremiumMode: isPremiumMode,
                  background: palette.accent,
                  gold: isPremiumMode
                      ? _premiumGold
                      : isDark
                      ? Colors.white12
                      : const Color(0xFFE5E7EB),
                  onPressed: () => _submit(palette),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _orgSection(
    BuildContext context,
    Map<String, dynamic> org,
    bool isDark,
    bool isPremiumMode,
    ElectionThemePalette palette,
  ) {
    final orgName = (org['organization'] ?? '').toString();
    final positions = org['positions'];
    if (positions is! List || orgName.isEmpty) return [];

    final titleColor = isDark ? Colors.white : Colors.black;
    final card = isPremiumMode
        ? Colors.white.withValues(alpha: 0.92)
        : isDark
        ? const Color(0xFF2A2A35)
        : Colors.white;
    final border = isPremiumMode
        ? _premiumBlue.withValues(alpha: 0.16)
        : isDark
        ? Colors.white38
        : Colors.black26;

    final widgets = <Widget>[
      const SizedBox(height: 8),
      Text(
        orgName,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: titleColor,
        ),
      ),
      const SizedBox(height: 8),
    ];

    for (final raw in positions) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final pos = (p['position'] ?? '').toString();
      final cands = p['candidates'];
      if (pos.isEmpty || cands is! List) continue;

      final key = _positionKey(orgName, pos);
      final multi = _isMultiSelect(orgName, pos);

      widgets.add(
        Container(
          key: key == _expectedKeys.first
              ? ElecomTutorialKeys.votingBallot
              : null,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
            boxShadow: isPremiumMode
                ? [
                    BoxShadow(
                      color: _premiumBlue.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      pos,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (!multi && ((_selections[key] != null)))
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white70
                            : palette.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => setState(() {
                        _selections.remove(key);
                        _straightPartyKeys.clear();
                      }),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (multi &&
                      ((_selections[key] as List?)?.isNotEmpty ?? false))
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white70
                            : palette.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => setState(() {
                        _selections.remove(key);
                        _straightPartyKeys.clear();
                      }),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              if (multi)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    'Select up to 2 candidates',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // Candidate rows: [Photo] [Name + party] [Control]
              ...cands.whereType<Map>().map((c) {
                final m = Map<String, dynamic>.from(c);
                final idVal = m['id'];
                final id = idVal is int
                    ? idVal
                    : int.tryParse(idVal.toString()) ?? 0;
                if (id == 0) return const SizedBox.shrink();
                final name = _candidateName(m) ?? 'Candidate';
                final photo = resolvedCandidatePhotoUrl(m['photo_url']);
                final party = (m['party_name'] ?? '').toString().trim();

                final avatarStroke = isDark ? Colors.white24 : Colors.black26;

                Widget avatar() {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: avatarStroke, width: 2),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark
                          ? Colors.white12
                          : const Color(0xFFEAF1FF),
                      backgroundImage: photo != null
                          ? NetworkImage(photo)
                          : null,
                      child: photo == null
                          ? Icon(
                              Icons.person,
                              size: 20,
                              color: isDark ? Colors.white54 : palette.accent,
                            )
                          : null,
                    ),
                  );
                }

                Widget rowShell({
                  required Widget control,
                  required VoidCallback onTap,
                }) {
                  final rowBorder = isDark
                      ? Colors.white12
                      : const Color(0xFFD7D7D7);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: onTap,
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: rowBorder),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              avatar(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: titleColor,
                                        fontSize: 14.5,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (party.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        party,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                          fontSize: 12.5,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 44,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: control,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (multi) {
                  final list =
                      (_selections[key] as List<dynamic>?)
                          ?.map((e) => e as int)
                          .toList() ??
                      <int>[];
                  final checked = list.contains(id);
                  return rowShell(
                    control: Checkbox(
                      value: checked,
                      activeColor: palette.accent,
                      checkColor: palette.onAccent,
                      onChanged: (v) {
                        setState(() {
                          final next = List<int>.from(list);
                          if (v == true) {
                            if (next.length < 2) next.add(id);
                          } else {
                            next.remove(id);
                          }
                          _selections[key] = next;
                          _straightPartyKeys.clear();
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        final next = List<int>.from(list);
                        if (checked) {
                          next.remove(id);
                        } else {
                          if (next.length < 2) next.add(id);
                        }
                        _selections[key] = next;
                        _straightPartyKeys.clear();
                      });
                    },
                  );
                }

                final selectedId = _selections[key] as int?;
                final selected = selectedId == id;
                return rowShell(
                  control: Radio<int>(
                    value: id,
                    groupValue: selectedId,
                    activeColor: palette.accent,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selections[key] = v;
                        _straightPartyKeys.clear();
                      });
                    },
                  ),
                  onTap: () {
                    if (selected) return;
                    setState(() {
                      _selections[key] = id;
                      _straightPartyKeys.clear();
                    });
                  },
                );
              }),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _straightPartySection(
    bool isDark,
    bool isPremiumMode,
    ElectionThemePalette palette,
    Color titleColor,
  ) {
    final options = _straightPartyOptions();
    if (options.isEmpty) return const <Widget>[];

    final card = isPremiumMode
        ? Colors.white.withValues(alpha: 0.92)
        : isDark
        ? const Color(0xFF2A2A35)
        : Colors.white;
    final border = isPremiumMode
        ? _premiumGold.withValues(alpha: 0.45)
        : isDark
        ? Colors.white24
        : const Color(0xFFD7D7D7);
    final sub = isPremiumMode
        ? const Color(0xFF475569)
        : isDark
        ? Colors.white60
        : Colors.black54;

    return [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: isPremiumMode
              ? [
                  BoxShadow(
                    color: _premiumBlue.withValues(alpha: 0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (isPremiumMode) ...[
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckList,
                          color: _premiumBlue,
                          size: 18,
                          strokeWidth: 1.9,
                        ),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          'Straight party vote',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_straightPartyKeys.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : palette.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => setState(() {
                      _straightPartyKeys.clear();
                      _selections.clear();
                    }),
                    child: const Text(
                      'Clear all',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a USG or organization party to auto-select that slate. You can still change any position manually.',
              style: TextStyle(
                color: sub,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            ...options.map((option) {
              final selected = _straightPartyKeys.contains(option.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StraightPartyButton(
                  option: option,
                  selected: selected,
                  isDark: isDark,
                  isPremiumMode: isPremiumMode,
                  palette: palette,
                  onTap: () => _selectStraightParty(option),
                ),
              );
            }),
          ],
        ),
      ),
    ];
  }
}

enum _ElectionAccessState { upcoming, active, closed }

class _StraightPartyOption {
  _StraightPartyOption({
    required this.label,
    required this.organization,
    required this.logoUrl,
  });

  final String label;
  final String organization;
  String logoUrl;
  int candidateCount = 0;
  int positionCount = 0;

  String get key =>
      '${organization.trim().toUpperCase()}::${label.trim().toLowerCase()}';
}

class _StraightPartyButton extends StatelessWidget {
  const _StraightPartyButton({
    required this.option,
    required this.selected,
    required this.isDark,
    required this.isPremiumMode,
    required this.palette,
    required this.onTap,
  });

  final _StraightPartyOption option;
  final bool selected;
  final bool isDark;
  final bool isPremiumMode;
  final ElectionThemePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logo = resolvedCandidatePhotoUrl(option.logoUrl);
    final bg = isPremiumMode
        ? selected
              ? _premiumBlue
              : _premiumBlue.withValues(alpha: 0.06)
        : selected
        ? palette.accent
        : isDark
        ? Colors.white10
        : const Color(0xFFF3F4F6);
    final fg = isPremiumMode
        ? selected
              ? Colors.white
              : _premiumInk
        : selected
        ? palette.onAccent
        : isDark
        ? Colors.white
        : Colors.black87;
    final sub = isPremiumMode
        ? selected
              ? Colors.white.withValues(alpha: 0.78)
              : const Color(0xFF475569)
        : selected
        ? palette.onAccent.withValues(alpha: 0.78)
        : isDark
        ? Colors.white60
        : Colors.black54;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? (isPremiumMode ? _premiumGold : palette.accent)
                  : isDark
                  ? Colors.white12
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PartyLogoBadge(
                logoUrl: logo,
                label: option.label,
                selected: selected,
                isPremiumMode: isPremiumMode,
                foreground: fg,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            option.organization,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: sub,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${option.positionCount} position${option.positionCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: sub,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: sub, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartyLogoBadge extends StatelessWidget {
  const _PartyLogoBadge({
    required this.logoUrl,
    required this.label,
    required this.selected,
    required this.isPremiumMode,
    required this.foreground,
  });

  final String? logoUrl;
  final String label;
  final bool selected;
  final bool isPremiumMode;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final initials = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    final borderColor = isPremiumMode
        ? _premiumGold.withValues(alpha: selected ? 0.95 : 0.55)
        : Colors.black12;
    final bg = isPremiumMode
        ? (selected ? Colors.white.withValues(alpha: 0.16) : Colors.white)
        : Colors.white;

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl == null
          ? Center(
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: TextStyle(
                  color: isPremiumMode && selected ? Colors.white : foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    initials.isEmpty ? '?' : initials,
                    style: TextStyle(
                      color: isPremiumMode && selected
                          ? Colors.white
                          : foreground,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Black/white-only control colors for the Election tab (avoids seed/brown Material tints).
class ElectionThemePalette {
  const ElectionThemePalette({
    required this.accent,
    required this.onAccent,
    required this.snackNeutral,
    required this.snackFg,
  });

  final Color accent;
  final Color onAccent;
  final Color snackNeutral;
  final Color snackFg;

  factory ElectionThemePalette.fromBrightness(
    Brightness b, {
    bool isPremiumMode = false,
  }) {
    if (isPremiumMode) {
      return const ElectionThemePalette(
        accent: _premiumBlue,
        onAccent: Colors.white,
        snackNeutral: _premiumInk,
        snackFg: Colors.white,
      );
    }
    if (b == Brightness.dark) {
      return const ElectionThemePalette(
        accent: Colors.white,
        onAccent: Colors.black,
        snackNeutral: Color(0xFFE8E8E8),
        snackFg: Colors.black,
      );
    }
    return const ElectionThemePalette(
      accent: Colors.black,
      onAccent: Colors.white,
      snackNeutral: Colors.black87,
      snackFg: Colors.white,
    );
  }
}

class _SecureActionButton extends StatefulWidget {
  const _SecureActionButton({
    required this.loading,
    required this.label,
    required this.icon,
    required this.background,
    required this.gold,
    required this.onPressed,
    this.premiumIcon,
    this.isPremiumMode = false,
  });

  final bool loading;
  final String label;
  final IconData icon;
  final List<List<dynamic>>? premiumIcon;
  final bool isPremiumMode;
  final Color background;
  final Color gold;
  final VoidCallback onPressed;

  @override
  State<_SecureActionButton> createState() => _SecureActionButtonState();
}

class _SecureActionButtonState extends State<_SecureActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = widget.isPremiumMode ? Colors.white : Colors.white;
    final disabled = widget.loading;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : widget.onPressed,
          onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
          onTapCancel: disabled ? null : () => setState(() => _pressed = false),
          onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              color: widget.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.gold.withValues(alpha: disabled ? 0.25 : 0.75),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.isPremiumMode ? _premiumBlue : widget.gold)
                      .withValues(
                        alpha: disabled
                            ? 0.0
                            : widget.isPremiumMode
                            ? 0.24
                            : (isDark ? 0.10 : 0.12),
                      ),
                  blurRadius: widget.isPremiumMode ? 24 : 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isPremiumMode && widget.premiumIcon != null)
                          HugeIcon(
                            icon: widget.premiumIcon!,
                            size: 18,
                            color: fg,
                            strokeWidth: 1.9,
                          )
                        else
                          Icon(widget.icon, size: 18, color: fg),
                        const SizedBox(width: 10),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
