import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Typography for comments UI — light sheet on white background.
abstract final class CommentTextStyles {
  static const Color tertiary = Color(0xFF808080);
  static const Color secondary = Color(0xFF8E8E93);

  static const TextStyle sheetTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.chatTextPrimary,
    height: 1.2,
  );

  static TextStyle username({required bool verified}) => TextStyle(
    fontSize: verified ? 14 : 12,
    fontWeight: FontWeight.w500,
    color: AppColors.chatTextPrimary,
    height: 1.2,
  );

  static const TextStyle timestamp = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: tertiary,
    height: 1.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.chatTextPrimary,
    height: 1.25,
  );

  static const TextStyle metaAction = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: secondary,
    height: 1.2,
  );

  static const TextStyle likeCount = TextStyle(
    fontSize: 8,
    fontWeight: FontWeight.w400,
    color: secondary,
    height: 1.2,
  );

  static const TextStyle input = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.chatTextPrimary,
    height: 1.25,
  );

  static const TextStyle inputHint = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: secondary,
    height: 1.25,
  );

  static const TextStyle replyBanner = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: secondary,
    height: 1.2,
  );

  static const TextStyle emptyState = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: secondary,
    height: 1.25,
  );
}
