import 'package:flutter/material.dart';

class ElecomPrivacyNoticeScreen extends StatelessWidget {
  const ElecomPrivacyNoticeScreen({super.key});

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w400,
            ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 10,
              child: Text(
                '•',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subheading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final surface = isDarkMode ? const Color(0xFF171620) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        title: const Text(
          'Privacy Notice',
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
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Effective Date: April 25, 2026',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
          ),
          _heading(context, '1. POLICY STATEMENT'),
          _paragraph(
            context,
            'The Electoral Commission Voting System (ECVS) of the University of Science and Technology of Southern Philippines – Oroquieta Campus is committed to protecting the privacy and security of personal data in compliance with the Data Privacy Act of 2012 and regulations issued by the National Privacy Commission.',
          ),
          _paragraph(
            context,
            'We uphold the principles of transparency, legitimate purpose, and proportionality in the collection and processing of personal data.',
          ),
          _heading(context, '2. PERSONAL DATA COLLECTED'),
          _paragraph(
            context,
            'The system collects and processes only necessary information for election purposes, including:',
          ),
          _subheading(context, 'A. Identity Information'),
          _bullet(context, 'Full Name'),
          _bullet(context, 'Student ID Number'),
          _bullet(context, 'Course/Year/Section'),
          _subheading(context, 'B. Contact Information'),
          _bullet(context, 'Institutional Email Address'),
          _subheading(context, 'C. Voting Information'),
          _bullet(context, 'Voting status (e.g., voted/not voted)'),
          _bullet(context, 'Encrypted vote records (secured via blockchain technology)'),
          _subheading(context, 'D. Technical Information'),
          _bullet(context, 'Device type'),
          _bullet(context, 'IP address'),
          _bullet(context, 'Log records'),
          _bullet(context, 'Application usage data'),
          _heading(context, '3. PURPOSE OF PROCESSING'),
          _paragraph(
            context,
            'Personal data is processed strictly for the following purposes:',
          ),
          _bullet(context, 'Voter registration and authentication'),
          _bullet(context, 'Secure vote casting and validation'),
          _bullet(context, 'Prevention of multiple voting'),
          _bullet(context, 'Election monitoring and administration'),
          _bullet(context, 'Generation of election results'),
          _bullet(context, 'System security and fraud prevention'),
          _paragraph(
            context,
            'No personal data shall be used beyond these declared and legitimate purposes.',
          ),
          _heading(context, '4. DATA SHARING AND DISCLOSURE'),
          _paragraph(
            context,
            'Personal data may be accessed only by:',
          ),
          _bullet(context, 'Authorized Electoral Commission (ELECOM) personnel'),
          _bullet(context, 'System administrators for maintenance and security'),
          _paragraph(
            context,
            'We do not sell, trade, or share personal data with third parties unless required by law.',
          ),
          _heading(context, '5. DATA RETENTION'),
          _paragraph(
            context,
            'Personal data shall be retained only for as long as necessary to:',
          ),
          _bullet(context, 'Complete election processes'),
          _bullet(context, 'Comply with institutional and legal requirements'),
          _bullet(context, 'Resolve disputes or audits'),
          _paragraph(
            context,
            'After the retention period, data will be securely deleted or anonymized.',
          ),
          _heading(context, '6. DATA SECURITY MEASURES'),
          _paragraph(
            context,
            'The system implements appropriate safeguards, including:',
          ),
          _bullet(context, 'Encryption of sensitive data'),
          _bullet(context, 'Blockchain-based vote recording'),
          _bullet(context, 'Secure authentication mechanisms'),
          _bullet(context, 'Network-restricted voting access'),
          _bullet(context, 'Regular system monitoring and security checks'),
          _paragraph(
            context,
            'Despite these measures, no system is completely immune from risks.',
          ),
          _heading(context, '7. RIGHTS OF DATA SUBJECTS'),
          _paragraph(
            context,
            'Users have the right to:',
          ),
          _bullet(context, 'Be informed about data processing'),
          _bullet(context, 'Access their personal data'),
          _bullet(context, 'Request correction of inaccurate data'),
          _bullet(context, 'Object to processing when applicable'),
          _bullet(context, 'Request deletion or blocking of data'),
          _bullet(context, 'File a complaint with the National Privacy Commission'),
          _paragraph(
            context,
            'Requests will be processed in accordance with applicable laws.',
          ),
          _heading(context, '8. DATA PROTECTION OFFICER (DPO)'),
          _paragraph(
            context,
            'The University designates a Data Protection Officer responsible for:',
          ),
          _bullet(context, 'Ensuring compliance with data privacy laws'),
          _bullet(context, 'Handling data-related concerns and requests'),
          _bullet(context, 'Monitoring system security and privacy practices'),
          _heading(context, '9. DATA BREACH NOTIFICATION'),
          _paragraph(
            context,
            'In case of a data breach that may affect user data:',
          ),
          _bullet(context, 'Affected users will be notified immediately'),
          _bullet(context, 'Proper authorities will be informed if required'),
          _bullet(context, 'Necessary actions will be taken to mitigate risks'),
          _heading(context, '10. USER RESPONSIBILITIES'),
          _paragraph(
            context,
            'Users are responsible for:',
          ),
          _bullet(context, 'Keeping login credentials secure'),
          _bullet(context, 'Using the system only for authorized purposes'),
          _bullet(context, 'Reporting suspicious activities'),
          _heading(context, '11. POLICY AMENDMENTS'),
          _paragraph(
            context,
            'This Privacy Notice may be updated to reflect system or legal changes. Updated versions will be made available within the application.',
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
