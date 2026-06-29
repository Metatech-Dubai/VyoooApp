import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/models/parent_consent_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dob_validation.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/widgets/onboarding_progress_bar.dart';
import '../../core/widgets/vyooo_brand_logo.dart';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class SelectDobScreen extends StatefulWidget {
  const SelectDobScreen({super.key, this.onDobSelected});

  /// Called with selected valid date when user taps Next.
  final void Function(DateTime date)? onDobSelected;

  @override
  State<SelectDobScreen> createState() => _SelectDobScreenState();
}

class _SelectDobScreenState extends State<SelectDobScreen> {
  static const double _horizontalPadding = 28;
  static const double _progressFill = 0.4;
  static const double _pickerHeight = 190;
  static const double _pickerItemExtent = 44;

  late int _monthIndex;
  late int _dayIndex;
  late int _yearIndex;
  late List<int> _years;
  late List<int> _days;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _yearController;

  int get _month => _monthIndex + 1;
  int get _year => _years[_yearIndex];
  int get _day => _days[_dayIndex];

  DateTime get _selectedDate => DateTime(_year, _month, _day);
  bool get _isValid => DobValidation.isValidBirthDate(_selectedDate);

  @override
  void initState() {
    super.initState();
    _years = DobValidation.allowedYears;
    final defaultYear = DateTime.now().year - 25;
    _yearIndex = _years.indexOf(defaultYear).clamp(0, _years.length - 1);
    if (_yearIndex < 0) _yearIndex = _years.length ~/ 2;
    _monthIndex = 0;
    _dayIndex = 0;
    _updateDaysList();
    _monthController = FixedExtentScrollController(initialItem: _monthIndex);
    _dayController = FixedExtentScrollController(initialItem: _dayIndex);
    _yearController = FixedExtentScrollController(initialItem: _yearIndex);
  }

  void _updateDaysList() {
    final maxDay = DobValidation.daysInMonth(_year, _month);
    _days = List.generate(maxDay, (i) => i + 1);
    _dayIndex = _dayIndex.clamp(0, _days.length - 1);
    if (_days.isNotEmpty && _day > _days.last) {
      _dayIndex = _days.length - 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dayController.hasClients && _dayIndex < _days.length) {
        _dayController.jumpToItem(_dayIndex);
      }
    });
  }

  @override
  void dispose() {
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _onMonthChanged(int index) {
    setState(() {
      _monthIndex = index;
      _updateDaysList();
    });
  }

  void _onDayChanged(int index) {
    setState(() => _dayIndex = index);
  }

  void _onYearChanged(int index) {
    setState(() {
      _yearIndex = index;
      _updateDaysList();
    });
  }

  Future<void> _onNext() async {
    if (!_isValid) return;
    widget.onDobSelected?.call(_selectedDate);
    final uid = AuthService().currentUser?.uid;
    final needsParent = DobValidation.requiresParentalConsent(_selectedDate);
    if (uid != null && uid.isNotEmpty) {
      try {
        final dobString =
            '${_year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}-${_day.toString().padLeft(2, '0')}';
        await UserService().updateUserProfile(
          uid: uid,
          dob: dobString,
          parentConsentStatus: needsParent
              ? ParentConsentStatusValue.pendingContact
              : ParentConsentStatusValue.notRequired,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your date of birth. Check your connection and try again.',
            ),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    // Do not push ParentContact / AddProfile here. [AuthWrapper] rebuilds from the user
    // stream after DOB saves and [OnboardingRouteResolver] already picks the next screen.
    // Pushing duplicated routes (e.g. two ParentContact screens) broke navigation after
    // "Send request" — the gate showed one instance while another stayed underneath.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    return AuthLightScaffold(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      stackChildren: [
        AuthFloatingNavRow(
          onBack: _onBack,
          onForward: _onNext,
          forwardEnabled: _isValid,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const VyoooBrandLogo.auth(),
          const SizedBox(height: 16),
          const OnboardingProgressBar(progress: _progressFill),
          const SizedBox(height: 40),
          _buildAvatar(),
          const SizedBox(height: 30),
          Text(
            'Select your Date of birth',
            style: AppTypography.onboardingSectionTitle.copyWith(
              color: isLight ? AppTheme.lightOnSurface : null,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildPicker(isLight),
          const SizedBox(height: 16),
          _buildPrivacyText(isLight),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: Image.asset(
        'assets/vyooO_icons/Onboarding/username_profile_avatar.png',
        width: 150,
        height: 150,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildPicker(bool isLight) {
    return Container(
      height: _pickerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: CupertinoPicker.builder(
                  scrollController: _monthController,
                  itemExtent: _pickerItemExtent,
                  selectionOverlay: const SizedBox(),
                  onSelectedItemChanged: _onMonthChanged,
                  childCount: 12,
                  itemBuilder: (context, index) {
                    final selected = _monthIndex == index;

                    return Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: (selected
                                ? AppTypography.dobPickerSelected
                                : AppTypography.dobPickerUnselected)
                            .copyWith(
                          color: isLight
                              ? (selected
                                  ? AppTheme.lightOnSurface
                                  : AppTheme.lightSecondaryText)
                              : null,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _monthNames[index],
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Expanded(
                flex: 1,
                child: CupertinoPicker.builder(
                  scrollController: _dayController,
                  itemExtent: _pickerItemExtent,
                  selectionOverlay: const SizedBox(),
                  onSelectedItemChanged: _onDayChanged,
                  childCount: _days.length,
                  itemBuilder: (context, index) {
                    final selected = _dayIndex == index;

                    return Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: (selected
                                ? AppTypography.dobPickerSelected
                                : AppTypography.dobPickerUnselected)
                            .copyWith(
                          color: isLight
                              ? (selected
                                  ? AppTheme.lightOnSurface
                                  : AppTheme.lightSecondaryText)
                              : null,
                        ),
                        child: Text('${_days[index]}'),
                      ),
                    );
                  },
                ),
              ),

              Expanded(
                flex: 2,
                child: CupertinoPicker.builder(
                  scrollController: _yearController,
                  itemExtent: _pickerItemExtent,
                  selectionOverlay: const SizedBox(),
                  onSelectedItemChanged: _onYearChanged,
                  childCount: _years.length,
                  itemBuilder: (context, index) {
                    final selected = _yearIndex == index;

                    return Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: (selected
                                ? AppTypography.dobPickerSelected
                                : AppTypography.dobPickerUnselected)
                            .copyWith(
                          color: isLight
                              ? (selected
                                  ? AppTheme.lightOnSurface
                                  : AppTheme.lightSecondaryText)
                              : null,
                        ),
                        child: Text('${_years[index]}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          /// CENTER SELECTION HIGHLIGHT
          Center(
            child: IgnorePointer(
              child: Container(
                height: _pickerItemExtent,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isLight
                      ? AppTheme.lightOtpBoxFill
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),

          /// TOP FADE
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isLight
                        ? [
                            AppTheme.lightScaffoldBackground,
                            AppTheme.lightScaffoldBackground.withValues(alpha: 0),
                          ]
                        : [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
          ),

          /// BOTTOM FADE
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 60,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: isLight
                        ? [
                            AppTheme.lightScaffoldBackground,
                            AppTheme.lightScaffoldBackground.withValues(alpha: 0),
                          ]
                        : [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyText(bool isLight) {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: AppTypography.onboardingPrivacyBody.copyWith(
            color: isLight ? AppTheme.lightMutedBody : null,
          ),
          children: [
            TextSpan(
              text: 'Please refer to our ',
              style: AppTypography.onboardingPrivacyBody.copyWith(
                color: isLight ? AppTheme.lightMutedBody : null,
              ),
            ),
            WidgetSpan(
              child: GestureDetector(
                onTap: () {
                  // TODO: open Privacy Policy
                },
                child: Text(
                  'Privacy Policy',
                  style: AppTypography.onboardingPrivacyLink.copyWith(
                    color: isLight ? AppTheme.lightOnSurface : null,
                  ),
                ),
              ),
            ),
            TextSpan(
              text: ' for further information on how we process this data.',
              style: AppTypography.onboardingPrivacyBody.copyWith(
                color: isLight ? AppTheme.lightMutedBody : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onBack() async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    await AuthService().signOut();
  }
}
