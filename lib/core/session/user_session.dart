class UserSession {
  static String? studentId;
  static String? fullName;
  static String? firstName;
  static String? middleName;
  static String? lastName;
  static String? profilePhotoUrl;
  static String? role;
  static String? department;
  static String? position;
  static String? yearSection;
  static String? lastReceiptId;
  static Map<String, String>? lastReceiptSelections;
  static String? lastReceiptStudentId;

  static void setFromResponse(Map<String, dynamic> res) {
    final user = res['user'] is Map<String, dynamic>
        ? (res['user'] as Map<String, dynamic>)
        : const <String, dynamic>{};
    final student = res['student'] is Map<String, dynamic>
        ? (res['student'] as Map<String, dynamic>)
        : const <String, dynamic>{};

    final newId =
        (res['student_id'] ??
                res['studentId'] ??
                res['id'] ??
                user['student_id'] ??
                user['studentId'] ??
                student['student_id'] ??
                student['studentId'] ??
                student['id'] ??
                '')
            .toString();
    final oldId = studentId;
    studentId = newId;

    final directName =
        (res['full_name'] ??
                res['fullName'] ??
                res['name'] ??
                res['username'] ??
                user['full_name'] ??
                user['fullName'] ??
                user['name'] ??
                user['username'] ??
                student['full_name'] ??
                student['fullName'] ??
                student['name'] ??
                '')
            .toString()
            .trim();

    final first =
        (student['first_name'] ??
                student['firstName'] ??
                res['first_name'] ??
                res['firstName'] ??
                '')
            .toString()
            .trim();
    final middle =
        (student['middle_name'] ??
                student['middleName'] ??
                res['middle_name'] ??
                res['middleName'] ??
                '')
            .toString()
            .trim();
    final last =
        (student['last_name'] ??
                student['lastName'] ??
                res['last_name'] ??
                res['lastName'] ??
                '')
            .toString()
            .trim();

    final built = [
      first,
      middle,
      last,
    ].where((p) => p.isNotEmpty).join(' ').trim();
    final finalName = directName.isNotEmpty ? directName : built;
    fullName = finalName.isEmpty ? null : finalName;
    firstName = first.isEmpty ? null : first;
    middleName = middle.isEmpty ? null : middle;
    lastName = last.isEmpty ? null : last;

    final photo =
        (res['profile_photo_url'] ??
                res['profilePhotoUrl'] ??
                res['photo_url'] ??
                res['photoUrl'] ??
                res['photo'] ??
                res['avatar'] ??
                user['profile_photo_url'] ??
                user['photo_url'] ??
                user['photo'] ??
                student['profile_photo_url'] ??
                student['photo_url'] ??
                student['photo'] ??
                '')
            .toString()
            .trim();
    if (photo.isNotEmpty && photo.toLowerCase() != 'null') {
      profilePhotoUrl = photo;
    }

    role = (res['role'] ?? user['role'] ?? '').toString();
    department =
        (res['department'] ?? user['department'] ?? student['department'] ?? '')
            .toString();
    position =
        (res['position'] ?? user['position'] ?? student['position'] ?? '')
            .toString();
    final directYearSection =
        (res['year_section'] ??
                res['yearSection'] ??
                res['year_and_section'] ??
                res['yearAndSection'] ??
                user['year_section'] ??
                user['yearSection'] ??
                student['year_section'] ??
                student['yearSection'] ??
                '')
            .toString()
            .trim();
    if (directYearSection.isNotEmpty &&
        directYearSection.toLowerCase() != 'null') {
      yearSection = directYearSection;
    } else {
      final year = (res['year'] ?? user['year'] ?? student['year'] ?? '')
          .toString()
          .trim();
      final section =
          (res['section'] ??
                  res['sec'] ??
                  user['section'] ??
                  user['sec'] ??
                  student['section'] ??
                  student['sec'] ??
                  '')
              .toString()
              .trim();
      final combined = [
        year,
        section,
      ].where((part) => part.isNotEmpty).join('-').trim();
      if (combined.isNotEmpty) yearSection = combined;
    }
    if (oldId != null && oldId != newId) {
      lastReceiptId = null;
      lastReceiptSelections = null;
      lastReceiptStudentId = null;
    }
  }

  static void clear() {
    studentId = null;
    fullName = null;
    firstName = null;
    middleName = null;
    lastName = null;
    profilePhotoUrl = null;
    role = null;
    department = null;
    position = null;
    yearSection = null;
    lastReceiptId = null;
    lastReceiptSelections = null;
    lastReceiptStudentId = null;
  }

  static void setLastReceipt({
    required String receiptId,
    required Map<String, String> selections,
  }) {
    lastReceiptId = receiptId;
    lastReceiptSelections = Map<String, String>.from(selections);
    lastReceiptStudentId = studentId;
  }
}
