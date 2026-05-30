import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/session/user_session.dart';
import '../../../core/utils/toast_service.dart';
import '../data/elecom_mobile_api.dart';

class CandidateFilingScreen extends StatefulWidget {
  const CandidateFilingScreen({super.key});

  @override
  State<CandidateFilingScreen> createState() => _CandidateFilingScreenState();
}

class _CandidateFilingScreenState extends State<CandidateFilingScreen> {
  static const List<String> _organizations = [
    'USG',
    'SITE',
    'PAFE',
    'AFPROTECHS',
  ];

  static const List<String> _positions = [
    'President',
    'Vice President',
    'General Secretary',
    'Associate Secretary',
    'Treasurer',
    'Auditor',
    'Public Information Officer',
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
    'BTLED-1A',
    'BTLED-1B',
    'BTLED-1C',
    'BTLED-1D',
    'BTLED-2A',
    'BTLED-2B',
    'BTLED-2C',
    'BTLED-2D',
    'BTLED-3A',
    'BTLED-3B',
    'BTLED-3C',
    'BTLED-3D',
    'BTLED-4A',
    'BTLED-4B',
    'BTLED-4C',
    'BTLED-4D',
    'BFPT-1A',
    'BFPT-1B',
    'BFPT-1C',
    'BFPT-1D',
    'BFPT-2A',
    'BFPT-2B',
    'BFPT-2C',
    'BFPT-2D',
    'BFPT-3A',
    'BFPT-3B',
    'BFPT-3C',
    'BFPT-3D',
    'BFPT-4A',
    'BFPT-4B',
    'BFPT-4C',
    'BFPT-4D',
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

  String _candidateType = 'Independent';
  String? _organization;
  String? _position;
  String? _program;
  String? _yearSection;
  File? _candidatePhoto;
  File? _partyLogo;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _hydrateFromSession();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _platformController.dispose();
    _partyNameController.dispose();
    super.dispose();
  }

  void _hydrateFromSession() {
    _studentIdController.text = (UserSession.studentId ?? '').trim();
    final parts = (UserSession.fullName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return;
    _firstNameController.text = parts.first;
    if (parts.length == 2) {
      _lastNameController.text = parts.last;
    } else if (parts.length > 2) {
      _middleNameController.text = parts.sublist(1, parts.length - 1).join(' ');
      _lastNameController.text = parts.last;
    }
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
      await _api.submitCandidateApplication(
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
          'party_name': _candidateType == 'Political Party'
              ? _partyNameController.text.trim()
              : '',
        },
      );
      if (!mounted) return;
      AppToast.success(
        context,
        'Candidate filing submitted. Please wait for ELECOM approval.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e is ElecomApiException
          ? e.message.replaceFirst(RegExp(r'^Request failed \(\d+\):\s*'), '')
          : 'Failed to submit candidate filing.';
      AppToast.error(context, message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(title: const Text('Candidate Filing')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Text(
                'Request to Run',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Submit your information and photo. ELECOM will review your eligibility before you appear as an official candidate.',
                style: TextStyle(
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              _Section(
                title: 'Candidate Type',
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Independent',
                      label: Text('Independent'),
                      icon: Icon(Icons.person_outline_rounded),
                    ),
                    ButtonSegment(
                      value: 'Political Party',
                      label: Text('Party'),
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
                subtitle: 'Required. Upload an actual candidate photo.',
                imageFile: _candidatePhoto,
                onGallery: () => _pickCandidatePhoto(ImageSource.gallery),
                onCamera: () => _pickCandidatePhoto(ImageSource.camera),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'Student Information',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _studentIdController,
                      validator: _required,
                      textInputAction: TextInputAction.next,
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
                            textInputAction: TextInputAction.next,
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
                            textInputAction: TextInputAction.next,
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
                      textInputAction: TextInputAction.next,
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
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _organization,
                      validator: _required,
                      items: _organizations
                          .map(
                            (org) =>
                                DropdownMenuItem(value: org, child: Text(org)),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _organization = value),
                      decoration: const InputDecoration(
                        labelText: 'Organization',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _position,
                      validator: _required,
                      items: _positions
                          .map(
                            (position) => DropdownMenuItem(
                              value: position,
                              child: Text(position),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _position = value),
                      decoration: const InputDecoration(
                        labelText: 'Position',
                        prefixIcon: Icon(Icons.workspace_premium_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _program,
                            validator: _required,
                            items: _programs
                                .map(
                                  (program) => DropdownMenuItem(
                                    value: program,
                                    child: Text(program),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() {
                              _program = value;
                              if (_yearSection != null &&
                                  !_yearSection!.startsWith('$value-')) {
                                _yearSection = null;
                              }
                            }),
                            decoration: const InputDecoration(
                              labelText: 'Program',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _yearSection,
                            validator: _required,
                            items: _yearSections
                                .where(
                                  (section) =>
                                      _program == null ||
                                      section.startsWith('$_program-'),
                                )
                                .map(
                                  (section) => DropdownMenuItem(
                                    value: section,
                                    child: Text(section),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _yearSection = value),
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
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _partyNameController,
                        validator: _candidateType == 'Political Party'
                            ? _required
                            : null,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Party name',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _MiniImagePicker(
                        title: 'Party logo',
                        imageFile: _partyLogo,
                        onPick: _pickPartyLogo,
                        onClear: () => setState(() => _partyLogo = null),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Submitting...' : 'Submit Filing'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242433) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
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
    required this.onGallery,
    required this.onCamera,
  });

  final String title;
  final String subtitle;
  final File? imageFile;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242433) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
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
                            : const Color(0xFFEAF1FF),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Color(0xFF2563EB),
                          size: 34,
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
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
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
    required this.onPick,
    required this.onClear,
  });

  final String title;
  final File? imageFile;
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
                    child: const Icon(Icons.image_outlined),
                  )
                : Image.file(imageFile!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            imageFile == null ? '$title optional' : '$title selected',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: onPick,
          icon: const Icon(Icons.upload_rounded),
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
