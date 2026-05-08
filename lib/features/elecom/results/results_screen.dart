import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../../core/session/user_session.dart';
import '../candidates/candidate_profile_screen.dart';
import '../data/elecom_mobile_api.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();
  Timer? _autoRefreshTimer;
  bool _refreshInFlight = false;
  int _chartAnimSeed = 0;
  String _viewerDepartment = '';

  /// `'ALL'` or organization key matching filter chips (e.g. `USG`).
  String _orgFilter = 'ALL';

  final Set<String> _expandedOrgNames = {};

  bool _loading = true;
  String? _error;
  bool _published = true;
  String _message = '';
  Map<String, dynamic> _orgTotals = const <String, dynamic>{};
  Map<String, dynamic> _positionTotals = const <String, dynamic>{};
  List<Map<String, dynamic>> _grouped = const <Map<String, dynamic>>[];

  static const List<String> _fixedOrgFilters = <String>[
    'ALL',
    'USG',
    'SITE',
    'PAFE',
    'AFPROTECHS',
  ];

  @override
  void initState() {
    super.initState();
    _viewerDepartment = (UserSession.department ?? '').trim();
    _load();
    _startAutoRefresh();
    _ensureViewerDepartment();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _load(showLoading: false);
    });
  }

  Future<void> _ensureViewerDepartment() async {
    if (_viewerDepartment.isNotEmpty) return;
    try {
      final profile = await _api.getProfile();
      UserSession.setFromResponse(profile);
      final dept = (UserSession.department ?? '').trim();
      if (!mounted || dept.isEmpty) return;
      setState(() {
        _viewerDepartment = dept;
      });
    } catch (_) {
      // Keep default ordering when profile info is unavailable.
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await _api.getResults();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _published = res['published'] != false;
        _message = (res['message'] ?? '').toString();
        _orgTotals = res['org_totals'] is Map ? Map<String, dynamic>.from(res['org_totals']) : <String, dynamic>{};
        _positionTotals = res['position_totals'] is Map ? Map<String, dynamic>.from(res['position_totals']) : <String, dynamic>{};
        _grouped = res['grouped'] is List
            ? (res['grouped'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        _chartAnimSeed++;
      });
    } catch (e) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  String _formatPercent(double ratio) {
    final p = (ratio * 100).clamp(0, 100);
    final rounded = p.roundToDouble();
    if ((p - rounded).abs() < 0.05) return '${rounded.toInt()}%';
    return '${p.toStringAsFixed(1)}%';
  }

  String _candidateName(Map<String, dynamic> c) {
    final first = (c['first_name'] ?? '').toString().trim();
    final middle = (c['middle_name'] ?? '').toString().trim();
    final last = (c['last_name'] ?? '').toString().trim();
    final joined = [first, if (middle.isNotEmpty) middle, last].where((x) => x.isNotEmpty).join(' ').trim();
    return joined.isNotEmpty ? joined : (c['name'] ?? 'Candidate').toString();
  }

  Widget _candidateAvatar({
    required dynamic photoUrlRaw,
    required bool isDark,
  }) {
    final photo = resolvedCandidatePhotoUrl(photoUrlRaw);
    final stroke = isDark ? Colors.white24 : const Color(0xFFD7D7D7);
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: stroke, width: 1.5)),
      padding: const EdgeInsets.all(1),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: isDark ? Colors.white12 : const Color(0xFFEAF1FF),
        backgroundImage: photo != null ? NetworkImage(photo) : null,
        child: photo == null ? Icon(Icons.person, size: 13, color: isDark ? Colors.white54 : Colors.black54) : null,
      ),
    );
  }

  Color _orgColor(String org) {
    switch (org.toUpperCase().trim()) {
      case 'AFPROTECHS':
        return const Color(0xFFEC4899);
      case 'SITE':
        return const Color(0xFF7F1D1D);
      case 'PAFE':
        return const Color(0xFF2563EB);
      case 'USG':
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFF64748B);
    }
  }

  int _positionOrderIndex(String position) {
    final p = position.toLowerCase();
    if (p.contains('president') && !p.contains('vice')) return 0;
    if (p.contains('vice') && p.contains('president')) return 1;
    if (p.contains('general') && p.contains('secret')) return 2;
    if (p.contains('associate') && p.contains('secret')) return 3;
    if (p.contains('treasurer') || p.contains('treas')) return 4;
    if (p.contains('auditor') || p.contains('audit')) return 5;
    if (p.contains('public information officer') || p.contains('p.i.o') || p.contains('pio')) return 6;
    if (p.contains('representative') || p.contains('rep')) return 7;
    return 99;
  }

  String _normalizeToken(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String? _preferredOrganizationFromDepartment(String? departmentRaw) {
    final department = _normalizeToken((departmentRaw ?? '').trim());
    if (department.isEmpty) return null;

    if (department.contains('BSIT')) return 'SITE';
    if (department.contains('BTLED')) return 'PAFE';
    if (department.contains('BFPT')) return 'AFPROTECHS';
    return null;
  }

  int _organizationPriority({
    required String orgName,
    required String? preferredOrganization,
  }) {
    final normalizedOrg = _normalizeToken(orgName);
    if (normalizedOrg == 'USG') return 0;
    if (preferredOrganization != null && normalizedOrg == _normalizeToken(preferredOrganization)) return 1;
    return 2;
  }

  Map<String, Map<String, List<Map<String, dynamic>>>> _byOrganizationPosition() {
    final out = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final party in _grouped) {
      final orgsRaw = party['organizations'];
      final orgs = orgsRaw is List
          ? orgsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      for (final org in orgs) {
        final orgName = (org['organization'] ?? '').toString().trim();
        if (orgName.isEmpty) continue;
        out.putIfAbsent(orgName, () => <String, List<Map<String, dynamic>>>{});
        final positionsRaw = org['positions'];
        final positions = positionsRaw is List
            ? positionsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        for (final pos in positions) {
          final posLabel = (pos['position'] ?? '').toString().trim();
          if (posLabel.isEmpty) continue;
          out[orgName]!.putIfAbsent(posLabel, () => <Map<String, dynamic>>[]);
          final candidatesRaw = pos['candidates'];
          final candidates = candidatesRaw is List
              ? candidatesRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : <Map<String, dynamic>>[];
          out[orgName]![posLabel]!.addAll(candidates);
        }
      }
    }
    // Sort candidates by votes DESC for easy comparison
    for (final posMap in out.values) {
      for (final cands in posMap.values) {
        cands.sort((a, b) => _toInt(b['votes']).compareTo(_toInt(a['votes'])));
      }
    }
    return out;
  }

  void _toggleOrgExpanded(String orgName) {
    setState(() {
      if (_expandedOrgNames.contains(orgName)) {
        _expandedOrgNames.remove(orgName);
      } else {
        _expandedOrgNames.add(orgName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white70 : const Color(0xFF5C5C5C);
    final card = isDark ? const Color(0xFF2A2A35) : Colors.white;
    final border = isDark ? Colors.white12 : const Color(0xFFE0E0E0);
    final pageBg = isDark ? const Color(0xFF171620) : const Color(0xFFF2F3F5);
    final trackGrey = isDark ? Colors.white12 : const Color(0xFFE8E9EC);

    if (_loading) {
      return ColoredBox(
        color: pageBg,
        child: Center(child: CircularProgressIndicator(color: fg)),
      );
    }

    if (_error != null) {
      return ColoredBox(
        color: pageBg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: sub),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: sub)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _load,
                  style: FilledButton.styleFrom(backgroundColor: fg, foregroundColor: isDark ? Colors.black : Colors.white),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_published) {
      return ColoredBox(
        color: pageBg,
        child: RefreshIndicator(
          color: Colors.black,
          backgroundColor: Colors.white,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bar_chart_outlined, size: 56, color: sub),
                        const SizedBox(height: 16),
                        Text(
                          'Results',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: fg),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _message.isNotEmpty ? _message : 'Results are not yet available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: sub, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalVotes = _orgTotals.values.fold<int>(0, (sum, v) => sum + _toInt(v));
    final orgEntries = _orgTotals.entries.toList()..sort((a, b) => _toInt(b.value).compareTo(_toInt(a.value)));
    final positionEntries = _positionTotals.entries.toList()
      ..sort((a, b) {
        final ai = _positionOrderIndex(a.key);
        final bi = _positionOrderIndex(b.key);
        if (ai != bi) return ai.compareTo(bi);
        return a.key.compareTo(b.key);
      });
    final maxPositionVotes = positionEntries.isEmpty ? 1 : _toInt(positionEntries.first.value).clamp(1, 1 << 30);
    final organizationsByPosition = _byOrganizationPosition();
    final preferredOrganization = _preferredOrganizationFromDepartment(_viewerDepartment);
    var orderedOrganizationEntries = organizationsByPosition.entries.toList()
      ..sort((a, b) {
        final aPriority = _organizationPriority(orgName: a.key, preferredOrganization: preferredOrganization);
        final bPriority = _organizationPriority(orgName: b.key, preferredOrganization: preferredOrganization);
        if (aPriority != bPriority) return aPriority.compareTo(bPriority);

        final av = _toInt(_orgTotals[a.key]);
        final bv = _toInt(_orgTotals[b.key]);
        if (av != bv) return bv.compareTo(av);
        return a.key.compareTo(b.key);
      });

    if (_orgFilter != 'ALL') {
      orderedOrganizationEntries =
          orderedOrganizationEntries.where((e) => _normalizeToken(e.key) == _normalizeToken(_orgFilter)).toList();
    }

    final showVotesByPosition = _orgFilter == 'ALL';

    return ColoredBox(
      color: pageBg,
      child: RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = math.min(constraints.maxWidth, 560.0);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 12, 16, math.max(MediaQuery.paddingOf(context).bottom + 16, 24)),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Election Results', style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time tally from ELECOM database',
                          style: TextStyle(color: sub, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 14),

                        /// Overview card (compact donut)
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Overall Vote Distribution', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 10),
                              if (orgEntries.isEmpty)
                                Text('No votes recorded yet.', style: TextStyle(color: sub, fontSize: 13))
                              else ...[
                                Center(
                                  child: SizedBox(
                                    width: 148,
                                    height: 148,
                                    child: TweenAnimationBuilder<double>(
                                      key: ValueKey('donut_$_chartAnimSeed'),
                                      duration: const Duration(milliseconds: 650),
                                      curve: Curves.easeOutCubic,
                                      tween: Tween<double>(begin: 0, end: 1),
                                      builder: (context, t, _) => Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CustomPaint(
                                            size: const Size(148, 148),
                                            painter: _DonutChartPainter(
                                              values: orgEntries.map((e) => _toInt(e.value).toDouble()).toList(),
                                              colors: orgEntries.map((e) => _orgColor(e.key)).toList(),
                                              trackColor: isDark ? Colors.white12 : Colors.black12,
                                              progress: t,
                                              strokeWidth: 16,
                                            ),
                                          ),
                                          Opacity(
                                            opacity: t,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('$totalVotes', style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 26)),
                                                Text('Total Votes', style: TextStyle(color: sub, fontWeight: FontWeight.w700, fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(builder: (context, legConstraints) {
                                  final w = legConstraints.maxWidth.isFinite ? legConstraints.maxWidth : 320.0;
                                  final half = math.max((w - 8) / 2, 120.0);
                                  return Wrap(
                                    alignment: WrapAlignment.start,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: orgEntries.map((e) => _LegendChip(
                                      label: '${e.key}  ·  ${_toInt(e.value)}',
                                      color: _orgColor(e.key),
                                      textColor: fg,
                                      borderColor: border,
                                      maxChipWidth: half,
                                    )).toList(),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),

                        /// Organization filters
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _fixedOrgFilters.map((filterKey) {
                              final selected = filterKey == 'ALL'
                                  ? (_orgFilter == 'ALL')
                                  : (_normalizeToken(_orgFilter) == _normalizeToken(filterKey));
                              final label = filterKey == 'ALL' ? 'All' : filterKey;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: selected ? (isDark ? Colors.white : Colors.white) : (isDark ? Colors.white70 : sub),
                                      ),
                                    ),
                                  ),
                                  selected: selected,
                                  showCheckmark: false,
                                  backgroundColor: isDark ? Colors.white10 : Colors.white,
                                  selectedColor: isDark ? Colors.white24 : Colors.black87,
                                  side: BorderSide(color: selected ? Colors.transparent : border),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (_) {
                                    setState(() => _orgFilter = filterKey);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        /// Helper — percentages
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
                          child: Text(
                            'Percentages are based on votes cast for each position.',
                            style: TextStyle(color: sub, fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
                          ),
                        ),

                        if (showVotesByPosition) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Votes by Position', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
                                const SizedBox(height: 10),
                                if (positionEntries.isEmpty)
                                  Text('No position data yet.', style: TextStyle(color: sub, fontSize: 13))
                                else
                                  ...positionEntries.asMap().entries.map((entry) {
                                    final e = entry.value;
                                    final votes = _toInt(e.value);
                                    final ratio = votes / maxPositionVotes;
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: entry.key == positionEntries.length - 1 ? 0 : 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  e.key,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13),
                                                ),
                                              ),
                                              Text(
                                                _formatPercent(ratio),
                                                style: TextStyle(color: sub, fontWeight: FontWeight.w700, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          TweenAnimationBuilder<double>(
                                            key: ValueKey('position_${entry.key}_$_chartAnimSeed'),
                                            duration: Duration(milliseconds: 500 + (entry.key * 50)),
                                            curve: Curves.easeOutCubic,
                                            tween: Tween<double>(begin: 0, end: ratio.clamp(0, 1)),
                                            builder: (context, v, _) => ClipRRect(
                                              borderRadius: BorderRadius.circular(99),
                                              child: LinearProgressIndicator(
                                                value: v,
                                                minHeight: 4,
                                                backgroundColor: trackGrey,
                                                color: fg,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],

                        /// Organization cards
                        const SizedBox(height: 12),
                        if (orderedOrganizationEntries.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              _orgFilter == 'ALL'
                                  ? 'No organization results loaded yet.'
                                  : 'No results for ${_orgFilter == 'ALL' ? '' : _orgFilter} yet.',
                              style: TextStyle(color: sub, fontWeight: FontWeight.w600),
                            ),
                          )
                        else
                          ...orderedOrganizationEntries.map((orgEntry) {
                            final orgName = orgEntry.key;
                            final posMap = orgEntry.value;
                            final orgVotes = _toInt(_orgTotals[orgName]);
                            final orgColor = _orgColor(orgName);
                            final expanded = _expandedOrgNames.contains(orgName);
                            final sortedPosEntries = posMap.entries.toList()
                              ..sort((a, b) {
                                final ai = _positionOrderIndex(a.key);
                                final bi = _positionOrderIndex(b.key);
                                if (ai != bi) return ai.compareTo(bi);
                                return a.key.compareTo(b.key);
                              });

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _toggleOrgExpanded(orgName),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 3,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: orgColor,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    orgName,
                                                    style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 17, height: 1.05),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '$orgVotes votes',
                                                    style: TextStyle(color: sub, fontWeight: FontWeight.w600, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              expanded ? Icons.expand_less : Icons.expand_more,
                                              color: sub,
                                              size: 26,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  AnimatedCrossFade(
                                    firstChild: const SizedBox(width: double.infinity, height: 0),
                                    secondChild: Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: sortedPosEntries.map((posEntry) {
                                          final posLabel = posEntry.key;
                                          final candidates = posEntry.value;
                                          if (candidates.isEmpty) return const SizedBox.shrink();
                                          final topVotes = _toInt(candidates.first['votes']).clamp(1, 1 << 30);
                                          final totalVotesForPosition =
                                              candidates.fold<int>(0, (sum, cand) => sum + _toInt(cand['votes'])).clamp(1, 1 << 30);
                                          final isRepresentative =
                                              posLabel.toLowerCase().contains('representative') || posLabel.toLowerCase().contains('rep');
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  posLabel,
                                                  style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.1),
                                                ),
                                                const SizedBox(height: 8),
                                                ...candidates.asMap().entries.map((candidateEntry) {
                                                  final candidateIndex = candidateEntry.key;
                                                  final c = candidateEntry.value;
                                                  final name = _candidateName(c);
                                                  final party = (c['party_name'] ?? '').toString().trim();
                                                  final votes = _toInt(c['votes']);
                                                  final ratio = isRepresentative ? (votes / topVotes) : (votes / totalVotesForPosition);
                                                  final clampedRatio = ratio.clamp(0.0, 1.0).toDouble();
                                                  final photoUrl = c['photo_url'];
                                                  final barColor = votes == 0 ? (isDark ? Colors.white24 : const Color(0xFFC7C8CC)) : orgColor;
                                                  return Padding(
                                                    padding: EdgeInsets.only(bottom: candidateIndex == candidates.length - 1 ? 0 : 10),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            _candidateAvatar(photoUrlRaw: photoUrl, isDark: isDark),
                                                            const SizedBox(width: 10),
                                                            Expanded(
                                                              child: Align(
                                                                alignment: Alignment.centerLeft,
                                                                child: Text(
                                                                  name,
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Column(
                                                              crossAxisAlignment: CrossAxisAlignment.end,
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Text(
                                                                  '$votes',
                                                                  style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14),
                                                                ),
                                                                Text(
                                                                  _formatPercent(ratio),
                                                                  style: TextStyle(color: sub, fontWeight: FontWeight.w600, fontSize: 11),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                        if (party.isNotEmpty) ...[
                                                          const SizedBox(height: 2),
                                                          Padding(
                                                            padding: const EdgeInsets.only(left: 38),
                                                            child: Text(
                                                              party,
                                                              style: TextStyle(color: sub, fontSize: 11, fontWeight: FontWeight.w500),
                                                            ),
                                                          ),
                                                        ],
                                                        const SizedBox(height: 6),
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 38),
                                                          child: TweenAnimationBuilder<double>(
                                                            key: ValueKey(
                                                              'candidate_${orgName}_${posLabel}_${name}_$candidateIndex$_chartAnimSeed',
                                                            ),
                                                            duration: Duration(milliseconds: 400 + (candidateIndex * 70)),
                                                            curve: Curves.easeOutCubic,
                                                            tween: Tween<double>(begin: 0, end: clampedRatio),
                                                            builder: (context, animatedValue, _) => ClipRRect(
                                                              borderRadius: BorderRadius.circular(99),
                                                              child: LinearProgressIndicator(
                                                                value: votes == 0 ? 0 : animatedValue,
                                                                minHeight: 3,
                                                                backgroundColor: trackGrey,
                                                                color: barColor,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                    duration: const Duration(milliseconds: 220),
                                  ),
                                ],
                              ),
                            );
                          }),

                        SizedBox(height: MediaQuery.paddingOf(context).bottom),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
    required this.textColor,
    required this.borderColor,
    required this.maxChipWidth,
  });

  final String label;
  final Color color;
  final Color textColor;
  final Color borderColor;
  final double maxChipWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 0, maxWidth: maxChipWidth.clamp(80, double.infinity)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
        child: Row(
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
    required this.progress,
    this.strokeWidth = 24,
  });

  final List<double> values;
  final List<Color> colors;
  final Color trackColor;
  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2 - 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, trackPaint);

    final total = values.fold<double>(0, (sum, v) => sum + v);
    if (total <= 0 || values.isEmpty) return;

    double start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v <= 0) continue;
      final sweep = ((v / total) * math.pi * 2) * progress.clamp(0, 1);
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
