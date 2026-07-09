import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/saved_account.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/saved_accounts_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_gradient_background.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';
import '../../core/wrappers/auth_wrapper.dart';
import '../auth/sign_in_screen.dart';

class SwitchAccountsScreen extends StatefulWidget {
  const SwitchAccountsScreen({super.key});

  @override
  State<SwitchAccountsScreen> createState() => _SwitchAccountsScreenState();
}

class _SwitchAccountsScreenState extends State<SwitchAccountsScreen> {
  final _auth = AuthService();
  bool _switching = false;
  String? _switchingUid;

  Future<void> _onSelectAccount(SavedAccount account) async {
    final currentUid = _auth.currentUser?.uid;
    if (account.uid == currentUid || _switching) return;

    setState(() {
      _switching = true;
      _switchingUid = account.uid;
    });

    final result = await _auth.switchToAccount(account);
    if (!mounted) return;

    setState(() {
      _switching = false;
      _switchingUid = null;
    });

    if (result.success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
      return;
    }

    final message = (result.message ?? '').trim();
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _onAddAccount() async {
    if (_switching) return;
    final accounts = await SavedAccountsService().getAccounts();
    if (!mounted) return;
    if (accounts.length >= SavedAccountsService.maxAccounts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can save up to ${SavedAccountsService.maxAccounts} accounts on this device.',
          ),
        ),
      );
      return;
    }

    await SavedAccountsService().prepareForAddAccount();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SignInScreen(addingAccount: true),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SettingsInnerAppBar(title: 'Switch Accounts'),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: SavedAccountsService.revision,
                  builder: (context, revision, _) {
                    return FutureBuilder<List<SavedAccount>>(
                      future: SavedAccountsService().getAccounts(),
                      builder: (context, snapshot) {
                        final accounts = snapshot.data ?? const <SavedAccount>[];
                        if (accounts.isEmpty) {
                          return _EmptyState(onAddAccount: _onAddAccount);
                        }
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xl,
                          ),
                          children: [
                            _accountsCard(
                              accounts: accounts,
                              currentUid: currentUid,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _AddAccountButton(
                              onTap: _onAddAccount,
                              enabled: !_switching,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountsCard({
    required List<SavedAccount> accounts,
    required String currentUid,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < accounts.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            _AccountRow(
              account: accounts[i],
              isActive: accounts[i].uid == currentUid,
              isLoading: _switching && _switchingUid == accounts[i].uid,
              onTap: () => _onSelectAccount(accounts[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
  });

  final SavedAccount account;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = (account.profileImageUrl ?? '').trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md - 2,
          ),
          child: Row(
            children: [
              _AccountAvatar(url: avatarUrl, label: account.label),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.label,
                      style: AppTypography.authDialogOption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (account.displayName.isNotEmpty &&
                        account.username.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        account.displayName,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                    if (!account.hasStoredCredentials) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Sign in again to switch',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isActive)
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fallback = label.isNotEmpty ? label[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      child: url.isEmpty
          ? Text(
              fallback,
              style: AppTypography.authDialogOption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _AddAccountButton extends StatelessWidget {
  const _AddAccountButton({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Add account',
                style: AppTypography.authDialogOption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddAccount});

  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No saved accounts yet',
              style: AppTypography.authDialogOption.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Log in to save an account on this device, then switch between accounts here.',
              style: AppTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            _AddAccountButton(onTap: onAddAccount, enabled: true),
          ],
        ),
      ),
    );
  }
}
