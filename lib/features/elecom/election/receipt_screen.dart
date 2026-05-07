import 'package:flutter/material.dart';

import '../candidates/candidate_profile_screen.dart';
import '../data/elecom_mobile_api.dart';

/// Shows the vote receipt for the currently logged-in student.
/// Displayed in the Receipt tab of the dashboard once the user has voted.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _receipt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final voteStatus = await _api.getVoteStatus();
      if (!mounted) return;
      if (voteStatus['ok'] != true || voteStatus['voted'] != true) {
        setState(() {
          _loading = false;
          _receipt = null;
        });
        return;
      }
      final res = await _api.getVoteReceipt();
      if (!mounted) return;
      if (res['ok'] != true) {
        setState(() {
          _loading = false;
          _error = (res['error'] ?? 'Could not load receipt.').toString();
        });
        return;
      }
      final raw = res['receipt'];
      setState(() {
        _loading = false;
        _receipt = raw is Map ? Map<String, dynamic>.from(raw) : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _formatDate(String? iso) {
    final raw = (iso ?? '').trim();
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final l = dt.isUtc ? dt.toLocal() : dt;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.white70 : Colors.black54;
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFD7D7D7);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: fg));
    }

    if (_error != null) {
      return Center(
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
                style: FilledButton.styleFrom(backgroundColor: fg, foregroundColor: isDark ? Colors.black : Colors.white),
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_receipt == null) {
      return RefreshIndicator(
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
                      Icon(Icons.receipt_long_outlined, size: 56, color: sub),
                      const SizedBox(height: 16),
                      Text(
                        'No receipt yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: fg),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your vote receipt will appear here after you have cast your vote.',
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
      );
    }

    final receipt = _receipt!;
    final ref = (receipt['reference_number'] ?? '').toString().trim();
    final votedAt = _formatDate((receipt['voted_at'] ?? '').toString());
    final totalSelections = receipt['total_selections'];

    final selectionsRaw = receipt['selections'];
    final selections = selectionsRaw is Map ? Map<String, dynamic>.from(selectionsRaw) : <String, dynamic>{};

    final candidatesRaw = receipt['candidates'];
    final candidates = candidatesRaw is Map ? Map<String, dynamic>.from(candidatesRaw) : <String, dynamic>{};

    final ballotDataRaw = receipt['ballot_data'];
    final ballotData = ballotDataRaw is Map ? Map<String, dynamic>.from(ballotDataRaw) : <String, dynamic>{};
    final ballotRaw = ballotData['ballot'];
    final ballot = ballotRaw is List
        ? ballotRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    Widget avatarFor(dynamic photoUrlRaw) {
      final photo = resolvedCandidatePhotoUrl(photoUrlRaw);
      final stroke = isDark ? Colors.white24 : const Color(0xFFD7D7D7);
      return Container(
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: stroke, width: 2)),
        padding: const EdgeInsets.all(1.5),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: isDark ? Colors.white12 : const Color(0xFFEAF1FF),
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null ? Icon(Icons.person, size: 18, color: isDark ? Colors.white54 : Colors.black54) : null,
        ),
      );
    }

    // Build ordered position keys from ballot_data, same as election order.
    List<String> orderedPositionKeys() {
      if (ballot.isNotEmpty) {
        final keys = <String>[];
        for (final org in ballot) {
          final orgName = (org['organization'] ?? '').toString().trim();
          final positionsRaw = org['positions'];
          if (orgName.isEmpty || positionsRaw is! List) continue;
          for (final p in positionsRaw.whereType<Map>()) {
            final posName = (p['position'] ?? '').toString().trim();
            if (posName.isNotEmpty) keys.add('$orgName::$posName');
          }
        }
        return keys;
      }
      return selections.keys.map((k) => k.toString()).toList();
    }

    final posKeys = orderedPositionKeys();

    List<Widget> buildSummary() {
      final widgets = <Widget>[];
      final emitted = <String>{};
      for (final posKey in posKeys) {
        if (emitted.contains(posKey)) continue;
        emitted.add(posKey);

        final v = selections[posKey];
        final ids = v is List
            ? v.map((e) => e.toString()).where((x) => x.isNotEmpty).toList()
            : <String>[v?.toString() ?? ''].where((x) => x.isNotEmpty).toList();
        if (ids.isEmpty) continue;

        final orgLabel = posKey.contains('::') ? posKey.split('::').first.trim() : '';
        final posLabel = posKey.contains('::') ? posKey.split('::').last.trim() : posKey;

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(posLabel, style: TextStyle(fontWeight: FontWeight.w900, color: fg, fontSize: 13.5)),
          ),
        );

        for (final id in ids) {
          final candRaw = candidates[id];
          final cand = candRaw is Map ? Map<String, dynamic>.from(candRaw) : <String, dynamic>{};
          final name = (cand['name'] ?? '').toString().trim();
          final party = (cand['party_name'] ?? '').toString().trim();
          final photoUrl = cand['photo_url'];
          final subtitle = [if (party.isNotEmpty) party, if (orgLabel.isNotEmpty) orgLabel].join(' · ');

          widgets.add(
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  avatarFor(photoUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Candidate' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.15),
                        ),
                        if (subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: sub, fontWeight: FontWeight.w500, fontSize: 12),
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
      return widgets;
    }

    return RefreshIndicator(
      color: Colors.black,
      backgroundColor: Colors.white,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
              color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF9F9F9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: const Color(0xFF2E7D32), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Vote successfully recorded',
                      style: TextStyle(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _metaRow('Reference', ref, fg, sub),
                const SizedBox(height: 6),
                _metaRow('Voted at', votedAt, fg, sub),
                const SizedBox(height: 6),
                if (totalSelections != null) _metaRow('Selections', totalSelections.toString(), fg, sub),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Summary', style: TextStyle(fontWeight: FontWeight.w900, color: fg, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Your selected candidates per position.',
            style: TextStyle(color: sub, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
          ...buildSummary(),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value, Color fg, Color sub) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(color: sub, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
      ],
    );
  }
}
