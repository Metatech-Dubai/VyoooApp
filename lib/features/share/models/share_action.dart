import 'package:flutter/material.dart';

/// Generic share action: Share to (native), Copy Link, WhatsApp, SMS, Instagram.
class ShareActionItem {
  const ShareActionItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    this.gradient,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Gradient? gradient;
}
