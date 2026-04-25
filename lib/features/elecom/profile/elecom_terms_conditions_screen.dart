import 'package:flutter/material.dart';

class ElecomTermsConditionsScreen extends StatelessWidget {
  const ElecomTermsConditionsScreen({super.key});

  Widget _heading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 10,
              child: Text('•', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Terms and Conditions',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        children: [
          Text(
            'ECVS (ELECOM Voting System)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.black54,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Effective Date: April 25, 2026',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
          ),
          _heading(context, '1. LEGAL AGREEMENT'),
          _paragraph(
            context,
            'These Terms and Conditions (“Terms”) constitute a binding agreement between the user (“Student”, “Voter”, or “User”) and the Electoral Commission (ELECOM) of the University of Science and Technology of Southern Philippines – Oroquieta Campus.',
          ),
          _paragraph(
            context,
            'By accessing and using the ECVS mobile application, you confirm that you have read, understood, and agreed to comply with these Terms and all applicable laws and university policies.',
          ),
          _paragraph(
            context,
            'If you do not agree, you must discontinue use of the application.',
          ),
          _heading(context, '2. PURPOSE OF THE PLATFORM'),
          _paragraph(
            context,
            'The Electoral Commission Voting System (ECVS) is designed to:',
          ),
          _bullet(context, 'Facilitate secure student elections'),
          _bullet(context, 'Provide access to candidate information'),
          _bullet(context, 'Enable authorized users to cast votes'),
          _bullet(context, 'Ensure accurate and automated vote counting'),
          _bullet(context, 'Display official election results'),
          _paragraph(
            context,
            'The system is intended strictly for official campus election purposes.',
          ),
          _heading(context, '3. ELIGIBILITY'),
          _paragraph(
            context,
            'To use the system, you must:',
          ),
          _bullet(context, 'Be an officially enrolled student of USTP Oroquieta Campus'),
          _bullet(context, 'Possess a valid Student ID and registered account'),
          _bullet(context, 'Be authorized by ELECOM to participate in the election'),
          _paragraph(
            context,
            'Each user is allowed one (1) vote per election.',
          ),
          _heading(context, '4. USER RESPONSIBILITIES'),
          _paragraph(
            context,
            'Users agree to:',
          ),
          _bullet(context, 'Provide accurate and valid information'),
          _bullet(context, 'Keep login credentials confidential'),
          _bullet(context, 'Use the system only for legitimate voting purposes'),
          _bullet(context, 'Follow election rules and guidelines set by ELECOM'),
          _paragraph(
            context,
            'Users must NOT:',
          ),
          _bullet(context, 'Attempt multiple voting'),
          _bullet(context, 'Share or transfer account access'),
          _bullet(context, 'Manipulate or interfere with the system'),
          _bullet(context, 'Engage in fraudulent or malicious activities'),
          _paragraph(
            context,
            'Violation may result in account suspension and disciplinary action.',
          ),
          _heading(context, '5. VOTING RULES AND SYSTEM USE'),
          _bullet(context, 'Votes cast are final and cannot be changed'),
          _bullet(context, 'Voting access is limited to authorized users only'),
          _bullet(context, 'The system may restrict access based on network or security policies'),
          _bullet(context, 'Election schedules are strictly enforced by ELECOM'),
          _heading(context, '6. DATA PRIVACY AND SECURITY'),
          _paragraph(
            context,
            'User data is collected and processed in accordance with the Data Privacy Act of 2012.',
          ),
          _paragraph(
            context,
            'The system implements:',
          ),
          _bullet(context, 'Secure authentication mechanisms'),
          _bullet(context, 'Encrypted data transmission'),
          _bullet(context, 'Blockchain-based vote recording for integrity'),
          _paragraph(
            context,
            'Users agree that their data will be used solely for election-related purposes.',
          ),
          _heading(context, '7. INTELLECTUAL PROPERTY'),
          _paragraph(
            context,
            'All components of the system, including:',
          ),
          _bullet(context, 'Software design'),
          _bullet(context, 'Source code'),
          _bullet(context, 'Database structures'),
          _bullet(context, 'Interface design'),
          _paragraph(
            context,
            'are the property of the developers and the institution.',
          ),
          _paragraph(
            context,
            'Unauthorized reproduction, modification, or distribution is strictly prohibited.',
          ),
          _heading(context, '8. LIMITATION OF LIABILITY'),
          _paragraph(
            context,
            'The system is provided “as is” and “as available.”',
          ),
          _paragraph(
            context,
            'ELECOM and the developers shall not be liable for:',
          ),
          _bullet(context, 'System interruptions due to technical issues'),
          _bullet(context, 'Delays caused by network or device limitations'),
          _bullet(context, 'User errors during voting'),
          _bullet(context, 'Unauthorized access beyond reasonable security controls'),
          _heading(context, '9. DATA BREACH AND INCIDENT RESPONSE'),
          _paragraph(
            context,
            'In the event of a security incident:',
          ),
          _bullet(context, 'Affected users will be notified promptly'),
          _bullet(context, 'Necessary actions will be taken to secure the system'),
          _bullet(context, 'Relevant authorities will be informed when required'),
          _heading(context, '10. GOVERNING LAW'),
          _paragraph(
            context,
            'These Terms shall be governed by the laws of the Republic of the Philippines.',
          ),
          _paragraph(
            context,
            'Any disputes shall be subject to the jurisdiction of appropriate courts within the Philippines.',
          ),
          _heading(context, '11. AMENDMENTS'),
          _paragraph(
            context,
            'ELECOM reserves the right to update these Terms at any time.',
          ),
          _paragraph(
            context,
            'Continued use of the application constitutes acceptance of any changes.',
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
