import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/auth_assets.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

/// Figma SVG prefix icon for light auth underline fields.
class AuthFieldIcon extends StatelessWidget {
  const AuthFieldIcon._({
    required this.asset,
    required this.width,
    required this.height,
    this.usePrefixSlot = true,
  });

  const AuthFieldIcon.name()
      : this._(
          asset: AuthAssets.nameIcon,
          width: AppSizes.authNameIconWidth,
          height: AppSizes.authNameIconHeight,
        );

  const AuthFieldIcon.email()
      : this._(
          asset: AuthAssets.emailIcon,
          width: AppSizes.authEmailIconWidth,
          height: AppSizes.authEmailIconHeight,
        );

  const AuthFieldIcon.phone()
      : this._(
          asset: AuthAssets.phoneIcon,
          width: AppSizes.authPhoneIconWidth,
          height: AppSizes.authPhoneIconHeight,
        );

  const AuthFieldIcon.password()
      : this._(
          asset: AuthAssets.passwordIcon,
          width: AppSizes.authPasswordIconWidth,
          height: AppSizes.authPasswordIconHeight,
        );

  final String asset;
  final double width;
  final double height;
  final bool usePrefixSlot;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.isLight(context)
        ? AppTheme.lightOnSurface
        : AppTheme.primary;

    final icon = SvgPicture.asset(
      asset,
      width: width,
      height: height,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

    if (!usePrefixSlot) return icon;

    return SizedBox(
      width: AppSizes.authFieldPrefixWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: icon,
      ),
    );
  }
}
