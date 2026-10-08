import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app.dart' show elecomRouteObserver;
import '../../../core/notifications/notification_center_store.dart';
import '../../../core/session/user_session.dart';
import '../../../core/utils/toast_service.dart';
import '../data/elecom_mobile_api.dart';
import '../data/candidate_application_policy.dart';
import '../student_dashboard/utils/theme_notifier.dart';
import 'candidate_certificate.dart';
import 'candidate_signature_screen.dart';

const _premiumBlue = Color(0xFF2563EB);
const _premiumAccentBlue = Color(0xFF60A5FA);
const _premiumInk = Color(0xFF0F172A);
const _premiumSub = Color(0xFF475569);

class CandidateFilingScreen extends StatefulWidget {
  const CandidateFilingScreen({super.key, this.api});

  final ElecomMobileApi? api;

  @override
  State<CandidateFilingScreen> createState() => _CandidateFilingScreenState();
}

class _CandidateFilingScreenState extends State<CandidateFilingScreen>
    with RouteAware, WidgetsBindingObserver {
  static const String _addNewPartyValue = '__add_new_party__';

  static const List<String> _organizations = [
    'USG',
    'SITE',
    'PAFE',
    'AFPROTECHS',
  ];

  static const List<String> _generalPositions = [
    'President',
    'Vice President',
    'General Secretary',
    'Associate Secretary',
    'Treasurer',
    'Auditor',
    'Public Information Officer',
  ];

  static const List<String> _representativePositions = [
    'BSIT Representative',
    'BTLED Representative',
    'BFPT Representative',
  ];

  static const List<String> _programs = ['BSIT', 'BTLED', 'BFPT'];

  // USTP Oroquieta student organizations (USTP Trailblazer's Summit 2025).
  static const List<String> _membershipOrganizations = [
    'University Student Government (USG)',
    'Society of Information Technology Enthusiasts (SITE)',
    'Prime Association of Future Educators (PAFE)',
    'Association of Food Processing and Technology Students (AFPROTECHS)',
    'Active Certified Computer-Enhanced Student Society (ACCESS)',
    'Red Cross Youth (RCY)',
  ];

  static const Map<String, String> _curriculumPrograms = {
    'BSIT': 'Bachelor of Science in Information Technology',
    'BTLED': 'Bachelor of Technology and Livelihood Education',
    'BFPT': 'Bachelor in Food Processing and Technology',
  };

  static const List<String> _yearSections = [
    'BSIT-1A',
    'BSIT-1B',
    'BSIT-1C',
    'BSIT-1D',
    'BSIT-2A',
    'BSIT-2B',
    'BSIT-2C',
    'BSIT-2D',
    'BSIT-3A',
    'BSIT-3B',
    'BSIT-3C',
    'BSIT-3D',
    'BSIT-4A',
    'BSIT-4B',
    'BSIT-4C',
    'BSIT-4D',
    'BSIT-4E',
    'BSIT-4F',
    'BTLED-ICT-1A',
    'BTLED-ICT-2A',
    'BTLED-ICT-3A',
    'BTLED-ICT-4A',
    'BTLED-IA-1A',
    'BTLED-IA-2A',
    'BTLED-IA-3A',
    'BTLED-IA-4A',
    'BTLED-HE-1A',
    'BTLED-HE-2A',
    'BTLED-HE-3A',
    'BTLED-HE-4A',
    'BFPT-1A',
    'BFPT-1B',
    'BFPT-1C',
    'BFPT-1D',
    'BFPT-2A',
    'BFPT-2B',
    'BFPT-2C',
    'BFPT-3A',
    'BFPT-3B',
    'BFPT-3C',
    'BFPT-4A',
    'BFPT-4B',
  ];

  late final ElecomMobileApi _api;
  Timer? _statusPollTimer;
  PageRoute<dynamic>? _filingRoute;
  bool _appResumed = true;
  bool _routeVisible = true;
  bool _statusRequestInFlight = false;
  int _statusRevision = 0;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _platformController = TextEditingController();
  final TextEditingController _partyNameController = TextEditingController();
  final FocusNode _partyNameFocusNode = FocusNode();
  final TextEditingController _partyCodeController = TextEditingController();
  final Map<String, TextEditingController> _certificateControllers = {
    for (final key in [
      'curriculum_program',
      'major',
      'contact_number',
      'email',
      'address',
      for (var i = 0; i < 3; i++) ...[
        'affiliation_${i}_organization',
        'affiliation_${i}_years',
        'affiliation_${i}_position',
      ],
    ])
      key: TextEditingController(),
  };
  DateTime? _birthDate;
  int _membershipCount = 1;
  final List<String?> _membershipSelections = List.filled(3, null);
  final List<String?> _membershipPositions = List.filled(3, null);
  final List<RangeValues?> _membershipYears = List.filled(3, null);
  String? _gender;
  Uint8List? _signature;
  Uint8List? _savedCertificate;
  String? _savedCertificateApplicationId;
  bool _preparingCertificate = false;
  bool _certified = false;

  String _candidateType = 'Political Party';
  String? _accountProgram;
  String? _accountYearSection;
  String? _organization;
  String? _position;
  String? _program;
  String? _yearSection;
  Map<String, dynamic>? _existingApplication;
  List<String> _existingPartyNames = <String>[];
  String? _selectedPartyName;
  File? _candidatePhoto;
  File? _partyLogo;
  bool _submitting = false;
  bool _loadingStatus = true;
  bool _loadingParties = false;
  bool _addingNewParty = true;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ElecomMobileApi();
    WidgetsBinding.instance.addObserver(this);
    _appResumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _statusPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollApplicationStatus();
    });
    _hydrateFromSession();
    _hydrateProfileAndStatus();
    _loadPartyNames();
    _restoreCertificate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _filingRoute) {
      elecomRouteObserver.unsubscribe(this);
      _filingRoute = route;
      elecomRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() => _routeVisible = true;

  @override
  void didPushNext() => _routeVisible = false;

  @override
  void didPopNext() {
    _routeVisible = true;
    _pollApplicationStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed) _pollApplicationStatus();
  }

  void _pollApplicationStatus() {
    if (!mounted ||
        !_appResumed ||
        !_routeVisible ||
        _filingRoute?.isCurrent == false ||
        _loadingStatus ||
        _submitting ||
        _existingApplication == null) {
      return;
    }
    unawaited(_loadApplicationStatus());
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    elecomRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _studentIdController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _platformController.dispose();
    _partyNameController.dispose();
    _partyNameFocusNode.dispose();
    _partyCodeController.dispose();
    for (final controller in _certificateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreCertificate() async {
    final studentId = UserSession.studentId;
    if (studentId == null || studentId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('candidate_certificate_$studentId');
    if (!mounted || stored == null || studentId != UserSession.studentId) {
      return;
    }
    try {
      final copy = jsonDecode(stored) as Map<String, dynamic>;
      setState(() {
        _savedCertificate = base64Decode(copy['pdf'] as String);
        _savedCertificateApplicationId = copy['application_id']?.toString();
      });
    } catch (_) {
      /* Ignore an invalid local copy. */
    }
  }

  Map<String, String> _filingFields() => {
    'candidate_type': _candidateType,
    'student_id': _studentIdController.text.trim(),
    'first_name': _firstNameController.text.trim(),
    'middle_name': _middleNameController.text.trim(),
    'last_name': _lastNameController.text.trim(),
    'organization': _organization ?? '',
    'position': _position ?? '',
    'program': _program ?? '',
    'year_section': _yearSection ?? '',
    'platform': _platformController.text.trim(),
    'party_name': _effectivePartyName,
    'party_code': _effectivePartyCode,
    for (final entry in _certificateControllers.entries)
      entry.key: entry.value.text.trim(),
    'gender': _gender ?? '',
    'date_of_birth': _birthDate == null
        ? ''
        : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
    'age': _birthDate == null
        ? ''
        : candidateAge(_birthDate!, DateTime.now()).toString(),
    if (_signature != null) 'signature_base64': base64Encode(_signature!),
  };

  bool _validateCertificate() {
    if (!_formKey.currentState!.validate()) return false;
    final missing = <String>[
      if (_candidatePhoto == null) 'add your 2x2 photo',
      if (_signature == null) 'add your signature',
      if (!_certified) 'check the declaration checkbox',
    ];
    if (missing.isNotEmpty) {
      AppToast.warning(context, 'Please ${missing.join(', ')}.');
      return false;
    }
    return true;
  }

  Future<Uint8List> _createCertificate() async => buildCandidateCertificate(
    fields: _filingFields(),
    photo: await _candidatePhoto!.readAsBytes(),
    signature: _signature!,
  );

  Future<void> _previewCertificate({
    Uint8List? saved,
    String? applicationId,
  }) async {
    if (_preparingCertificate ||
        (saved == null && applicationId == null && !_validateCertificate())) {
      return;
    }
    setState(() => _preparingCertificate = true);
    try {
      final bytes =
          saved ??
          (applicationId == null
              ? await _createCertificate()
              : await _api.getCandidateCertificate(applicationId));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Certificate of Candidacy')),
            body: PdfPreview(
              build: (_) async => bytes,
              pdfFileName:
                  'certificate_of_candidacy_${_studentIdController.text.trim()}.pdf',
              canChangePageFormat: false,
              canChangeOrientation: false,
              allowPrinting: true,
              allowSharing: true,
            ),
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Certificate preview failed: $error\n$stackTrace');
      if (mounted) {
        AppToast.warning(
          context,
          'Could not prepare your certificate. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _preparingCertificate = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (date != null && mounted) setState(() => _birthDate = date);
  }

  Future<void> _sign() async {
    final signature = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const CandidateSignatureScreen()),
    );
    if (signature != null && mounted) {
      setState(() {
        _signature = signature;
        _certified = false;
      });
    }
  }

  Widget _certificateText(
    String key,
    String label, {
    bool required = true,
    String? hint,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _FilingTextField(
      controller: _certificateControllers[key]!,
      validator: (value) {
        if (required && (value ?? '').trim().isEmpty) return 'Required';
        if (key == 'email' &&
            !RegExp(
              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
            ).hasMatch((value ?? '').trim())) {
          return 'Enter a valid email address';
        }
        if ((value ?? '').length > (key == 'address' ? 200 : 120)) {
          return 'Please use a shorter value';
        }
        if (key.startsWith('affiliation_')) {
          final prefix = key.substring(0, key.lastIndexOf('_') + 1);
          final hasRow = ['organization', 'years', 'position'].any(
            (suffix) => _certificateControllers['$prefix$suffix']!.text
                .trim()
                .isNotEmpty,
          );
          if (hasRow && (value ?? '').trim().isEmpty) {
            return 'Complete this membership row';
          }
        }
        return null;
      },
      maxLines: lines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  Widget _personalDetails(bool premium) => _Section(
    title: 'Personal Details',
    isPremiumMode: premium,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilingSelectField(
          label: 'Curriculum Program',
          value: _certificateControllers['curriculum_program']!.text.isEmpty
              ? null
              : _certificateControllers['curriculum_program']!.text,
          options: _curriculumPrograms.values.toList(),
          validator: _required,
          onChanged: (value) => setState(() {
            _certificateControllers['curriculum_program']!.text = value ?? '';
          }),
        ),
        const SizedBox(height: 12),
        _certificateText(
          'major',
          'Major in',
          hint: 'Enter N/A if not applicable',
        ),
        _FilingSelectField(
          label: 'Gender',
          value: _gender,
          options: const ['Male', 'Female', 'Other', 'Prefer not to say'],
          validator: _required,
          onChanged: (value) => setState(() => _gender = value),
        ),
        const SizedBox(height: 12),
        FormField<DateTime>(
          initialValue: _birthDate,
          key: ValueKey(_birthDate),
          validator: (_) => _birthDate == null ? 'Required' : null,
          builder: (field) => InkWell(
            onTap: _pickBirthDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date of Birth',
                errorText: field.errorText,
                suffixIcon: const Icon(Icons.calendar_month),
              ),
              child: Text(
                _birthDate == null
                    ? 'Select date'
                    : _filingFields()['date_of_birth']!,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _birthDate == null
              ? 'Age: calculated from date of birth'
              : 'Age: ${candidateAge(_birthDate!, DateTime.now())}',
        ),
        const SizedBox(height: 12),
        _certificateText(
          'contact_number',
          'Contact No.',
          hint: 'Mobile or telephone number',
        ),
        _certificateText('email', 'Email Address'),
        _certificateText('address', 'Address', lines: 2),
      ],
    ),
  );

  Widget _membershipOrganization(int index) {
    final key = 'affiliation_${index}_organization';
    final controller = _certificateControllers[key]!;
    final selection = _membershipSelections[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilingSelectField(
          label: 'Club / Organization',
          value: selection,
          options: const [..._membershipOrganizations, 'Others', 'None'],
          validator: (_) {
            final hasDetails = ['years', 'position'].any(
              (suffix) =>
                  _certificateControllers['affiliation_${index}_$suffix']!.text
                      .trim()
                      .isNotEmpty,
            );
            if (selection != 'Others' &&
                hasDetails &&
                controller.text.isEmpty) {
              return 'Select a club / organization';
            }
            return null;
          },
          onChanged: (value) => setState(() {
            _membershipSelections[index] = value;
            _membershipPositions[index] = null;
            _certificateControllers['affiliation_${index}_position']!.clear();
            controller.text = value == 'Others' || value == 'None'
                ? ''
                : value ?? '';
            if (value == 'None') {
              _membershipYears[index] = null;
              for (final suffix in ['years', 'position']) {
                _certificateControllers['affiliation_${index}_$suffix']!
                    .clear();
              }
            }
          }),
        ),
        const SizedBox(height: 12),
        if (selection == 'Others')
          _certificateText(
            key,
            'Other Club / Organization',
            hint: 'Enter the full organization name',
          ),
      ],
    );
  }

  Future<void> _pickMembershipYears(int index) async {
    FocusScope.of(context).unfocus();
    final currentYear = DateTime.now().year;
    final firstYear = _birthDate?.year ?? currentYear - 100;
    var range =
        _membershipYears[index] ??
        RangeValues(currentYear.toDouble(), currentYear.toDouble());
    range = RangeValues(
      range.start.clamp(firstYear, currentYear).toDouble(),
      range.end.clamp(firstYear, currentYear).toDouble(),
    );
    final selected = await showModalBottomSheet<RangeValues>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Year/s of Membership',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'From ${range.start.round()} to ${range.end.round()}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Drag the handles to select your start and end year.',
                ),
                RangeSlider(
                  values: range,
                  min: firstYear.toDouble(),
                  max: currentYear.toDouble(),
                  divisions: currentYear > firstYear
                      ? currentYear - firstYear
                      : null,
                  labels: RangeLabels(
                    range.start.round().toString(),
                    range.end.round().toString(),
                  ),
                  onChanged: (value) => updateSheet(() => range = value),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, range),
                  child: const Text('Use these years'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _membershipYears[index] = selected;
      _certificateControllers['affiliation_${index}_years']!.text =
          '${selected.start.round()}–${selected.end.round()}';
    });
  }

  Widget _membershipYearField(int index) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _FilingFieldLabel(
      label: 'Year/s of Membership',
      child: FormField<String>(
        key: ValueKey('membership-years-$index:${_membershipYears[index]}'),
        validator: (_) {
          final hasOrganization =
              _certificateControllers['affiliation_${index}_organization']!.text
                  .trim()
                  .isNotEmpty;
          return hasOrganization && _membershipYears[index] == null
              ? 'Select membership years'
              : null;
        },
        builder: (field) => InkWell(
          onTap: () => _pickMembershipYears(index),
          child: InputDecorator(
            decoration: InputDecoration(
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.calendar_month, size: 20),
            ),
            child: Text(
              _membershipYears[index] == null
                  ? 'Select start and end year'
                  : _certificateControllers['affiliation_${index}_years']!.text,
              style: _filingValueStyle(context),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _membershipPositionField(int index) {
    final organization = _membershipSelections[index];
    final hasKnownRoles = _membershipOrganizations
        .take(4)
        .contains(organization);
    final key = 'affiliation_${index}_position';
    final selection = _membershipPositions[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilingSelectField(
          label: 'Membership Position',
          value: selection,
          options: [
            if (hasKnownRoles) ..._generalPositions,
            if (organization == _membershipOrganizations.first)
              ..._representativePositions,
            'Member',
            'Others',
          ],
          validator: (_) {
            final hasRow = ['organization', 'years'].any(
              (suffix) =>
                  _certificateControllers['affiliation_${index}_$suffix']!.text
                      .trim()
                      .isNotEmpty,
            );
            return hasRow && selection == null
                ? 'Select a membership position'
                : null;
          },
          onChanged: (value) => setState(() {
            _membershipPositions[index] = value;
            _certificateControllers[key]!.text = value == 'Others'
                ? ''
                : value ?? '';
          }),
        ),
        const SizedBox(height: 12),
        if (selection == 'Others')
          _certificateText(
            key,
            'Other Membership Position',
            hint: 'Enter your position',
          ),
      ],
    );
  }

  Widget _affiliations(bool premium) => _Section(
    title: 'Clubs and Organizations',
    isPremiumMode: premium,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Inside or outside the school. Optional if you have no memberships.',
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _membershipCount; i++) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Membership ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (i == _membershipCount - 1 && i > 0)
                IconButton(
                  tooltip: 'Remove membership',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() {
                    for (final suffix in [
                      'organization',
                      'years',
                      'position',
                    ]) {
                      _certificateControllers['affiliation_${i}_$suffix']!
                          .clear();
                    }
                    _membershipCount--;
                    _membershipSelections[i] = null;
                    _membershipPositions[i] = null;
                    _membershipYears[i] = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _membershipOrganization(i),
          _membershipYearField(i),
          _membershipPositionField(i),
        ],
        if (_membershipCount < 3)
          OutlinedButton.icon(
            onPressed: () => setState(() => _membershipCount++),
            icon: const Icon(Icons.add),
            label: const Text('Add Club / Organization'),
          ),
      ],
    ),
  );

  Widget _signatureSection(bool premium) => _Section(
    title: 'Candidate Signature',
    isPremiumMode: premium,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_signature != null)
          Container(
            color: Colors.white,
            height: 100,
            child: Image.memory(_signature!, fit: BoxFit.contain),
          ),
        OutlinedButton.icon(
          onPressed: _sign,
          icon: const Icon(Icons.draw_outlined),
          label: Text(
            _signature == null ? 'Add E-Signature' : 'Replace E-Signature',
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _certified,
          onChanged: (value) => setState(() => _certified = value ?? false),
          title: const Text(
            'I certify that these details are true and correct and agree to abide by the USTP Oroquieta election rules.',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _preparingCertificate ? null : () => _previewCertificate(),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            _preparingCertificate
                ? 'Preparing...'
                : 'Preview / Save Certificate',
          ),
        ),
      ],
    ),
  );

  void _hydrateFromSession() {
    _studentIdController.text = (UserSession.studentId ?? '').trim();
    _accountProgram = _programFromDepartment(UserSession.department);
    _setProgram(_accountProgram);
    _accountYearSection = _normalizeYearSection(UserSession.yearSection);
    if (_accountYearSection != null &&
        _sectionBelongsToProgram(_accountYearSection!, _program)) {
      _yearSection = _accountYearSection;
    }
    final explicitFirst = (UserSession.firstName ?? '').trim();
    final explicitMiddle = (UserSession.middleName ?? '').trim();
    final explicitLast = (UserSession.lastName ?? '').trim();
    if (explicitFirst.isNotEmpty ||
        explicitMiddle.isNotEmpty ||
        explicitLast.isNotEmpty) {
      _firstNameController.text = explicitFirst;
      _middleNameController.text = explicitMiddle;
      _lastNameController.text = explicitLast;
      return;
    }
    final parts = (UserSession.fullName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return;
    if (parts.length == 1) {
      _firstNameController.text = parts.first;
    } else if (parts.length == 2) {
      _firstNameController.text = parts.first;
      _lastNameController.text = parts.last;
      _middleNameController.clear();
    } else if (parts.length > 2) {
      _firstNameController.text = parts.length > 3
          ? parts.sublist(0, parts.length - 2).join(' ')
          : parts.first;
      _middleNameController.text = parts[parts.length - 2];
      _lastNameController.text = parts.last;
    }
  }

  Future<void> _hydrateProfileAndStatus() async {
    final initialEmail = _certificateControllers['email']!.text;
    final initialPhone = _certificateControllers['contact_number']!.text;
    try {
      final res = await _api.getProfile();
      final data = res['data'];
      if (data is Map<String, dynamic>) {
        UserSession.setFromResponse(data);
      } else if (data is Map) {
        UserSession.setFromResponse(Map<String, dynamic>.from(data));
      }
      UserSession.setFromResponse(res);
      if (mounted) {
        setState(() {
          _hydrateFromSession();
          // Only prefill untouched empty fields; preserve candidate corrections.
          if (initialEmail.isEmpty &&
              _certificateControllers['email']!.text == initialEmail) {
            _certificateControllers['email']!.text = _profileContact(
              res,
              const ['email'],
            );
          }
          if (initialPhone.isEmpty &&
              _certificateControllers['contact_number']!.text == initialPhone) {
            _certificateControllers['contact_number']!.text =
                _profileContact(res, const [
                  'phone_number',
                  'phoneNumber',
                  'phone',
                  'mobile',
                  'contact',
                  'contact_number',
                  'contact_no',
                  'contactNo',
                ]);
          }
        });
      }
    } catch (_) {
      // Keep the locally persisted session values if profile refresh fails.
    }
    await _loadApplicationStatus();
  }

  String _profileContact(Map<String, dynamic> profile, List<String> keys) {
    final sources = <Map>[
      profile,
      if (profile['data'] is Map) profile['data'] as Map,
    ];
    for (final source in List<Map>.of(sources)) {
      for (final key in ['user', 'student']) {
        if (source[key] is Map) sources.add(source[key] as Map);
      }
    }
    for (final key in keys) {
      for (final source in sources) {
        final value = source[key]?.toString().trim() ?? '';
        if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
      }
    }
    return '';
  }

  Future<void> _refreshFiling() async {
    if (mounted) {
      setState(() => _loadingStatus = true);
    }
    await _hydrateProfileAndStatus();
    await _loadPartyNames();
  }

  String? _programFromDepartment(String? department) {
    final value = (department ?? '').trim().toUpperCase();
    if (value.isEmpty) return null;
    if (value.contains('BFPT')) return 'BFPT';
    if (value.contains('BTLED')) return 'BTLED';
    if (value.contains('BSIT') ||
        value.contains('INFORMATION TECHNOLOGY') ||
        value == 'IT' ||
        value.contains(' IT')) {
      return 'BSIT';
    }
    return null;
  }

  String? _normalizeYearSection(String? value) {
    final raw = (value ?? '').trim().toUpperCase();
    if (raw.isEmpty || raw == 'NULL') return null;
    final compact = raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^A-Z0-9-]'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final yearLetter = compact.replaceFirstMapped(
      RegExp(r'^(\d+)-([A-Z])$'),
      (match) => '${match.group(1)}${match.group(2)}',
    );
    if (_yearSections.contains(compact)) return compact;
    if (_yearSections.contains(yearLetter)) return yearLetter;
    final inferredProgram = _accountProgram ?? _program;
    if (inferredProgram != null) {
      final candidates = <String>[
        if (!compact.startsWith('$inferredProgram-'))
          '$inferredProgram-$compact',
        if (!yearLetter.startsWith('$inferredProgram-'))
          '$inferredProgram-$yearLetter',
      ];
      for (final candidate in candidates) {
        if (_yearSections.contains(candidate)) return candidate;
      }
    }
    return _yearSections.contains(raw) ? raw : null;
  }

  List<String> get _availableOrganizations {
    switch (_program) {
      case 'BSIT':
        return const ['USG', 'SITE'];
      case 'BTLED':
        return const ['USG', 'PAFE'];
      case 'BFPT':
        return const ['USG', 'AFPROTECHS'];
      default:
        return _organizations;
    }
  }

  List<String> get _availablePositions {
    if (_organization != 'USG') return _generalPositions;
    final ownRepresentative = switch (_program) {
      'BSIT' => 'BSIT Representative',
      'BTLED' => 'BTLED Representative',
      'BFPT' => 'BFPT Representative',
      _ => null,
    };
    return [
      ..._generalPositions,
      if (ownRepresentative != null)
        ownRepresentative
      else
        ..._representativePositions,
    ];
  }

  bool _sectionBelongsToProgram(String section, String? program) {
    if (program == null) return true;
    return section.startsWith('$program-');
  }

  void _setProgram(String? value) {
    _program = value;
    _certificateControllers['curriculum_program']!.text =
        _curriculumPrograms[value] ?? '';
    if (_organization != null &&
        !_availableOrganizations.contains(_organization)) {
      _organization = null;
    }
    if (_position != null && !_availablePositions.contains(_position)) {
      _position = null;
    }
    if (_yearSection != null &&
        !_sectionBelongsToProgram(_yearSection!, value)) {
      _yearSection = null;
    }
  }

  void _setOrganization(String? value) {
    _organization = value;
    if (_position != null && !_availablePositions.contains(_position)) {
      _position = null;
    }
  }

  Future<void> _loadApplicationStatus() async {
    if (_statusRequestInFlight || !mounted) return;
    _statusRequestInFlight = true;
    final revision = _statusRevision;
    try {
      final res = await _api.getCandidateApplicationStatus();
      final raw = res['application'];
      final application = raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (!mounted || revision != _statusRevision) return;
      final applicationId = application?['id']?.toString();
      if (applicationId != null &&
          application?['certificate_available'] == false &&
          _savedCertificateApplicationId == applicationId &&
          _savedCertificate != null) {
        try {
          final archived = await _api.archiveCandidateCertificate(
            applicationId,
            _savedCertificate!,
          );
          if (archived['certificate_available'] == true) {
            application!['certificate_available'] = true;
            application['certificate_sha256'] = archived['certificate_sha256'];
          }
        } catch (error) {
          debugPrint('Certificate archival retry pending: $error');
        }
        if (!mounted || revision != _statusRevision) return;
      }
      if (_loadingStatus || !mapEquals(_existingApplication, application)) {
        setState(() {
          _existingApplication = application;
          _loadingStatus = false;
        });
      }
    } catch (_) {
      // Retain the last successful status and retry on the next poll.
      if (mounted && revision == _statusRevision && _loadingStatus) {
        setState(() => _loadingStatus = false);
      }
    } finally {
      _statusRequestInFlight = false;
    }
  }

  Future<void> _loadPartyNames() async {
    setState(() => _loadingParties = true);
    try {
      final names = await _api.getCandidateApplicationParties();
      if (!mounted) return;
      setState(() {
        _existingPartyNames = names;
        final current = _partyNameController.text.trim();
        final matching = current.isEmpty ? null : _matchingPartyName(current);
        if (matching != null) {
          _selectedPartyName = matching;
          _addingNewParty = false;
        } else if (names.isNotEmpty && current.isEmpty) {
          _selectedPartyName = null;
          _addingNewParty = false;
        } else {
          _addingNewParty = true;
        }
      });
    } catch (_) {
      // The party field still allows adding a new party if loading fails.
    } finally {
      if (mounted) setState(() => _loadingParties = false);
    }
  }

  String? _matchingPartyName(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final party in _existingPartyNames) {
      if (party.trim().toLowerCase() == normalized) return party;
    }
    return null;
  }

  String get _effectivePartyName {
    if (_candidateType != 'Political Party') return '';
    if (!_addingNewParty && (_selectedPartyName ?? '').trim().isNotEmpty) {
      return _selectedPartyName!.trim();
    }
    return _partyNameController.text.trim();
  }

  String get _effectivePartyCode {
    if (_candidateType != 'Political Party') return '';
    if (_addingNewParty) return '';
    return _partyCodeController.text.trim();
  }

  String? _partyNameValidator(String? value) {
    if (_candidateType != 'Political Party') return null;
    if (_effectivePartyName.isEmpty) return 'Required';
    return null;
  }

  String? _partyCodeValidator(String? value) {
    if (_candidateType != 'Political Party') return null;
    if (_addingNewParty) return null;
    final code = _effectivePartyCode;
    if (code.isEmpty) return 'Required';
    if (code.length < 4) return 'Use at least 4 characters';
    return null;
  }

  void _selectPartyName(String? value) {
    if (value == null) return;
    if (value == _addNewPartyValue) {
      setState(() {
        _addingNewParty = true;
        _selectedPartyName = null;
        _partyNameController.clear();
        _partyCodeController.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_addingNewParty) return;
        _partyNameFocusNode.requestFocus();
      });
      return;
    }
    setState(() {
      _addingNewParty = false;
      _selectedPartyName = value;
      _partyNameController.text = value;
    });
  }

  void _chooseExistingParty() {
    setState(() {
      _addingNewParty = false;
      final matching = _matchingPartyName(_partyNameController.text);
      _selectedPartyName = matching;
      _partyNameController.text = matching ?? '';
    });
  }

  Future<void> _pickCandidatePhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null || !mounted) return;
    setState(() => _candidatePhoto = File(picked.path));
  }

  Future<void> _pickPartyLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (picked == null) return;
    setState(() => _partyLogo = File(picked.path));
  }

  Future<void> _submit() async {
    if (_submitting || _preparingCertificate) return;
    if (!_validateCertificate()) return;
    final fields = _filingFields();
    final photo = _candidatePhoto!;
    final signature = _signature!;
    final partyLogo = _partyLogo;

    setState(() => _submitting = true);
    try {
      final storage = await _api.getCandidateApplicationStatus();
      if (storage['certificate_storage_ready'] != true) {
        throw const ElecomApiException(
          'Certificate storage is not ready on the server. Please contact ELECOM before submitting.',
        );
      }
      final certificate = await buildCandidateCertificate(
        fields: fields,
        photo: await photo.readAsBytes(),
        signature: signature,
      );
      final res = await _api.submitCandidateApplication(
        candidatePhoto: photo,
        certificatePdf: certificate,
        partyLogo: partyLogo,
        fields: fields,
      );
      if (!mounted) return;
      setState(() {
        _statusRevision++;
        _existingApplication = _applicationFromSubmitResponse(res);
        _loadingStatus = false;
        _savedCertificate = certificate;
        _savedCertificateApplicationId = _existingApplication?['id']
            ?.toString();
      });
      // Keep an offline copy in addition to the authoritative server archive.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'candidate_certificate_${_studentIdController.text.trim()}',
          jsonEncode({
            'pdf': base64Encode(certificate),
            'application_id': _savedCertificateApplicationId,
          }),
        );
      } catch (_) {
        /* Submission already succeeded; keep the in-memory copy. */
      }
      await NotificationCenterStore.refresh();
      if (!mounted) return;
      AppToast.success(
        context,
        'Candidate filing submitted. Please wait for ELECOM approval.',
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e is ElecomApiException ? e.message : e.toString();
      // Strip raw HTTP codes from the user-facing message.
      final cleaned = raw
          .replaceFirst(RegExp(r'^Request failed \(\d+\):\s*'), '')
          .replaceFirst(RegExp(r'^Server error \(\d+\):\s*'), '')
          .trim();

      // Give a friendly message for known server-side issues.
      final message = () {
        if (raw.contains('413') ||
            cleaned.toLowerCase().contains('too large') ||
            cleaned.toLowerCase().contains('invalid json')) {
          return 'Your photo is too large. Please choose a smaller image and try again.';
        }
        if (cleaned.toLowerCase().contains('already submitted') ||
            cleaned.toLowerCase().contains('pending filing') ||
            cleaned.toLowerCase().contains('already registered')) {
          return cleaned;
        }
        if (cleaned.isEmpty) return 'Failed to submit candidate filing.';
        return cleaned;
      }();

      final lowerMessage = message.toLowerCase();
      if (lowerMessage.contains('already submitted') ||
          lowerMessage.contains('pending filing') ||
          lowerMessage.contains('already registered')) {
        await _loadApplicationStatus();
        if (!mounted) return;
        AppToast.warning(context, message);
        return;
      }
      AppToast.error(context, message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Map<String, dynamic> _applicationFromSubmitResponse(
    Map<String, dynamic> response,
  ) {
    final raw = response['application'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{
      'id': response['application_id'],
      'student_id': _studentIdController.text.trim(),
      'first_name': _firstNameController.text.trim(),
      'middle_name': _middleNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'organization': _organization ?? '',
      'position': _position ?? '',
      'program': _program ?? '',
      'year_section': _yearSection ?? '',
      'platform': _platformController.text.trim(),
      'candidate_type': _candidateType,
      'party_name': _effectivePartyName,
      'status': (response['status'] ?? 'pending').toString(),
    };
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
  }

  Widget _buildPartyNameField(bool isPremiumMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Select Existing Party')),
            ButtonSegment(value: true, label: Text('Register New Party')),
          ],
          selected: {_addingNewParty},
          onSelectionChanged: _loadingParties
              ? null
              : (selection) {
                  if (selection.first) {
                    _selectPartyName(_addNewPartyValue);
                  } else {
                    _chooseExistingParty();
                  }
                },
        ),
        const SizedBox(height: 12),
        if (_loadingParties) const LinearProgressIndicator(),
        if (_addingNewParty)
          _FilingTextField(
            controller: _partyNameController,
            focusNode: _partyNameFocusNode,
            validator: _partyNameValidator,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'New Party Name',
              helperText: 'A security code is generated after submission.',
              helperMaxLines: 2,
            ),
          )
        else ...[
          _FilingSelectField(
            label: 'Existing Party',
            value: _selectedPartyName,
            options: _existingPartyNames,
            validator: (_) => _partyNameValidator(null),
            onChanged: _loadingParties ? null : _selectPartyName,
          ),
          if (!_loadingParties && _existingPartyNames.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'No parties available. Register a new party.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          _FilingTextField(
            controller: _partyCodeController,
            validator: _partyCodeValidator,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Party Security Code',
              helperText: 'Enter the code shared by your party leader.',
              helperMaxLines: 2,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final isPremiumMode = themeNotifier.isPremiumMode;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final titleColor = isPremiumMode
            ? _premiumInk
            : isDark
            ? Colors.white
            : const Color(0xFF0F172A);
        final existingApplication = _existingApplication;
        final baseTheme = Theme.of(context);
        final formTheme = isPremiumMode
            ? baseTheme.copyWith(
                colorScheme: baseTheme.colorScheme.copyWith(
                  primary: _premiumBlue,
                  onPrimary: Colors.white,
                  primaryContainer: const Color(0xFFDBEAFE),
                  onPrimaryContainer: _premiumInk,
                  surface: Colors.white,
                  surfaceTint: Colors.transparent,
                  onSurface: _premiumInk,
                  onSurfaceVariant: _premiumSub,
                ),
                bottomSheetTheme: baseTheme.bottomSheetTheme.copyWith(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                ),
                canvasColor: Colors.white,
                highlightColor: _premiumBlue.withValues(alpha: 0.12),
                focusColor: _premiumBlue.withValues(alpha: 0.10),
                hoverColor: _premiumBlue.withValues(alpha: 0.08),
                splashColor: _premiumBlue.withValues(alpha: 0.10),
                inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.72),
                  prefixIconColor: _premiumBlue,
                  suffixIconColor: _premiumBlue,
                  labelStyle: const TextStyle(
                    color: _premiumSub,
                    fontWeight: FontWeight.w700,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: _premiumBlue.withValues(alpha: 0.26),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: _premiumBlue, width: 1.8),
                  ),
                  disabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: _premiumAccentBlue.withValues(alpha: 0.54),
                      width: 1.2,
                    ),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _premiumBlue,
                    side: BorderSide(
                      color: _premiumBlue.withValues(alpha: 0.32),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                segmentedButtonTheme: SegmentedButtonThemeData(
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? _premiumInk
                          : _premiumSub,
                    ),
                    iconColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? _premiumBlue
                          : _premiumSub,
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? _premiumBlue.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.52),
                    ),
                    side: WidgetStateProperty.resolveWith(
                      (states) => BorderSide(
                        color: states.contains(WidgetState.selected)
                            ? _premiumBlue
                            : _premiumBlue.withValues(alpha: 0.20),
                      ),
                    ),
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              )
            : baseTheme;

        return Theme(
          data: formTheme.copyWith(
            inputDecorationTheme: formTheme.inputDecorationTheme.copyWith(
              isDense: true,
              filled: true,
              fillColor: isDark && !isPremiumMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark && !isPremiumMode
                      ? Colors.white24
                      : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? _premiumAccentBlue : _premiumBlue,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark && !isPremiumMode
                      ? Colors.white12
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
          child: Scaffold(
            backgroundColor: isPremiumMode ? Colors.white : null,
            appBar: AppBar(
              backgroundColor: isPremiumMode ? Colors.white : null,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                'Candidate Filing',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            bottomNavigationBar: !_loadingStatus && existingApplication == null
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: formTheme.colorScheme.surface,
                      border: Border(
                        top: BorderSide(color: formTheme.dividerColor),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _submitting ? 'Submitting...' : 'Submit Filing',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
            body: Container(
              color: formTheme.colorScheme.surface,
              child: SafeArea(
                child: RefreshIndicator(
                  color: _premiumBlue,
                  onRefresh: _refreshFiling,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                      children: [
                        Text(
                          existingApplication == null
                              ? 'Complete your candidate application'
                              : 'Your candidate application',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_loadingStatus)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (existingApplication != null) ...[
                          _ApplicationStatusCard(
                            application: existingApplication,
                            isPremiumMode: isPremiumMode,
                            onRequirementsSubmitted: _loadApplicationStatus,
                            onFileAgain: () {
                              if (!canFileCandidateApplicationAgain(
                                existingApplication,
                              )) {
                                return;
                              }
                              setState(() {
                                _statusRevision++;
                                _existingApplication = null;
                                _candidatePhoto = null;
                                _partyLogo = null;
                                _signature = null;
                                _certified = false;
                                _savedCertificate = null;
                                _savedCertificateApplicationId = null;
                              });
                            },
                          ),
                          if (existingApplication['certificate_available'] ==
                                  true ||
                              (_savedCertificate != null &&
                                  _savedCertificateApplicationId != null &&
                                  _savedCertificateApplicationId ==
                                      existingApplication['id']
                                          ?.toString())) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _previewCertificate(
                                saved:
                                    _savedCertificateApplicationId ==
                                        existingApplication['id']?.toString()
                                    ? _savedCertificate
                                    : null,
                                applicationId: existingApplication['id']
                                    ?.toString(),
                              ),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('View / Save Certificate'),
                            ),
                          ],
                        ] else ...[
                          _Section(
                            title: 'Candidate Type',
                            isPremiumMode: isPremiumMode,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'Independent',
                                  label: Text('Independent'),
                                  icon: Icon(Icons.person_outline_rounded),
                                ),
                                ButtonSegment(
                                  value: 'Political Party',
                                  label: Text('Political Party'),
                                  icon: Icon(Icons.groups_2_outlined),
                                ),
                              ],
                              selected: {_candidateType},
                              onSelectionChanged: (selected) {
                                setState(() => _candidateType = selected.first);
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          _PhotoPickerCard(
                            title: 'Candidate Photo',
                            subtitle:
                                'Required. Upload an actual candidate photo.',
                            imageFile: _candidatePhoto,
                            isPremiumMode: isPremiumMode,
                            onGallery: () =>
                                _pickCandidatePhoto(ImageSource.gallery),
                            onCamera: () =>
                                _pickCandidatePhoto(ImageSource.camera),
                          ),
                          const SizedBox(height: 14),
                          _Section(
                            title: 'Student Information',
                            isPremiumMode: isPremiumMode,
                            child: Column(
                              children: [
                                _FilingTextField(
                                  controller: _studentIdController,
                                  validator: _required,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Candidate Student ID',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _FilingTextField(
                                        controller: _firstNameController,
                                        validator: _required,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'First Name',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _FilingTextField(
                                        controller: _lastNameController,
                                        validator: _required,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Last Name',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _FilingTextField(
                                  controller: _middleNameController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Middle Name',
                                    hintText: 'Optional',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _FilingSelectField(
                                        label: 'Program',
                                        value: _program,
                                        options: _programs,
                                        validator: _required,
                                        onChanged: _accountProgram == null
                                            ? (value) => setState(() {
                                                _setProgram(value);
                                              })
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _FilingSelectField(
                                        label: 'Year/Section',
                                        value: _yearSection,
                                        options: _yearSections
                                            .where(
                                              (section) =>
                                                  _sectionBelongsToProgram(
                                                    section,
                                                    _program,
                                                  ),
                                            )
                                            .toList(),
                                        validator: _required,
                                        onChanged: _accountYearSection == null
                                            ? (value) => setState(
                                                () => _yearSection = value,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _personalDetails(isPremiumMode),
                          const SizedBox(height: 14),
                          _affiliations(isPremiumMode),
                          const SizedBox(height: 14),
                          _Section(
                            title: 'Candidacy Details',
                            isPremiumMode: isPremiumMode,
                            child: Column(
                              children: [
                                _FilingSelectField(
                                  label: 'Organization',
                                  value: _organization,
                                  options: _availableOrganizations,
                                  validator: _required,
                                  onChanged: (value) => setState(() {
                                    _setOrganization(value);
                                  }),
                                ),
                                const SizedBox(height: 12),
                                _FilingSelectField(
                                  label: 'Position',
                                  value: _position,
                                  options: _availablePositions,
                                  validator: _required,
                                  onChanged: (value) =>
                                      setState(() => _position = value),
                                ),
                                const SizedBox(height: 12),
                                _FilingTextField(
                                  controller: _platformController,
                                  validator: _required,
                                  minLines: 3,
                                  maxLines: 7,
                                  decoration: const InputDecoration(
                                    labelText: 'Platform',
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_candidateType == 'Political Party') ...[
                            const SizedBox(height: 14),
                            _Section(
                              title: 'Political Party',
                              isPremiumMode: isPremiumMode,
                              child: Column(
                                children: [
                                  _buildPartyNameField(isPremiumMode),
                                  const SizedBox(height: 12),
                                  _MiniImagePicker(
                                    title: 'Party logo',
                                    imageFile: _partyLogo,
                                    isPremiumMode: isPremiumMode,
                                    onPick: _pickPartyLogo,
                                    onClear: () =>
                                        setState(() => _partyLogo = null),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _signatureSection(isPremiumMode),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ApplicationStatusCard extends StatelessWidget {
  const _ApplicationStatusCard({
    required this.application,
    required this.isPremiumMode,
    required this.onFileAgain,
    required this.onRequirementsSubmitted,
  });

  final Map<String, dynamic> application;
  final bool isPremiumMode;
  final VoidCallback onFileAgain;
  final Future<void> Function() onRequirementsSubmitted;

  @override
  Widget build(BuildContext context) {
    final status = (application['status'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase();
    final canFileAgain = canFileCandidateApplicationAgain(application);
    final requirementsRejected = status == 'rejected' && !canFileAgain;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isPremiumMode
        ? _premiumInk
        : isDark
        ? Colors.white
        : const Color(0xFF0F172A);
    final mutedColor = isPremiumMode
        ? _premiumSub
        : isDark
        ? Colors.white70
        : const Color(0xFF64748B);
    final colors = switch (status) {
      'approved' => (
        bg: const Color(0xFFEFFAF3),
        fg: const Color(0xFF15803D),
        icon: Icons.verified_rounded,
        title: 'Congratulations!',
        body:
            'ELECOM approved your candidate filing. You are now published as an official candidate.',
      ),
      'requirements_pending' => (
        bg: const Color(0xFFEFF6FF),
        fg: const Color(0xFF2563EB),
        icon: Icons.upload_file_rounded,
        title: 'Initial Filing Approved',
        body:
            'Your filing passed the initial review. Submit all follow-up requirements for ELECOM’s final approval before your candidacy is published.',
      ),
      'requirements_review' => (
        bg: const Color(0xFFFFF7ED),
        fg: const Color(0xFFC2410C),
        icon: Icons.fact_check_outlined,
        title: 'Requirements Under Review',
        body:
            'Your follow-up requirements were submitted. ELECOM must approve them before you are published as an official candidate.',
      ),
      'rejected' => (
        bg: const Color(0xFFFFF1F2),
        fg: const Color(0xFFBE123C),
        icon: Icons.cancel_rounded,
        title: requirementsRejected
            ? 'Requirements Rejected'
            : 'Filing Rejected',
        body:
            'ELECOM reviewed your filing and marked it rejected. Please check the reason below or contact ELECOM for clarification.',
      ),
      _ => (
        bg: const Color(0xFFEFF6FF),
        fg: const Color(0xFF2563EB),
        icon: Icons.hourglass_top_rounded,
        title: 'Filing Under Review',
        body:
            'Your candidate filing was submitted. ELECOM will review your eligibility before publishing.',
      ),
    };
    final reason = (application['rejection_reason'] ?? '').toString().trim();
    final partyCode = (application['party_code'] ?? '').toString().trim();
    final name =
        [
              application['first_name'],
              application['middle_name'],
              application['last_name'],
            ]
            .map((part) => (part ?? '').toString().trim())
            .where((part) => part.isNotEmpty)
            .join(' ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPremiumMode
            ? Colors.white.withValues(alpha: 0.88)
            : isDark
            ? const Color(0xFF242433)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPremiumMode
              ? Colors.white.withValues(alpha: 0.78)
              : isDark
              ? Colors.white12
              : Colors.black12,
        ),
        boxShadow: isPremiumMode
            ? [
                BoxShadow(
                  color: _premiumBlue.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(colors.icon, color: colors.fg, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          colors.title,
                          style: TextStyle(
                            color: colors.fg,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Status: ${status.toUpperCase()}',
                          style: TextStyle(
                            color: colors.fg,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              colors.body,
              style: TextStyle(
                color: mutedColor,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (status == 'approved' && partyCode.isNotEmpty) ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _premiumBlue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _premiumBlue.withValues(alpha: 0.16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_open_rounded,
                        color: _premiumBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Party security code',
                              style: TextStyle(
                                color: mutedColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              partyCode,
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: partyCode),
                          );
                          if (context.mounted) {
                            AppToast.success(
                              context,
                              'Party security code copied.',
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: 'Copy code',
                        style: IconButton.styleFrom(
                          foregroundColor: _premiumBlue,
                          backgroundColor: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Reason: $reason',
                style: const TextStyle(
                  color: Color(0xFFBE123C),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _StatusLine(label: 'Candidate', value: name),
            _StatusLine(
              label: 'Organization',
              value: (application['organization'] ?? '').toString(),
            ),
            _StatusLine(
              label: 'Position',
              value: (application['position'] ?? '').toString(),
            ),
            _StatusLine(
              label: 'Program',
              value: (application['program'] ?? '').toString(),
            ),
            _StatusLine(
              label: 'Section',
              value: (application['year_section'] ?? '').toString(),
            ),
            if (status == 'requirements_pending' ||
                status == 'requirements_review') ...[
              const SizedBox(height: 12),
              _CandidateRequirementsCard(
                application: application,
                isPremiumMode: isPremiumMode,
                onSubmitted: onRequirementsSubmitted,
              ),
            ],
            const SizedBox(height: 10),
            if (canFileAgain) ...[
              Text(
                'You may correct your filing and submit again.',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: onFileAgain,
                  icon: const Icon(Icons.edit_document),
                  label: const Text('File Again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ] else
              Text(
                requirementsRejected
                    ? 'Your follow-up requirements were rejected. You cannot file again for this election. Contact ELECOM for clarification.'
                    : 'You cannot submit another candidate filing for this election.',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CandidateRequirementsCard extends StatefulWidget {
  const _CandidateRequirementsCard({
    required this.application,
    required this.isPremiumMode,
    required this.onSubmitted,
  });

  final Map<String, dynamic> application;
  final bool isPremiumMode;
  final Future<void> Function() onSubmitted;

  @override
  State<_CandidateRequirementsCard> createState() =>
      _CandidateRequirementsCardState();
}

class _CandidateRequirementsCardState
    extends State<_CandidateRequirementsCard> {
  File? _photo;
  File? _enrollment;
  File? _grades;
  File? _goodMoral;
  bool _submitting = false;

  bool _hasServerFile(String key) =>
      (widget.application[key] ?? '').toString().trim().isNotEmpty;

  bool get _complete =>
      _hasServerFile('requirements_photo_url') &&
      _hasServerFile('enrollment_certificate_url') &&
      _hasServerFile('grades_url') &&
      _hasServerFile('good_moral_url');

  Future<void> _pickPhoto() async {
    final result = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (result != null && mounted) setState(() => _photo = File(result.path));
  }

  Future<void> _pickPdf(String field) async {
    PlatformFile? result;
    try {
      result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
    } on MissingPluginException {
      if (mounted) {
        AppToast.warning(
          context,
          'PDF picker was just installed. Fully close and reopen the app, then try again.',
        );
      }
      return;
    }
    final path = result?.path;
    if (path == null || !mounted) return;
    setState(() {
      final file = File(path);
      switch (field) {
        case 'enrollment_certificate':
          _enrollment = file;
        case 'grades':
          _grades = file;
        case 'good_moral':
          _goodMoral = file;
      }
    });
  }

  Future<void> _submit() async {
    final files = <String, File>{};
    if (_photo case final file?) files['requirements_photo'] = file;
    if (_enrollment case final file?) files['enrollment_certificate'] = file;
    if (_grades case final file?) files['grades'] = file;
    if (_goodMoral case final file?) files['good_moral'] = file;
    final missing = <String>[
      if (!_hasServerFile('requirements_photo_url') && _photo == null)
        '2×2 picture',
      if (!_hasServerFile('enrollment_certificate_url') && _enrollment == null)
        'Certificate of Enrollment',
      if (!_hasServerFile('grades_url') && _grades == null)
        'grades for the last two consecutive semesters',
      if (!_hasServerFile('good_moral_url') && _goodMoral == null)
        'Good Moral Certificate',
    ];
    if (missing.isNotEmpty) {
      AppToast.warning(context, 'Please attach ${missing.join(', ')}.');
      return;
    }
    if (files.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ElecomMobileApi().submitCandidateRequirements(files: files);
      await widget.onSubmitted();
      if (!mounted) return;
      setState(() {
        _photo = null;
        _enrollment = null;
        _grades = null;
        _goodMoral = null;
      });
      AppToast.success(context, 'Candidate requirements submitted.');
    } catch (e) {
      if (!mounted) return;
      final message = e is ElecomApiException ? e.message : e.toString();
      AppToast.error(context, message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = widget.isPremiumMode
        ? _premiumInk
        : isDark
        ? Colors.white
        : _premiumInk;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _premiumBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _premiumBlue.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _complete
                      ? Icons.task_alt_rounded
                      : Icons.upload_file_rounded,
                  color: _complete ? const Color(0xFF15803D) : _premiumBlue,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _complete
                        ? 'Requirements complete'
                        : 'Submit follow-up requirements',
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Upload a clear 2×2 picture. The remaining documents must be PDF files (maximum 8 MB each).',
              style: TextStyle(
                color: foreground.withValues(alpha: 0.70),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            _RequirementPicker(
              title: '2×2 Picture',
              note: 'JPG or PNG image',
              selectedName: _photo?.path.split(Platform.pathSeparator).last,
              uploaded: _hasServerFile('requirements_photo_url'),
              onTap: _pickPhoto,
            ),
            _RequirementPicker(
              title: 'Certificate of Enrollment',
              note: 'PDF only',
              selectedName: _enrollment?.path
                  .split(Platform.pathSeparator)
                  .last,
              uploaded: _hasServerFile('enrollment_certificate_url'),
              onTap: () => _pickPdf('enrollment_certificate'),
            ),
            _RequirementPicker(
              title: 'Grades — Last 2 Semesters',
              note: 'One PDF containing both consecutive semesters',
              selectedName: _grades?.path.split(Platform.pathSeparator).last,
              uploaded: _hasServerFile('grades_url'),
              onTap: () => _pickPdf('grades'),
            ),
            _RequirementPicker(
              title: 'Good Moral Certificate',
              note: 'PDF only',
              selectedName: _goodMoral?.path.split(Platform.pathSeparator).last,
              uploaded: _hasServerFile('good_moral_url'),
              onTap: () => _pickPdf('good_moral'),
            ),
            if (!_complete ||
                _photo != null ||
                _enrollment != null ||
                _grades != null ||
                _goodMoral != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _submitting ? 'Uploading...' : 'Submit Requirements',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequirementPicker extends StatelessWidget {
  const _RequirementPicker({
    required this.title,
    required this.note,
    required this.selectedName,
    required this.uploaded,
    required this.onTap,
  });

  final String title;
  final String note;
  final String? selectedName;
  final bool uploaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ready = selectedName != null || uploaded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  ready
                      ? Icons.check_circle_rounded
                      : Icons.attach_file_rounded,
                  color: ready ? const Color(0xFF15803D) : _premiumBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        selectedName ??
                            (uploaded ? 'Uploaded — tap to replace' : note),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremiumMode = themeNotifier.isPremiumMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: isPremiumMode
                    ? _premiumSub
                    : isDark
                    ? Colors.white60
                    : const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isPremiumMode
                    ? _premiumInk
                    : isDark
                    ? Colors.white
                    : const Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    required this.isPremiumMode,
  });
  final String title;
  final Widget child;
  final bool isPremiumMode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: isPremiumMode
              ? _premiumSub
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 12),
      child,
    ],
  );
}

class _PhotoPickerCard extends StatelessWidget {
  const _PhotoPickerCard({
    required this.title,
    required this.subtitle,
    required this.imageFile,
    required this.isPremiumMode,
    required this.onGallery,
    required this.onCamera,
  });
  final String title;
  final String subtitle;
  final File? imageFile;
  final bool isPremiumMode;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  Future<void> _showSources(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || source == null) return;
    if (source == ImageSource.camera) {
      onCamera();
    } else {
      onGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? _premiumAccentBlue
        : _premiumBlue;
    return Column(
      children: [
        Semantics(
          button: true,
          label: imageFile == null
              ? 'Upload candidate photo, required'
              : 'Change candidate photo',
          child: Tooltip(
            message: 'Upload candidate photo',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _showSources(context),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipOval(
                          child: imageFile == null
                              ? ColoredBox(
                                  color: accent.withValues(alpha: 0.10),
                                  child: Icon(
                                    Icons.person_outline,
                                    size: 40,
                                    color: accent,
                                  ),
                                )
                              : Image.file(imageFile!, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          imageFile == null
              ? 'Latest 2x2 candidate photo • Required'
              : 'Tap to change photo',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MiniImagePicker extends StatelessWidget {
  const _MiniImagePicker({
    required this.title,
    required this.imageFile,
    required this.isPremiumMode,
    required this.onPick,
    required this.onClear,
  });

  final String title;
  final File? imageFile;
  final bool isPremiumMode;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: imageFile == null
                ? ColoredBox(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                    child: Icon(
                      Icons.image_outlined,
                      color: isPremiumMode ? _premiumBlue : null,
                    ),
                  )
                : Image.file(imageFile!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            imageFile == null ? '$title optional' : '$title selected',
            style: TextStyle(
              color: isPremiumMode ? _premiumInk : null,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          onPressed: onPick,
          icon: Icon(
            Icons.upload_rounded,
            color: isPremiumMode ? _premiumBlue : null,
          ),
          tooltip: 'Upload logo',
        ),
        if (imageFile != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Remove logo',
          ),
      ],
    );
  }
}

TextStyle _filingValueStyle(BuildContext context) => TextStyle(
  fontSize: 14,
  color:
      Theme.of(context).brightness == Brightness.dark &&
          !themeNotifier.isPremiumMode
      ? const Color(0xFFE2E8F0)
      : const Color(0xFF1E293B),
);

class _FilingFieldLabel extends StatelessWidget {
  const _FilingFieldLabel({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color:
              Theme.of(context).brightness == Brightness.dark &&
                  !themeNotifier.isPremiumMode
              ? const Color(0xFF94A3B8)
              : const Color(0xFF64748B),
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _FilingTextField extends StatelessWidget {
  const _FilingTextField({
    required this.controller,
    required this.decoration,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.readOnly = false,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.minLines,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final bool obscureText;
  final bool enableSuggestions;
  final bool autocorrect;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _FilingFieldLabel(
    label: decoration.labelText!,
    child: TextFormField(
      controller: controller,
      validator: validator,
      focusNode: focusNode,
      readOnly: readOnly,
      obscureText: obscureText,
      enableSuggestions: enableSuggestions,
      autocorrect: autocorrect,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      style: _filingValueStyle(context),
      scrollPadding: const EdgeInsets.only(bottom: 120),
      decoration: InputDecoration(
        hintText: decoration.hintText,
        helperText: decoration.helperText,
        helperMaxLines: decoration.helperMaxLines,
        helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
    ),
  );
}

class _FilingSelectField extends StatelessWidget {
  const _FilingSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.validator,
  });
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;
  final FormFieldValidator<String>? validator;

  Future<String?> _choose(BuildContext context) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: options.length,
                  itemBuilder: (context, index) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    title: Text(
                      options[index],
                      style: _filingValueStyle(context),
                    ),
                    trailing: options[index] == value
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(context, options[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _FilingFieldLabel(
    label: label,
    child: FormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      validator: validator,
      builder: (field) => Semantics(
        button: true,
        enabled: onChanged != null,
        label: label,
        value: value,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onChanged == null || options.isEmpty
              ? null
              : () async {
                  final selected = await _choose(context);
                  if (!context.mounted || selected == null) return;
                  field.didChange(selected);
                  onChanged!(selected);
                },
          child: InputDecorator(
            isEmpty: value == null,
            decoration: InputDecoration(
              enabled: onChanged != null,
              errorText: field.errorText,
              suffixIcon: Icon(
                onChanged == null ? Icons.lock_outline : Icons.expand_more,
                size: 18,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 24,
              ),
            ),
            child: Text(
              value ?? 'Select',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _filingValueStyle(context),
            ),
          ),
        ),
      ),
    ),
  );
}
