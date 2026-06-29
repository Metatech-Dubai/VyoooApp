import 'package:flutter/material.dart';

import '../../core/onboarding/interest_vibes_catalog.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_text_field_style.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/auth/auth_widgets.dart';
import '../../core/widgets/interest/auto_sliding_chip_row.dart';
import '../../core/widgets/onboarding_progress_bar.dart';
import '../../core/widgets/vyooo_brand_logo.dart';
import '../../state/onboarding_state.dart';

class SelectInterestsScreen extends StatefulWidget {
  const SelectInterestsScreen({
    super.key,
    this.onboardingState,
    List<String>? interests,
  }) : interests = interests ?? InterestVibesCatalog.all;

  final OnboardingState? onboardingState;
  final List<String> interests;

  @override
  State<SelectInterestsScreen> createState() => _SelectInterestsScreenState();
}

class _SelectInterestsScreenState extends State<SelectInterestsScreen> {
  static const double _horizontalPadding = 28;
  static const int _minSelections = 3;
  static const int _horizontalRowCount = 6;
  static const double _chipRowHeight = 48;
  static const double _chipRowGap = 12;
  static const double _chipGap = 10;

  OnboardingState get _state => widget.onboardingState ?? _defaultState;
  static final OnboardingState _defaultState = OnboardingState();

  late List<String> _interests;
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _interests = List<String>.from(widget.interests)..shuffle();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    _state.addListener(_onStateChanged);
  }

  void _onStateChanged() => setState(() {});

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredInterests {
    if (_searchQuery.isEmpty) return _interests;
    final matches = _interests
        .where((s) => s.toLowerCase().contains(_searchQuery))
        .toList();
    matches.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return matches;
  }

  int get _selectedCount => _state.selectedInterests.length;
  bool get _canContinue => _selectedCount >= _minSelections;

  void _toggleInterest(String id) {
    _state.toggleInterest(id);
  }

  Future<void> _onNext() async {
    if (!_canContinue) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 3 interests.')),
      );
      return;
    }
    final uid = AuthService().currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await UserService().updateUserProfile(
          uid: uid,
          interests: _state.selectedInterests,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save interests. Check your connection and try again.',
            ),
          ),
        );
        return;
      }
    }
    // [OnboardingGate] shows terms / complete screen when interests are saved.
  }

  @override
  Widget build(BuildContext context) {
    return AuthLightScaffold(
      scrollable: false,
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      stackChildren: [
        AuthFloatingNavRow(
          onBack: _onBack,
          onForward: _onNext,
          forwardEnabled: _canContinue,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const VyoooBrandLogo.auth(),
          const SizedBox(height: 16),
          const OnboardingProgressBar(progress: 0.85),
          const SizedBox(height: 40),
          _buildTitleSection(),
          const SizedBox(height: 20),
          _buildSearchBar(),
          const SizedBox(height: 20),
          Expanded(child: SingleChildScrollView(child: _buildChipsRows())),
          const SizedBox(height: 16),
          _buildHelperText(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    final height = MediaQuery.sizeOf(context).height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's your vibe?",
          style: AppTypography.onboardingSectionTitle.copyWith(
            color: AppTheme.lightOnSurface,
            fontSize: height * 0.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Powered by AI to match you with content that truly vibes with you',
          style: AppTypography.authSmallBody.copyWith(
            color: AppTheme.lightMutedBody,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.lightSearchBarFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/vyooO_icons/Home/nav_bar_icons/search.png',
            width: 22,
            height: 22,
            color: AppTheme.lightSecondaryText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              keyboardAppearance:
                  AppTextFieldStyle.keyboardAppearance(context),
              cursorColor: AppTextFieldStyle.cursorColor(context),
              style: AppTypography.input.copyWith(color: AppTheme.lightOnSurface),
              decoration: InputDecoration(
                hintText: 'Search vibes...',
                hintStyle: AppTypography.inputHint.copyWith(
                  color: AppTheme.lightHintText,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          Image.asset(
            'assets/vyooO_icons/Search/microphone.png',
            width: 22,
            height: 22,
            color: AppTheme.lightSecondaryText,
          ),
        ],
      ),
    );
  }

  Widget _buildChipsRows() {
    final rows = InterestVibesCatalog.rowsFor(
      _filteredInterests,
      rowCount: _horizontalRowCount,
    );
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Center(
          child: Text(
            'No vibes match your search',
            style: AppTypography.authSmallBody.copyWith(
              color: AppTheme.lightMutedBody,
            ),
          ),
        ),
      );
    }
    return AutoSlidingChipRows(
      rows: rows,
      rowHeight: _chipRowHeight,
      rowGap: _chipRowGap,
      chipGap: _chipGap,
      isSelected: _state.selectedInterests.contains,
      onToggle: _toggleInterest,
    );
  }

  Widget _buildHelperText() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _canContinue ? 0.6 : 1.0,
      child: Center(
        child: Text(
          'Select at least 3 vibes to continue',
          style: AppTypography.authSmallBody.copyWith(
            color: AppTheme.lightMutedBody,
          ),
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
