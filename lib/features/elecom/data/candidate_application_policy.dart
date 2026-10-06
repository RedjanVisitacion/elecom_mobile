/// Initial filing rejections can be corrected. Rejections after the follow-up
/// document stage close the filing for that election.
bool canFileCandidateApplicationAgain(Map<String, dynamic> application) {
  final status = (application['status'] ?? '').toString().trim().toLowerCase();
  if (status != 'rejected') return false;
  if (application['can_file_again'] == false) return false;
  const followUpFields = [
    'requirements_submitted_at',
    'requirements_photo_url',
    'enrollment_certificate_url',
    'grades_url',
    'good_moral_url',
  ];
  return !followUpFields.any(
    (field) => (application[field] ?? '').toString().trim().isNotEmpty,
  );
}
