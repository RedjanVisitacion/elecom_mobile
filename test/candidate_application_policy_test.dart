import 'package:elecom_mobile/features/elecom/data/candidate_application_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial rejection allows a corrected filing', () {
    expect(canFileCandidateApplicationAgain({'status': 'rejected'}), isTrue);
    expect(
      canFileCandidateApplicationAgain({
        'status': 'rejected',
        'requirements_submitted_at': null,
        'requirements_photo_url': '',
      }),
      isTrue,
    );
  });

  test('follow-up rejection blocks another filing', () {
    for (final field in [
      'requirements_submitted_at',
      'requirements_photo_url',
      'enrollment_certificate_url',
      'grades_url',
      'good_moral_url',
    ]) {
      expect(
        canFileCandidateApplicationAgain({
          'status': 'rejected',
          field: 'saved',
        }),
        isFalse,
        reason: field,
      );
    }
  });

  test('honors a server restriction even without document metadata', () {
    expect(
      canFileCandidateApplicationAgain({
        'status': 'rejected',
        'can_file_again': false,
      }),
      isFalse,
    );
  });

  test('an allowed flag cannot bypass the follow-up rejection rule', () {
    expect(
      canFileCandidateApplicationAgain({
        'status': 'rejected',
        'can_file_again': true,
        'requirements_submitted_at': '2026-10-06T23:55:00',
      }),
      isFalse,
    );
  });

  test('other statuses cannot start a second filing', () {
    for (final status in [
      'pending',
      'requirements_pending',
      'requirements_review',
      'approved',
    ]) {
      expect(canFileCandidateApplicationAgain({'status': status}), isFalse);
    }
  });
}
