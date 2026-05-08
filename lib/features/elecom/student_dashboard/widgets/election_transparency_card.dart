import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ElectionTransparencyCard extends StatelessWidget {
  const ElectionTransparencyCard({
    super.key,
    required this.summary,
    required this.isLoading,
    required this.onTapViewLedger,
  });

  final Map<String, dynamic>? summary;
  final bool isLoading;
  final VoidCallback onTapViewLedger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white70 : Colors.black54;
    final cardColor = isDark ? const Color(0xFF2A2A35) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    final ledgerStatus = _readStr(
      summary,
      'ledger_status',
      fallback: 'Unknown',
    );
    final statusValid = ledgerStatus.toLowerCase() == 'valid';
    final statusColor = statusValid
        ? const Color(0xFF1E8E3E)
        : const Color(0xFFD97706);
    final totalBlocks = _readInt(summary, 'total_vote_blocks');
    final voteRecordText = totalBlocks == 1
        ? '1 vote record'
        : '$totalBlocks vote records';
    final latestHash = _readStr(summary, 'latest_hash', fallback: '-');
    final lastVerified = _formatDisplayDate(
      _readStr(summary, 'last_verified', fallback: '-'),
    );
    final preview = _readList(summary, 'preview_blocks');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Election Transparency',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_outlined, color: statusColor),
                        const SizedBox(width: 8),
                        Text(
                          'Secured by Vote Ledger',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vote records are linked with cryptographic hashes to help detect tampering.',
                      style: TextStyle(
                        color: subColor,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _kv(
                      label: 'Ledger Status',
                      value: ledgerStatus,
                      valueColor: statusColor,
                      subColor: subColor,
                      textColor: titleColor,
                    ),
                    _kv(
                      label: 'Total Vote Blocks',
                      value: voteRecordText,
                      subColor: subColor,
                      textColor: titleColor,
                    ),
                    _kv(
                      label: 'Latest Hash',
                      value: latestHash,
                      subColor: subColor,
                      textColor: titleColor,
                    ),
                    _kv(
                      label: 'Last Verified',
                      value: lastVerified,
                      subColor: subColor,
                      textColor: titleColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vote choices and student identities are kept private. Only public verification hashes are shown.',
                      style: TextStyle(
                        color: subColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final b in preview.take(1))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _blockPreviewRow(
                            blockNo: _readInt(b, 'id'),
                            hash: _readStr(b, 'hash', fallback: '-'),
                            isValid:
                                _readStr(
                                  b,
                                  'status',
                                  fallback: 'valid',
                                ).toLowerCase() ==
                                'valid',
                            titleColor: titleColor,
                            subColor: subColor,
                          ),
                        ),
                    ],
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onTapViewLedger,
                        icon: Icon(
                          Icons.visibility_outlined,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        label: Text(
                          'View Public Ledger',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _kv({
    required String label,
    required String value,
    required Color subColor,
    required Color textColor,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: subColor, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? textColor,
                fontWeight: FontWeight.w800,
                fontSize: label == 'Last Verified' ? 13 : 14.5,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockPreviewRow({
    required int blockNo,
    required String hash,
    required bool isValid,
    required Color titleColor,
    required Color subColor,
  }) {
    final statusColor = isValid
        ? const Color(0xFF1E8E3E)
        : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Block #$blockNo',
            style: TextStyle(color: titleColor, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'Hash: $hash',
            style: TextStyle(
              color: subColor,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Status: ${isValid ? 'Valid' : 'Warning'}',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  String _readStr(
    Map<String, dynamic>? source,
    String key, {
    String fallback = '',
  }) {
    if (source == null) return fallback;
    final raw = source[key];
    if (raw == null) return fallback;
    final out = raw.toString().trim();
    return out.isEmpty ? fallback : out;
  }

  int _readInt(Map<String, dynamic>? source, String key) {
    if (source == null) return 0;
    final raw = source[key];
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? ''}') ?? 0;
  }

  List<Map<String, dynamic>> _readList(
    Map<String, dynamic>? source,
    String key,
  ) {
    if (source == null) return const <Map<String, dynamic>>[];
    final raw = source[key];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
}
