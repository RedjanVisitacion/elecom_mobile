import 'package:flutter_test/flutter_test.dart';
import 'package:elecom_mobile/features/elecom/candidates/candidate_certificate_preview_screen.dart';

void main() {
  test('PDF name includes organization and complete candidate name', () {
    expect(
      candidateCertificateFileName(
        organization: 'SITE',
        candidateName: 'Von Joshua Peje',
      ),
      'SITE_Certificate_of_Candidacy_Von_Joshua_Peje.pdf',
    );
  });

  test('filenames remove path separators and preserve names with accents', () {
    expect(
      candidateCertificateFileName(
        organization: 'usg',
        candidateName: '  María / Dela\\Cruz:  ',
      ),
      'USG_Certificate_of_Candidacy_María_DelaCruz.pdf',
    );
  });

  test('missing name produces a usable PDF filename', () {
    expect(
      candidateCertificateFileName(organization: '', candidateName: ' '),
      'Candidate_Certificate_of_Candidacy_Candidate.pdf',
    );
  });
}
