import 'package:flutter/material.dart';

import '../services/app_version_update_service.dart';
import '../widgets/app_update_prompt.dart';

/// Runs version policy checks on launch and when the app resumes.
class AppVersionGate extends StatefulWidget {
  const AppVersionGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate>
    with WidgetsBindingObserver {
  AppUpdateCheckResult? _result;
  bool _checking = true;
  bool _optionalDialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runCheck(showOptionalDialog: true);
    }
  }

  Future<void> _runCheck({bool showOptionalDialog = false}) async {
    // Fast path: decide from the cached policy immediately so launch never
    // blank-screens behind the network fetch. A cached force-update policy
    // still blocks instantly; the fresh result below replaces it when ready.
    if (_checking) {
      final cachedResult =
          await AppVersionUpdateService.instance.evaluateFromCache();
      if (!mounted) return;
      if (_checking) {
        setState(() {
          _checking = false;
          _result = cachedResult;
        });
      }
    }

    final result = await AppVersionUpdateService.instance.evaluate();
    if (!mounted) return;

    setState(() {
      _checking = false;
      _result = result;
    });

    if (result.requirement == AppUpdateRequirement.optional &&
        showOptionalDialog) {
      _maybeShowOptionalDialog(result);
    }
  }

  Future<void> _maybeShowOptionalDialog(AppUpdateCheckResult result) async {
    if (_optionalDialogVisible || !mounted) return;
    _optionalDialogVisible = true;
    try {
      await showOptionalAppUpdateDialog(context, result: result);
    } finally {
      _optionalDialogVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFDE106B)),
        ),
      );
    }

    final result = _result;
    if (result != null && result.blocksApp) {
      return AppForceUpdateScreen(result: result);
    }

    if (result != null &&
        result.requirement == AppUpdateRequirement.optional &&
        !_optionalDialogVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowOptionalDialog(result);
      });
    }

    return widget.child;
  }
}
