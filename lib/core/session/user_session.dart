class UserSession {
  static String? studentId;
  static String? fullName;
  static String? role;
  static String? department;
  static String? position;
  static String? lastReceiptId;
  static Map<String, String>? lastReceiptSelections;
  static String? lastReceiptStudentId;

  static void setFromResponse(Map<String, dynamic> res) {
    final user = res['user'] is Map<String, dynamic> ? (res['user'] as Map<String, dynamic>) : const <String, dynamic>{};
    final student = res['student'] is Map<String, dynamic> ? (res['student'] as Map<String, dynamic>) : const <String, dynamic>{};

    final newId = (res['student_id'] ?? res['studentId'] ?? res['id'] ?? user['student_id'] ?? user['studentId'] ?? student['student_id'] ?? student['studentId'] ?? student['id'] ?? '').toString();
    final oldId = studentId;
    studentId = newId;

    final directName = (res['full_name'] ?? res['fullName'] ?? res['name'] ?? res['username'] ?? user['full_name'] ?? user['fullName'] ?? user['name'] ?? user['username'] ?? student['full_name'] ?? student['fullName'] ?? student['name'] ?? '')
        .toString()
        .trim();

    final first = (student['first_name'] ?? student['firstName'] ?? res['first_name'] ?? res['firstName'] ?? '').toString().trim();
    final middle = (student['middle_name'] ?? student['middleName'] ?? res['middle_name'] ?? res['middleName'] ?? '').toString().trim();
    final last = (student['last_name'] ?? student['lastName'] ?? res['last_name'] ?? res['lastName'] ?? '').toString().trim();

    final built = [first, middle, last].where((p) => p.isNotEmpty).join(' ').trim();
    final finalName = directName.isNotEmpty ? directName : built;
    fullName = finalName.isEmpty ? null : finalName;

    role = (res['role'] ?? user['role'] ?? '').toString();
    department = (res['department'] ?? user['department'] ?? student['department'] ?? '').toString();
    position = (res['position'] ?? user['position'] ?? student['position'] ?? '').toString();
    if (oldId != null && oldId != newId) {
      lastReceiptId = null;
      lastReceiptSelections = null;
      lastReceiptStudentId = null;
    }
  }

  static void clear() {
    studentId = null;
    fullName = null;
    role = null;
    department = null;
    position = null;
    lastReceiptId = null;
    lastReceiptSelections = null;
    lastReceiptStudentId = null;
  }

  static void setLastReceipt({required String receiptId, required Map<String, String> selections}) {
    lastReceiptId = receiptId;
    lastReceiptSelections = Map<String, String>.from(selections);
    lastReceiptStudentId = studentId;
  }
}
