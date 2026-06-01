import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/notifications/notification_center_store.dart';
import '../../../core/session/user_session.dart';
import '../../../core/utils/toast_service.dart';
import '../data/elecom_mobile_api.dart';
import '../student_dashboard/utils/theme_notifier.dart';

const _premiumBlue = Color(0xFF2563EB);
const _premiumAccentBlue = Color(0xFF60A5FA);
const _premiumInk = Color(0xFF0F172A);
const _premiumSub = Color(0xFF475569);
const _premiumBg = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFFFFFF),
    Color(0xFFF4F8FF),
    Color(0xFFEAF2FF),
    Color(0xFFFDFEFF),
  ],
);

class CandidateFilingScreen extends StatefulWidget {
  const CandidateFilingScreen({super.key});

  @override
  State<CandidateFilingScreen> createState() => _CandidateFilingScreenState();
}

class _CandidateFilingScreenState extends State<CandidateFilingScreen> {
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

  final ElecomMobileApi _api = ElecomMobileApi();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _platformController = TextEditingController();
  final TextEditingController _partyNameController = TextEditingController();
  final TextEditingController _partyCodeController = TextEditingController();

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
    _hydrateFromSession();
    _hydrateProfileAndStatus();
    _loadPartyNames();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _platformController.dispose();
    _partyNameController.dispose();
    _partyCodeController.dispose();
    super.dispose();
  }

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
        setState(_hydrateFromSession);
      }
    } catch (_) {
      // Keep the locally persisted session values if profile refresh fails.
    }
    await _loadApplicationStatus();
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
    try {
      final res = await _api.getCandidateApplicationStatus();
      final raw = res['application'];
      if (!mounted) return;
      setState(() {
        _existingApplication = raw is Map<String, dynamic>
            ? raw
            : raw is Map
            ? Map<String, dynamic>.from(raw)
            : null;
        _loadingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStatus = false);
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
      if (matching != null) _partyNameController.text = matching;
    });
  }

  Future<void> _pickCandidatePhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 88);
    if (picked == null) return;
    setState(() => _candidatePhoto = File(picked.path));
  }

  Future<void> _pickPartyLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() => _partyLogo = File(picked.path));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_candidatePhoto == null) {
      AppToast.warning(context, 'Upload your candidate photo first.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await _api.submitCandidateApplication(
        candidatePhoto: _candidatePhoto!,
        partyLogo: _partyLogo,
        fields: <String, String>{
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
        },
      );
      if (!mounted) return;
      setState(() {
        _existingApplication = _applicationFromSubmitResponse(res);
        _loadingStatus = false;
      });
      await NotificationCenterStore.refresh();
      if (!mounted) return;
      AppToast.success(
        context,
        'Candidate filing submitted. Please wait for ELECOM approval.',
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ElecomApiException
          ? e.message.replaceFirst(RegExp(r'^Request failed \(\d+\):\s*'), '')
          : 'Failed to submit candidate filing.';
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
    if (_loadingParties) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            minHeight: 3,
            borderRadius: BorderRadius.circular(999),
            color: isPremiumMode ? _premiumBlue : null,
          ),
          const SizedBox(height: 10),
          Text(
            'Loading available party names...',
            style: TextStyle(
              color: isPremiumMode ? _premiumSub : null,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    if (_existingPartyNames.isEmpty || _addingNewParty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _partyNameController,
            validator: _partyNameValidator,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _existingPartyNames.isEmpty
                  ? 'Party name'
                  : 'New party name',
              helperText: _existingPartyNames.isEmpty
                  ? 'Enter your party name.'
                  : 'Use this only if your party is not listed.',
              prefixIcon: const Icon(Icons.flag_outlined),
            ),
          ),
          if (_existingPartyNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _chooseExistingParty,
                icon: const Icon(Icons.groups_2_outlined, size: 18),
                label: const Text('Choose existing party'),
              ),
            ),
          ],
        ],
      );
    }

    final dropdownValue =
        _selectedPartyName != null &&
            _existingPartyNames.contains(_selectedPartyName)
        ? _selectedPartyName
        : null;
    return DropdownButtonFormField<String>(
      initialValue: dropdownValue,
      dropdownColor: Colors.white,
      validator: (_) => _partyNameValidator(null),
      items: [
        ..._existingPartyNames.map(
          (party) => DropdownMenuItem(value: party, child: Text(party)),
        ),
        const DropdownMenuItem(
          value: _addNewPartyValue,
          child: Text('Add new party name'),
        ),
      ],
      onChanged: _selectPartyName,
      decoration: const InputDecoration(
        labelText: 'Party name',
        helperText: 'Choose your party if it already exists.',
        prefixIcon: Icon(Icons.flag_outlined),
      ),
    );
  }

  Widget _buildPartyCodeField() {
    if (_addingNewParty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: _premiumBlue.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _premiumBlue.withValues(alpha: 0.16)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_reset_rounded, color: _premiumBlue, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A party security code will be generated automatically after you submit this new party.',
                  style: TextStyle(
                    color: _premiumSub,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return TextFormField(
      controller: _partyCodeController,
      validator: _partyCodeValidator,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Party security code',
        helperText: 'Enter the code shared by your party leader.',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
      ),
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
        final mutedColor = isPremiumMode
            ? _premiumSub
            : isDark
            ? Colors.white70
            : const Color(0xFF64748B);
        final existingApplication = _existingApplication;
        final baseTheme = Theme.of(context);
        final formTheme = isPremiumMode
            ? baseTheme.copyWith(
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
          data: formTheme,
          child: Scaffold(
            backgroundColor: isPremiumMode ? const Color(0xFFFDFEFF) : null,
            appBar: AppBar(
              backgroundColor: isPremiumMode ? const Color(0xFFFDFEFF) : null,
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
            body: Container(
              decoration: isPremiumMode
                  ? const BoxDecoration(gradient: _premiumBg)
                  : null,
              child: SafeArea(
                child: RefreshIndicator(
                  color: _premiumBlue,
                  onRefresh: _refreshFiling,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      children: [
                        Row(
                          children: [
                            if (isPremiumMode) ...[
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _premiumBlue.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                                child: const Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedUserCheck01,
                                    color: _premiumBlue,
                                    size: 23,
                                    strokeWidth: 1.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Request to Run',
                                    style: TextStyle(
                                      color: titleColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Submit your information and photo. ELECOM will review your eligibility before you appear as an official candidate.',
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (_loadingStatus)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (existingApplication != null)
                          _ApplicationStatusCard(
                            application: existingApplication,
                            isPremiumMode: isPremiumMode,
                            onFileAgain: () {
                              setState(() {
                                _existingApplication = null;
                                _candidatePhoto = null;
                                _partyLogo = null;
                              });
                            },
                          )
                        else ...[
                          _Section(
                            title: 'Candidate Type',
                            premiumIcon: HugeIcons.strokeRoundedUserMultiple,
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
                            premiumIcon: HugeIcons.strokeRoundedId,
                            isPremiumMode: isPremiumMode,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _studentIdController,
                                  validator: _required,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Candidate student ID',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _firstNameController,
                                        validator: _required,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'First name',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lastNameController,
                                        validator: _required,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Last name',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _middleNameController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Middle name',
                                    hintText: 'Optional',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Section(
                            title: 'Candidacy Details',
                            premiumIcon: HugeIcons.strokeRoundedUniversity,
                            isPremiumMode: isPremiumMode,
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _organization,
                                  dropdownColor: Colors.white,
                                  validator: _required,
                                  items: _availableOrganizations
                                      .map(
                                        (org) => DropdownMenuItem(
                                          value: org,
                                          child: Text(org),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) => setState(() {
                                    _setOrganization(value);
                                  }),
                                  decoration: const InputDecoration(
                                    labelText: 'Organization',
                                    prefixIcon: Icon(
                                      Icons.account_balance_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _position,
                                  dropdownColor: Colors.white,
                                  validator: _required,
                                  items: _availablePositions
                                      .map(
                                        (position) => DropdownMenuItem(
                                          value: position,
                                          child: Text(position),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _position = value),
                                  decoration: const InputDecoration(
                                    labelText: 'Position',
                                    prefixIcon: Icon(
                                      Icons.workspace_premium_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _program,
                                        dropdownColor: Colors.white,
                                        validator: _required,
                                        items: _programs
                                            .map(
                                              (program) => DropdownMenuItem(
                                                value: program,
                                                child: Text(program),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _accountProgram == null
                                            ? (value) => setState(() {
                                                _setProgram(value);
                                              })
                                            : null,
                                        decoration: const InputDecoration(
                                          labelText: 'Program',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _yearSection,
                                        dropdownColor: Colors.white,
                                        validator: _required,
                                        items: _yearSections
                                            .where(
                                              (section) =>
                                                  _sectionBelongsToProgram(
                                                    section,
                                                    _program,
                                                  ),
                                            )
                                            .map(
                                              (section) => DropdownMenuItem(
                                                value: section,
                                                child: Text(section),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _accountYearSection == null
                                            ? (value) => setState(
                                                () => _yearSection = value,
                                              )
                                            : null,
                                        decoration: const InputDecoration(
                                          labelText: 'Year/Section',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _platformController,
                                  validator: _required,
                                  minLines: 4,
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
                                  _buildPartyCodeField(),
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
                          const SizedBox(height: 20),
                          SizedBox(
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
  });

  final Map<String, dynamic> application;
  final bool isPremiumMode;
  final VoidCallback onFileAgain;

  @override
  Widget build(BuildContext context) {
    final status = (application['status'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase();
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
      'rejected' => (
        bg: const Color(0xFFFFF1F2),
        fg: const Color(0xFFBE123C),
        icon: Icons.cancel_rounded,
        title: 'Filing Rejected',
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
            const SizedBox(height: 10),
            if (status == 'rejected') ...[
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
                'You cannot submit another candidate filing for this election.',
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
    this.premiumIcon,
  });

  final String title;
  final Widget child;
  final bool isPremiumMode;
  final List<List<dynamic>>? premiumIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPremiumMode
            ? Colors.white.withValues(alpha: 0.86)
            : isDark
            ? const Color(0xFF242433)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPremiumMode
              ? Colors.white.withValues(alpha: 0.74)
              : isDark
              ? Colors.white12
              : Colors.black12,
        ),
        boxShadow: isPremiumMode
            ? [
                BoxShadow(
                  color: _premiumBlue.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (isPremiumMode && premiumIcon != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _premiumBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: premiumIcon!,
                        color: _premiumBlue,
                        size: 16,
                        strokeWidth: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isPremiumMode
                          ? _premiumInk
                          : isDark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPremiumMode
            ? Colors.white.withValues(alpha: 0.86)
            : isDark
            ? const Color(0xFF242433)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPremiumMode
              ? Colors.white.withValues(alpha: 0.74)
              : isDark
              ? Colors.white12
              : Colors.black12,
        ),
        boxShadow: isPremiumMode
            ? [
                BoxShadow(
                  color: _premiumBlue.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 88,
                height: 104,
                child: imageFile == null
                    ? ColoredBox(
                        color: isDark
                            ? Colors.white10
                            : isPremiumMode
                            ? _premiumBlue.withValues(alpha: 0.10)
                            : const Color(0xFFEAF1FF),
                        child: Center(
                          child: isPremiumMode
                              ? const HugeIcon(
                                  icon: HugeIcons.strokeRoundedUserAdd01,
                                  color: _premiumBlue,
                                  size: 34,
                                  strokeWidth: 1.8,
                                )
                              : const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 34,
                                ),
                        ),
                      )
                    : Image.file(imageFile!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isPremiumMode
                          ? _premiumInk
                          : isDark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isPremiumMode
                          ? _premiumSub
                          : isDark
                          ? Colors.white70
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onCamera,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Camera'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
