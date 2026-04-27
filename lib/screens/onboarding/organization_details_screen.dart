import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_gradient_background.dart';
import 'select_dob_screen.dart';

class OrganizationDetailsScreen extends StatefulWidget {
  const OrganizationDetailsScreen({
    super.key,
    required this.accountType,
  });

  final String accountType;

  @override
  State<OrganizationDetailsScreen> createState() =>
      _OrganizationDetailsScreenState();
}

class _OrganizationDetailsScreenState extends State<OrganizationDetailsScreen> {
  int _step = 1;
  final _orgNameController = TextEditingController();
  final _workEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _industryController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _isGov => widget.accountType.trim().toLowerCase() == 'government';

  @override
  void dispose() {
    _orgNameController.dispose();
    _workEmailController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _industryController.dispose();
    _locationController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  bool _validateStepOne() {
    final orgName = _orgNameController.text.trim();
    final email = _workEmailController.text.trim();
    final website = _websiteController.text.trim();
    final description = _descriptionController.text.trim();

    if (orgName.isEmpty || email.isEmpty || website.isEmpty || description.isEmpty) {
      setState(() => _error = 'Please complete all required organization details.');
      return false;
    }
    final emailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!emailOk) {
      setState(() => _error = 'Please enter a valid work email.');
      return false;
    }
    final websiteOk = website.startsWith('http://') || website.startsWith('https://');
    if (!websiteOk) {
      setState(() => _error = 'Website must start with http:// or https://');
      return false;
    }
    return true;
  }

  bool _validateStepTwo() {
    final industry = _industryController.text.trim();
    final location = _locationController.text.trim();
    final contact = _contactPhoneController.text.trim();
    if (industry.isEmpty || location.isEmpty || contact.isEmpty) {
      setState(() => _error = 'Please complete industry, location, and contact phone.');
      return false;
    }
    return true;
  }

  Future<void> _onContinue() async {
    if (_saving) return;
    if (_step == 1) {
      if (!_validateStepOne()) return;
      setState(() {
        _error = null;
        _step = 2;
      });
      return;
    }

    if (!_validateStepTwo()) return;

    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final orgName = _orgNameController.text.trim();
      final email = _workEmailController.text.trim().toLowerCase();
      final website = _websiteController.text.trim();
      final description = _descriptionController.text.trim();
      final industry = _industryController.text.trim();
      final location = _locationController.text.trim();
      final contact = _contactPhoneController.text.trim();

      await UserService().updateUserProfile(
        uid: uid,
        orgProfileCompleted: true,
        organizationDetails: {
          'orgName': orgName,
          'workEmail': email,
          'website': website,
          'description': description,
          'industry': industry,
          'location': location,
          'contactPhone': contact,
          'orgType': _isGov ? 'government' : 'business',
          'entityLabel': _isGov ? 'department' : 'company',
        },
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SelectDobScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save organization details. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isGov ? 'Government details' : 'Business details';
    final stepTitle = _step == 1 ? 'Step 1 of 2' : 'Step 2 of 2';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.onboarding,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stepTitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tell us more about your organization before continuing.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                if (_step == 1) ...[
                  _field(
                    controller: _orgNameController,
                    label: _isGov ? 'Department / agency name' : 'Business name',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _workEmailController,
                    label: _isGov ? 'Official government email' : 'Work email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _websiteController,
                    label: _isGov ? 'Official website' : 'Website',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _descriptionController,
                    label: _isGov ? 'Department mission / services' : 'What does your business do?',
                    maxLines: 4,
                  ),
                ] else ...[
                  _field(
                    controller: _industryController,
                    label: _isGov ? 'Department category' : 'Industry',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _locationController,
                    label: _isGov ? 'Office location' : 'Business location',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _contactPhoneController,
                    label: _isGov ? 'Office contact phone' : 'Business contact phone',
                    keyboardType: TextInputType.phone,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.buttonBackground,
                      foregroundColor: AppTheme.buttonTextColor,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _step == 1 ? 'Next' : 'Continue',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                if (_step == 2) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () {
                              setState(() {
                                _error = null;
                                _step = 1;
                              });
                            },
                      child: const Text('Back to previous step'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
      ),
    );
  }
}
