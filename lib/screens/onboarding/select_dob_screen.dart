import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/platform/app_system_ui.dart';
import '../../core/models/parent_consent_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/dob_validation.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/widgets/onboarding_profile_avatar.dart';
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
    // Do not push ParentContact here. [AuthWrapper] rebuilds from the user
    // stream after DOB saves and [OnboardingRouteResolver] already picks the next screen.
    // Pushing duplicated routes (e.g. two ParentContact screens) broke navigation after
    // "Send request" — the gate showed one instance while another stayed underneath.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLightScaffold(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      stackChildren: [
        Positioned(
          right: AppSpacing.xl,
          bottom:
              AppSpacing.authFloatingNavBottom +
              AppSystemUi.bottomChromeInset(context),
          child: AuthFloatingCircleButton.forward(
            onPressed: _onNext,
            enabled: _isValid,
          ),
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
            style: AppTypography.onboardingLightSectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildPicker(),
          const SizedBox(height: 16),
          _buildPrivacyText(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return const Center(child: OnboardingProfileAvatar());
  }

  Widget _buildPicker() {
    final pickerHeight = AppSizes.onboardingDobPickerHeight;
    final itemExtent = AppSizes.onboardingDobPickerItemExtent;
    final fadeHeight = AppSizes.onboardingDobPickerFadeHeight;
    final fadeBase = AppTheme.lightScaffoldBackground;

    return CupertinoTheme(
      data: AppTheme.onboardingDobCupertinoTheme,
      child: Theme(
        data: AppTheme.light,
        child: SizedBox(
          height: pickerHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Selection band — behind wheels (Figma #787880 @ 8%, rx 7).
              Align(
                child: Container(
                  height: itemExtent,
                  decoration: BoxDecoration(
                    color: AppTheme.onboardingDobPickerSelectionFill,
                    borderRadius: BorderRadius.circular(
                      AppRadius.onboardingDobPickerSelection,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildPickerColumn(
                      scrollController: _monthController,
                      childCount: 12,
                      onSelectedItemChanged: _onMonthChanged,
                      selectedIndex: _monthIndex,
                      labelBuilder: (index) => _monthNames[index],
                      shrinkFit: true,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildPickerColumn(
                      scrollController: _dayController,
                      childCount: _days.length,
                      onSelectedItemChanged: _onDayChanged,
                      selectedIndex: _dayIndex,
                      labelBuilder: (index) => '${_days[index]}',
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildPickerColumn(
                      scrollController: _yearController,
                      childCount: _years.length,
                      onSelectedItemChanged: _onYearChanged,
                      selectedIndex: _yearIndex,
                      labelBuilder: (index) => '${_years[index]}',
                    ),
                  ),
                ],
              ),
              // Top fade — white into transparent.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: fadeHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          fadeBase,
                          fadeBase.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom fade.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: fadeHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          fadeBase,
                          fadeBase.withValues(alpha: 0),
                        ],
                      ),
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

  Widget _buildPickerColumn({
    required FixedExtentScrollController scrollController,
    required int childCount,
    required ValueChanged<int> onSelectedItemChanged,
    required int selectedIndex,
    required String Function(int index) labelBuilder,
    bool shrinkFit = false,
  }) {
    return CupertinoPicker.builder(
      scrollController: scrollController,
      itemExtent: AppSizes.onboardingDobPickerItemExtent,
      backgroundColor: Colors.transparent,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onSelectedItemChanged,
      childCount: childCount,
      itemBuilder: (context, index) => _buildPickerLabel(
        labelBuilder(index),
        _pickerItemStyle(index: index, selectedIndex: selectedIndex),
        shrinkFit: shrinkFit,
      ),
    );
  }

  /// Ignores CupertinoPicker's inherited DefaultTextStyle (dark theme → white text).
  Widget _buildPickerLabel(
    String text,
    TextStyle style, {
    bool shrinkFit = false,
  }) {
    final resolved = style.copyWith(
      color: style.color ?? const Color(0xFF000000),
      decoration: TextDecoration.none,
      inherit: false,
    );
    final label = Text(
      text,
      style: resolved,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
    );
    return Center(
      child: shrinkFit
          ? FittedBox(fit: BoxFit.scaleDown, child: label)
          : label,
    );
  }

  /// Figma: selected row black; adjacent rows ~52% black; fade with distance.
  TextStyle _pickerItemStyle({
    required int index,
    required int selectedIndex,
  }) {
    final distance = (index - selectedIndex).abs();
    if (distance == 0) {
      return AppTypography.onboardingDobPickerSelected.copyWith(
        color: const Color(0xFF000000),
        decoration: TextDecoration.none,
        inherit: false,
      );
    }
    final alpha = switch (distance) {
      1 => 0.52,
      2 => 0.38,
      _ => 0.28,
    };
    return AppTypography.onboardingDobPickerUnselected.copyWith(
      color: const Color(0xFF000000).withValues(alpha: alpha),
      inherit: false,
    );
  }

  Widget _buildPrivacyText() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: AppTypography.onboardingPrivacyBody.copyWith(
            color: AppTheme.lightMutedBody,
          ),
          children: [
            const TextSpan(text: 'Please refer to our '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () {
                  // TODO: open Privacy Policy
                },
                child: Text(
                  'Privacy Policy',
                  style: AppTypography.onboardingPrivacyLink.copyWith(
                    color: AppTheme.lightOnSurface,
                  ),
                ),
              ),
            ),
            const TextSpan(
              text: ' for further information on how we process this data.',
            ),
          ],
        ),
      ),
    );
  }
}
