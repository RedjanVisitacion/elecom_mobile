import 'dart:convert';

import 'package:crypto/crypto.dart';

class VoteLedgerCrypto {
  VoteLedgerCrypto._();

  static String sha256Hex(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  static String buildAnonymousVoterHash({
    required String studentId,
    required int electionId,
    required String submittedAtIsoUtc,
  }) {
    // Keeps voter identity private in public ledger.
    return sha256Hex('$studentId|$electionId|$submittedAtIsoUtc|elecom');
  }

  static String buildVoteDataHash(Map<String, dynamic> selections) {
    final normalized = <String>[];
    final keys = selections.keys.map((k) => k.toString()).toList()..sort();
    for (final key in keys) {
      final value = selections[key];
      if (value is List) {
        final ints =
            value
                .map((e) => int.tryParse(e.toString()))
                .whereType<int>()
                .toList()
              ..sort();
        normalized.add('$key::${ints.join(",")}');
      } else {
        normalized.add('$key::${value.toString()}');
      }
    }
    return sha256Hex(normalized.join('|'));
  }

  static String buildCurrentHash({
    required int electionId,
    required String anonymousVoterHash,
    required String voteDataHash,
    required String previousHash,
    required String submittedAtIsoUtc,
  }) {
    return sha256Hex(
      '$electionId|$anonymousVoterHash|$voteDataHash|$previousHash|$submittedAtIsoUtc',
    );
  }
}
