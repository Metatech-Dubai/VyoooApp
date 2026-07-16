import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Figma album picker drawer for post upload — Recents / Favourites / All Albums.
class AlbumPickerDropdown extends StatefulWidget {
  const AlbumPickerDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelStyle,
    this.chevronColor,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final TextStyle? labelStyle;
  final Color? chevronColor;

  static const String assetPath =
      'assets/vyooO_icons/Upload_Story_Live/album_picker_menu.svg';

  static const List<String> options = [
    'Recents',
    'Favourites',
    'All Albums',
  ];

  @override
  State<AlbumPickerDropdown> createState() => _AlbumPickerDropdownState();
}

class _AlbumPickerDropdownState extends State<AlbumPickerDropdown> {
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _removeOverlay();
      return;
    }
    _showOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_isOpen && mounted) {
      setState(() => _isOpen = false);
    }
  }

  void _showOverlay() {
    final triggerContext = _triggerKey.currentContext;
    if (triggerContext == null) return;
    final box = triggerContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    final triggerTopLeft = box.localToGlobal(Offset.zero);
    final triggerSize = box.size;
    final menuWidth = AppSizes.uploadAlbumPickerMenuWidth;
    final screenWidth = MediaQuery.sizeOf(context).width;
    const edgePad = 8.0;

    // Center the menu under the Recents + chevron row so it sits by the arrow.
    final idealLeft =
        triggerTopLeft.dx + (triggerSize.width - menuWidth) / 2;
    final left = idealLeft.clamp(
      edgePad,
      (screenWidth - menuWidth - edgePad).clamp(edgePad, screenWidth),
    );
    final top = triggerTopLeft.dy +
        triggerSize.height +
        AppSizes.uploadAlbumPickerMenuOffsetY;

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeOverlay,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: _AlbumPickerMenuPanel(
                onSelected: (option) {
                  _removeOverlay();
                  widget.onChanged(option);
                },
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = widget.labelStyle ??
        AppTypography.chatTileName.copyWith(
          color: AppColors.chatTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        );
    final chevronColor =
        widget.chevronColor ?? AppColors.chatAppBarActionIcon;

    return GestureDetector(
      key: _triggerKey,
      behavior: HitTestBehavior.opaque,
      onTap: _toggleMenu,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.value, style: labelStyle),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            _isOpen
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: chevronColor,
            size: AppSizes.uploadAlbumPickerChevron,
          ),
        ],
      ),
    );
  }
}

class _AlbumPickerMenuPanel extends StatelessWidget {
  const _AlbumPickerMenuPanel({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: AppSizes.uploadAlbumPickerMenuWidth,
        height: AppSizes.uploadAlbumPickerMenuHeight,
        child: Stack(
          children: [
            SvgPicture.asset(
              AlbumPickerDropdown.assetPath,
              width: AppSizes.uploadAlbumPickerMenuWidth,
              height: AppSizes.uploadAlbumPickerMenuHeight,
              fit: BoxFit.fill,
            ),
            Column(
              children: [
                for (var i = 0; i < AlbumPickerDropdown.options.length; i++)
                  _AlbumPickerMenuRow(
                    onTap: () => onSelected(AlbumPickerDropdown.options[i]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumPickerMenuRow extends StatelessWidget {
  const _AlbumPickerMenuRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.uploadAlbumPickerMenuRowHeight,
      width: AppSizes.uploadAlbumPickerMenuWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white24,
          highlightColor: Colors.white12,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
