import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/bottom_nav_figma_tokens.dart';
import '../../../core/widgets/create_menu_style_row.dart';

/// Album picker for post upload — Recents / Favourites / All Albums.
/// Menu rows match the bottom-nav create hub pill style.
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

  static const List<({String label, IconData icon})> options = [
    (label: 'Recents', icon: Icons.photo_library_outlined),
    (label: 'Favourites', icon: Icons.favorite_border_rounded),
    (label: 'All Albums', icon: Icons.grid_view_outlined),
  ];

  /// Wider than the create hub so longer album labels fit.
  static const double menuDesignWidth = 149;

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

    final layout = BottomNavLayout.of(context);
    final triggerTopLeft = box.localToGlobal(Offset.zero);
    final triggerSize = box.size;
    final menuWidth = layout.s(AlbumPickerDropdown.menuDesignWidth);
    final screenWidth = MediaQuery.sizeOf(context).width;
    const edgePad = 8.0;

    final idealLeft =
        triggerTopLeft.dx + (triggerSize.width - menuWidth) / 2;
    final left = idealLeft.clamp(
      edgePad,
      (screenWidth - menuWidth - edgePad).clamp(edgePad, screenWidth),
    );
    final top = triggerTopLeft.dy +
        triggerSize.height +
        AppSpacing.xs;

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
                layout: layout,
                menuWidth: menuWidth,
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
  const _AlbumPickerMenuPanel({
    required this.layout,
    required this.menuWidth,
    required this.onSelected,
  });

  final BottomNavLayout layout;
  final double menuWidth;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final rowGap = layout.s(BottomNavFigmaTokens.createMenuRowGap);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: menuWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < AlbumPickerDropdown.options.length; i++) ...[
              if (i > 0) SizedBox(height: rowGap),
              CreateMenuStyleRow(
                layout: layout,
                width: menuWidth,
                label: AlbumPickerDropdown.options[i].label,
                icon: AlbumPickerDropdown.options[i].icon,
                onTap: () => onSelected(AlbumPickerDropdown.options[i].label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
