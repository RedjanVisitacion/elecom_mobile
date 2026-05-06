import 'package:flutter/material.dart';

import '../candidates/candidate_profile_screen.dart';
import '../data/elecom_mobile_api.dart';

/// Election / voting tab: ballot from [GET /api/mobile/ballot/], submit via [POST /api/mobile/vote/submit/].
/// Program-based organizations and USG representative rows are enforced server-side.
class ElectionScreen extends StatefulWidget {
  const ElectionScreen({super.key});

  @override
  State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();

  bool _loading = true;
  bool _alreadyVoted = false;
  String? _loadError;
  Map<String, dynamic> _ballotPayload = const {};

  final Map<String, dynamic> _selections = {};

  String _positionKey(String org, String position) =>
      '${org.toUpperCase().trim()}::${position.trim()}';

  bool _isMultiSelect(String org, String position) =>
      org.toUpperCase() == 'USG' && position.toUpperCase().contains('REPRESENTATIVE');

  List<Map<String, dynamic>> get _orgList {
    final b = _ballotPayload['ballot'];
    if (b is! List) return <Map<String, dynamic>>[];
    return b.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<String> _eligibleOrganizationLabels() {
    final raw = _ballotPayload['eligible_organizations'];
    if (raw is! List) return <String>[];
    return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final status = await _api.getVoteStatus();
      if (!mounted) return;
      if (status['ok'] == true && status['voted'] == true) {
        setState(() {
          _alreadyVoted = true;
          _loading = false;
          _ballotPayload = const {};
          _selections.clear();
        });
        return;
      }

      final ballot = await _api.getBallot();
      if (!mounted) return;
      if (ballot['ok'] != true) {
        setState(() {
          _loadError = (ballot['error'] ?? 'Could not load ballot').toString();
          _loading = false;
        });
        return;
      }

      setState(() {
        _alreadyVoted = false;
        _ballotPayload = ballot;
        _selections.clear();
        _loading = false;
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

  ElectionThemePalette _electionPalette(BuildContext context, bool isDark) =>
      ElectionThemePalette.fromBrightness(isDark ? Brightness.dark : Brightness.light);

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

  Future<void> _submit(ElectionThemePalette palette) async {
    final payload = _payloadOnlyFilled();
    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: palette.snackNeutral,
          content: Text('Select at least one candidate before submitting.', style: TextStyle(color: palette.snackFg)),
        ),
      );
      return;
    }

    final blankCount = _expectedKeys.length - _filledCount;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final fg = Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black;
        final sub = Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.black54;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          titleTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: fg),
          title: const Text('Confirm your vote'),
          content: SingleChildScrollView(
            child: Text(
              blankCount > 0
                  ? 'You have chosen candidates for $_filledCount of ${_expectedKeys.length} ballot position(s).\n'
                        '$blankCount position(s) will be left blank or skipped.\n\n'
                        'Once you confirm, your vote will be submitted and cannot be changed. Continue?'
                  : 'You are about to submit your ballot with all positions filled.\n\n'
                      'Once you confirm, your vote cannot be changed. Continue?',
              style: TextStyle(color: sub, height: 1.4, fontWeight: FontWeight.w600),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: fg))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: palette.accent),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Continue', style: TextStyle(color: palette.onAccent)),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    try {
      await _api.submitVote(<String, dynamic>{'selections': payload});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: palette.snackNeutral,
          content: Text('Your vote has been recorded.', style: TextStyle(color: palette.snackFg)),
        ),
      );
      await _load();
    } on ElecomApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: palette.snackNeutral,
          content: Text(e.message, style: TextStyle(color: palette.snackFg)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: palette.snackNeutral,
          content: Text(e.toString(), style: TextStyle(color: palette.snackFg)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black),
      );
    }

    if (_alreadyVoted) {
      return RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.how_to_vote_outlined, size: 56, color: subtitleColor),
            const SizedBox(height: 16),
            Text(
              'You have already submitted your vote. You cannot vote again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: titleColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Thank you for participating. You can view your receipt from the Receipt tab when available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
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
              Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: subtitleColor)),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final programCode = (_ballotPayload['program_code'] ?? '').toString().trim();

    final palette = _electionPalette(context, isDark);

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
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: titleColor),
            ),
            const SizedBox(height: 8),
            Text(
              'If you expect to vote, confirm your program is set correctly on your profile.',
              style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
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
        selectedTileColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
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
                  Text(
                    'Election',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor),
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
                  const SizedBox(height: 16),
                  for (final org in _orgList) ..._orgSection(context, org, isDark, palette),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                  ),
                  onPressed: () => _submit(palette),
                  icon: Icon(Icons.how_to_vote_outlined, color: palette.onAccent),
                  label: Text('Submit ballot', style: TextStyle(fontWeight: FontWeight.w800, color: palette.onAccent)),
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
    ElectionThemePalette palette,
  ) {
    final orgName = (org['organization'] ?? '').toString();
    final positions = org['positions'];
    if (positions is! List || orgName.isEmpty) return [];

    final titleColor = isDark ? Colors.white : Colors.black;
    final card = isDark ? const Color(0xFF2A2A35) : Colors.white;
    final border = isDark ? Colors.white38 : Colors.black26;

    final widgets = <Widget>[
      const SizedBox(height: 8),
      Text(
        orgName,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor),
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
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
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
                      style: TextStyle(fontWeight: FontWeight.w800, color: titleColor, fontSize: 15),
                    ),
                  ),
                  if (!multi &&
                      ((_selections[key] != null)))
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : palette.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => setState(() => _selections.remove(key)),
                      child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  if (multi &&
                      ((_selections[key] as List?)?.isNotEmpty ?? false))
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : palette.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => setState(() => _selections.remove(key)),
                      child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w700)),
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
                final id = idVal is int ? idVal : int.tryParse(idVal.toString()) ?? 0;
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
                      backgroundColor: isDark ? Colors.white12 : const Color(0xFFEAF1FF),
                      backgroundImage: photo != null ? NetworkImage(photo) : null,
                      child: photo == null
                          ? Icon(Icons.person, size: 20, color: isDark ? Colors.white54 : palette.accent)
                          : null,
                    ),
                  );
                }

                Widget rowShell({required Widget control, required VoidCallback onTap}) {
                  final rowBorder = isDark ? Colors.white12 : const Color(0xFFD7D7D7);
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                          color: isDark ? Colors.white60 : Colors.black54,
                                          fontSize: 12.5,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(width: 44, child: Align(alignment: Alignment.centerRight, child: control)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (multi) {
                  final list = (_selections[key] as List<dynamic>?)?.map((e) => e as int).toList() ?? <int>[];
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
                      setState(() => _selections[key] = v);
                    },
                  ),
                  onTap: () {
                    if (selected) return;
                    setState(() => _selections[key] = id);
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

  factory ElectionThemePalette.fromBrightness(Brightness b) {
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
