import 'package:flutter/material.dart';

import '../../core/theme/app_padding.dart';
import '../../core/theme/app_spacing.dart';

/// Search tab. State preserved via AutomaticKeepAliveClientMixin.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0015),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_rounded,
                size: 64,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              AppPadding.itemGap,
              Text(
                'Search',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
