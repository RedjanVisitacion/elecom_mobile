import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/elecom_mobile_api.dart';

class ElectionTransparencyScreen extends StatefulWidget {
  const ElectionTransparencyScreen({super.key});

  @override
  State<ElectionTransparencyScreen> createState() =>
      _ElectionTransparencyScreenState();
}

class _ElectionTransparencyScreenState
    extends State<ElectionTransparencyScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = <String, dynamic>{};
  List<Map<String, dynamic>> _blocks = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await _api.getVoteLedger();
      final summary = res['summary'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(res['summary'] as Map<String, dynamic>)
          : <String, dynamic>{};
      final blocksRaw = res['blocks'];
      final blocks = blocksRaw is List
          ? blocksRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _blocks = blocks;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load public ledger.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _s(Map<String, dynamic> x, String key, {String fallback = '-'}) {
    final v = x[key];
    if (v == null) return fallback;
    final out = v.toString().trim();
    return out.isEmpty ? fallback : out;
  }

  int _n(Map<String, dynamic> x, String key) {
    final v = x[key];
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF171620) : const Color(0xFFF3F4F6);
    final card = isDark ? const Color(0xFF2A2A35) : Colors.white;
    final border = isDark ? Colors.white12 : const Color(0xFFDADCE0);
    final fg = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final statusValid =
        _s(_summary, 'ledger_status', fallback: 'unknown').toLowerCase() ==
        'valid';
    final statusColor = statusValid
        ? const Color(0xFF1E8E3E)
        : const Color(0xFFD97706);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Election Transparency',
          style: TextStyle(color: fg, fontWeight: FontWeight.w900),
        ),
        iconTheme: IconThemeData(color: fg),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.26 : 0.10,
                          ),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: statusColor.withValues(
                            alpha: isDark ? 0.08 : 0.05,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white10
                                          : const Color(0xFFF5F1E3),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: statusColor.withValues(
                                          alpha: 0.55,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.verified_user_outlined,
                                      color: statusColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Secured by Vote Ledger',
                                      style: TextStyle(
                                        color: fg,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Vote blocks are linked with cryptographic hashes to help detect tampering.',
                                style: TextStyle(
                                  color: sub,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'A hash is a digital fingerprint used to detect changes in vote records.',
                                style: TextStyle(
                                  color: sub,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_error != null)
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFD97706),
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              else ...[
                                _line(
                                  label: 'Ledger Status',
                                  value: _s(_summary, 'ledger_status'),
                                  valueColor:
                                      _s(
                                            _summary,
                                            'ledger_status',
                                          ).toLowerCase() ==
                                          'valid'
                                      ? const Color(0xFF1E8E3E)
                                      : const Color(0xFFD97706),
                                  sub: sub,
                                ),
                                _line(
                                  label: 'Total Vote Blocks',
                                  value: _voteBlockText(
                                    _n(_summary, 'total_vote_blocks'),
                                  ),
                                  sub: sub,
                                ),
                                _line(
                                  label: 'Latest Hash',
                                  value: _s(_summary, 'latest_hash'),
                                  sub: sub,
                                ),
                                _line(
                                  label: 'Active Validator Nodes',
                                  value: _n(
                                    _summary,
                                    'active_validator_nodes',
                                  ).toString(),
                                  sub: sub,
                                ),
                                _line(
                                  label: 'Consensus Result',
                                  value: _s(
                                    _summary,
                                    'consensus_result',
                                    fallback: '-',
                                  ),
                                  sub: sub,
                                ),
                                _line(
                                  label: 'Latest Block Status',
                                  value: _s(
                                    _summary,
                                    'latest_block_status',
                                    fallback: '-',
                                  ),
                                  valueColor:
                                      _s(
                                            _summary,
                                            'latest_block_status',
                                            fallback: '',
                                          ).toLowerCase() ==
                                          'accepted'
                                      ? const Color(0xFF1E8E3E)
                                      : const Color(0xFFD97706),
                                  sub: sub,
                                ),
                                _line(
                                  label: 'Last Verified',
                                  value: _formatDisplayDate(
                                    _s(_summary, 'last_verified'),
                                  ),
                                  sub: sub,
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                'Vote choices and student identities are kept private. Only public verification hashes are shown.',
                                style: TextStyle(
                                  color: sub,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!_loading && _error == null)
                ..._blocks.map((b) {
                  final blockId = _n(b, 'id');
                  final previousHash = _s(b, 'previous_hash');
                  final linkedLabel = previousHash == '-'
                      ? 'Linked to previous block'
                      : 'Linked to Block #${blockId > 1 ? blockId - 1 : blockId}';
                  final isValid =
                      _s(b, 'status', fallback: 'valid').toLowerCase() ==
                      'valid';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Block #$blockId',
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            linkedLabel,
                            style: TextStyle(
                              color: sub,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Hash:',
                            style: TextStyle(
                              color: sub,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _s(b, 'hash'),
                                  style: TextStyle(
                                    color: sub,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                onPressed: () async {
                                  final fullHash = _s(
                                    b,
                                    'hash_full',
                                    fallback: _s(b, 'hash'),
                                  );
                                  if (fullHash == '-') return;
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await Clipboard.setData(
                                    ClipboardData(text: fullHash),
                                  );
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Hash copied.'),
                                      duration: Duration(milliseconds: 1200),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: sub,
                                ),
                                tooltip: 'Copy hash',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minHeight: 28,
                                  minWidth: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Previous: $previousHash',
                            style: TextStyle(
                              color: sub,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Submitted: ${_formatDisplayDate(_s(b, 'submitted_at'))}',
                            style: TextStyle(
                              color: sub,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Status: ${isValid ? 'Valid' : 'Warning'}',
                            style: TextStyle(
                              color: isValid
                                  ? const Color(0xFF1E8E3E)
                                  : const Color(0xFFD97706),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _s(
                              b,
                              'node_validation_result',
                              fallback: '0/0 nodes approved',
                            ),
                            style: TextStyle(
                              color: sub,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Block status: ${_s(b, 'block_status', fallback: 'pending')}',
                            style: TextStyle(
                              color:
                                  _s(
                                        b,
                                        'block_status',
                                        fallback: '',
                                      ).toLowerCase() ==
                                      'accepted'
                                  ? const Color(0xFF1E8E3E)
                                  : const Color(0xFFD97706),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line({
    required String label,
    required String value,
    required Color sub,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: sub, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color:
                    valueColor ??
                    (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black),
                fontWeight: FontWeight.w900,
                fontSize: label == 'Last Verified' ? 13 : 14.5,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDisplayDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text == '-') return '-';
    final hasOffset = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text);
    final normalized = hasOffset ? text : '${text}Z';
    final dt = DateTime.tryParse(normalized);
    if (dt == null) return text;
    return DateFormat('MMM d, y · h:mm a').format(dt.toLocal());
  }

  String _voteBlockText(int total) {
    if (total == 1) return '1 vote block';
    return '$total vote blocks';
  }
}
