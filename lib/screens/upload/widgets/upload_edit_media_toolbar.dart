import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_sizes.dart';

/// Figma edit-media toolbar tools (music → delete).
enum UploadEditMediaTool {
  music,
  adjust,
  filter,
  trim,
  speed,
  delete,
}

abstract final class UploadEditMediaToolbarAssets {
  static const String toolbar =
      'assets/vyooO_icons/Upload_Story_Live/upload_edit_media_toolbar.svg';
}

/// Figma 350×52 edit toolbar — six tappable tool buttons over the SVG.
class UploadEditMediaToolbar extends StatelessWidget {
  const UploadEditMediaToolbar({
    super.key,
    required this.onToolTap,
  });

  final ValueChanged<UploadEditMediaTool> onToolTap;

  static const double _designWidth = AppSizes.uploadEditMediaToolbarWidth;
  static const double _designHeight = AppSizes.uploadEditMediaToolbarHeight;
  static const double _buttonWidth = 51.4706;
  static const List<double> _buttonXs = [
    0,
    59.7051,
    119.412,
    179.117,
    238.824,
    298.529,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, _designWidth);
        final height = _designHeight * (width / _designWidth);
        final scale = width / _designWidth;

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SvgPicture.asset(
                UploadEditMediaToolbarAssets.toolbar,
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
              for (var i = 0; i < UploadEditMediaTool.values.length; i++)
                Positioned(
                  left: _buttonXs[i] * scale,
                  top: 0,
                  width: _buttonWidth * scale,
                  height: height,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onToolTap(UploadEditMediaTool.values[i]),
                      borderRadius: BorderRadius.circular(6.17647 * scale),
                      splashColor: Colors.white24,
                      highlightColor: Colors.white12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
