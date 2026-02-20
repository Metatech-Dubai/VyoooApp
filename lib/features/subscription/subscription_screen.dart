import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/mock/mock_subscription_data.dart';
import '../../core/subscription/subscription_controller.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// Subscription paywall: plan cards, feature comparison, upgrade / restore.
/// Uses mock plans when [AppConfig.useMockSubscriptions] or when RevenueCat offerings are empty.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    super.key,
    this.showRestoreButton = true,
  });

  final bool showRestoreButton;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<SubscriptionUIModel> _plans = mockSubscriptionPlans;
  Map<String, Package>? _packagesByPlanId;
  int _selectedIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    if (AppConfig.useMockSubscriptions) {
      setState(() {
        _plans = mockSubscriptionPlans;
        _packagesByPlanId = null;
        _loading = false;
      });
      return;
    }
    final controller = context.read<SubscriptionController>();
    final offerings = await controller.fetchOfferings();
    if (!mounted) return;
    if (offerings == null || offerings.current == null) {
      setState(() {
        _plans = mockSubscriptionPlans;
        _packagesByPlanId = null;
        _loading = false;
      });
      return;
    }
    final current = offerings.current!;
    final list = <SubscriptionUIModel>[];
    final map = <String, Package>{};
    for (final p in current.availablePackages) {
      final id = p.identifier;
      map[id] = p;
      list.add(SubscriptionUIModel(
        id: id,
        title: _formatPlanTitle(id),
        price: p.storeProduct.priceString,
        isPopular: id.toLowerCase().contains('subscriber'),
      ));
    }
    setState(() {
      _plans = list.isNotEmpty ? list : mockSubscriptionPlans;
      _packagesByPlanId = list.isNotEmpty ? map : null;
      _loading = false;
    });
  }

  String _formatPlanTitle(String id) {
    if (id.isEmpty) return id;
    return id[0].toUpperCase() + id.substring(1).toLowerCase().replaceAll('_', ' ');
  }

  bool get _isMockMode =>
      AppConfig.useMockSubscriptions || _packagesByPlanId == null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.profileGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      _PlanCardsRow(
                        plans: _plans,
                        selectedIndex: _selectedIndex,
                        onSelect: (i) => setState(() => _selectedIndex = i),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const Expanded(
                        child: _FeatureComparisonTable(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _UpgradeButton(
                        selectedPlan: _plans[_selectedIndex],
                        package: _packagesByPlanId?[_plans[_selectedIndex].id],
                        isMockMode: _isMockMode,
                      ),
                      if (widget.showRestoreButton) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _RestoreButton(),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PlanCardsRow extends StatelessWidget {
  const _PlanCardsRow({
    required this.plans,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<SubscriptionUIModel> plans;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(plans.length, (i) {
        final plan = plans[i];
        final selected = i == selectedIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: i < plans.length - 1 ? AppSpacing.sm : 0,
            ),
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedScale(
                scale: selected ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: AppGradients.subscriptionCardGradient,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFDE106B).withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                    border: selected
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 2,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (plan.isPopular) ...[
                              Text(
                                'Popular',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              plan.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              plan.price,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _FeatureComparisonTable extends StatelessWidget {
  const _FeatureComparisonTable();

  static const _features = [
    ('Watch live content', true, true, true),
    ('Create profile', true, true, true),
    ('Verification', false, true, true),
    ('Upload content', false, true, true),
    ('Monetize content', false, false, true),
    ('Offer subscriptions', false, false, true),
    ('Video quality', false, false, true),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tableRow(context, 'Feature', 'Standard', 'Subscriber', 'Creator', isHeader: true),
          const SizedBox(height: AppSpacing.sm),
          ..._features.map((f) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _tableRow(
                context,
                f.$1,
                f.$2 ? '✔' : '✖',
                f.$3 ? '✔' : '✖',
                f.$4 ? '✔' : '✖',
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _tableRow(
    BuildContext context,
    String feature,
    String standard,
    String subscriber,
    String creator, {
    bool isHeader = false,
  }) {
    final style = TextStyle(
      fontSize: isHeader ? 12 : 14,
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
      color: isHeader
          ? Colors.white.withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.85),
    );
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(feature, style: style, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(standard, style: style, textAlign: TextAlign.center),
        ),
        Expanded(
          child: Text(subscriber, style: style, textAlign: TextAlign.center),
        ),
        Expanded(
          child: Text(creator, style: style, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({
    required this.selectedPlan,
    required this.package,
    required this.isMockMode,
  });

  final SubscriptionUIModel selectedPlan;
  final Package? package;
  final bool isMockMode;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SubscriptionController>();

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: controller.isLoading
            ? null
            : () async {
                if (isMockMode) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mock mode active'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                if (package == null) return;
                if (selectedPlan.id.toLowerCase().contains('creator')) {
                  await controller.purchaseCreator(package!);
                } else if (selectedPlan.id.toLowerCase().contains('subscriber')) {
                  await controller.purchaseSubscriber(package!);
                } else {
                  await controller.purchaseStandard(package!);
                }
                if (context.mounted) Navigator.of(context).maybePop();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
        ),
        child: controller.isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                selectedPlan.id.toLowerCase() == 'standard' && !isMockMode
                    ? 'Continue'
                    : 'Upgrade',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _RestoreButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.read<SubscriptionController>();
    return TextButton(
      onPressed: controller.isLoading
          ? null
          : () async {
              await controller.restorePurchases();
              if (context.mounted) Navigator.of(context).maybePop();
            },
      child: Text(
        'Restore Purchases',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 14,
        ),
      ),
    );
  }
}
