import 'package:flutter/material.dart';

import '../student_dashboard/student_dashboard.dart';

class ElecomDashboard extends StatelessWidget {
  const ElecomDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudentDashboard(orgName: 'ELECOM', assetPath: 'assets/elecom.png');
  }
}
