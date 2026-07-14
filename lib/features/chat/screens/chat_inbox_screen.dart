import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_padding.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_summary_model.dart';
import '../utils/chat_constants.dart';
import '../widgets/chat_tile.dart';
import 'chat_thread_screen.dart';
import 'message_requests_screen.dart';
import 'new_message_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final ChatController _controller;
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  String? _currentUid;
  AppUserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _controller = ChatController(uid: _currentUid ?? '');
    _controller.addListener(_onControllerChange);
    _searchController.addListener(_onSearchChanged);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (_currentUid == null) return;
    final user = await _userService.getUser(_currentUid!);
    if (!mounted || user == null) return;
    setState(() {
      _currentUser = user;
    });
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  List<ChatSummaryModel> get _primarySummaries {
    return _controller.summaries.where((s) {
      final rs = s.requestStatus;
      return rs == null ||
          rs == RequestStatus.none ||
          rs == RequestStatus.accepted;
    }).toList();
  }

  List<ChatSummaryModel> get _filteredPrimarySummaries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _primarySummaries;
    return _primarySummaries
        .where((s) => s.title.toLowerCase().contains(query))
        .toList();
  }

  List<ChatSummaryModel> get _requestSummaries {
    return _controller.summaries.where((s) {
      return s.requestStatus == RequestStatus.pending;
    }).toList();
  }

  String get _inboxHeaderName {
    final user = _currentUser;
    if (user == null) return '';
    final username = (user.username ?? '').trim();
    if (username.isNotEmpty) return username;
    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;
    return '';
  }

  Future<void> _openThread(ChatSummaryModel summary) async {
    if (_currentUid == null) return;

    final currentUser = _currentUser ?? await _userService.getUser(_currentUid!);
    if (!mounted || currentUser == null) return;
    _currentUser ??= currentUser;

    if (summary.type == ChatTypes.group) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatThreadScreen(
            chatId: summary.chatId,
            currentUser: currentUser,
            chatType: ChatTypes.group,
            groupName: summary.title,
            groupImageUrl: summary.avatarUrl,
            participantIds: summary.participantIds,
          ),
        ),
      );
      return;
    }

    final otherUid = summary.participantIds.firstWhere(
      (id) => id != _currentUid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return;

    final otherUser = AppUserModel(
      uid: otherUid,
      email: '',
      displayName: summary.title,
      profileImage:
          summary.avatarUrl.trim().isNotEmpty ? summary.avatarUrl : null,
      createdAt: Timestamp.now(),
    );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(
          chatId: summary.chatId,
          currentUser: currentUser,
          otherUser: otherUser,
        ),
      ),
    );
  }

  void _openNewMessage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NewMessageScreen()));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _ChatNotesRow(
              summaries: _primarySummaries,
              currentUid: _currentUid,
              currentUser: _currentUser,
              onTapNote: (summary) {
                if (summary != null) {
                  _openThread(summary);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notes coming soon'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            _buildMessagesSectionHeader(),
            Expanded(child: _buildInboxList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppPadding.screenHorizontal.left,
        AppSpacing.xs,
        AppPadding.screenHorizontal.right,
        AppSpacing.xs,
      ),
      child: SizedBox(
        height: AppSizes.chatComposeButton,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.chatComposeButton,
              ),
              child: Text(
                _inboxHeaderName,
                style: AppTypography.chatInboxTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _openNewMessage,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: AppSizes.chatComposeButton,
                  height: AppSizes.chatComposeButton,
                  child: Center(
                    child: SvgPicture.asset(
                      ChatAssets.newChatIcon,
                      width: 18,
                      height: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final scale = AppSizes.chatInboxWidthScale(context);
    double scaled(double designPx) => designPx * scale;

    final searchWidth = scaled(AppSizes.chatSearchWidth);
    final searchHeight = scaled(AppSizes.chatSearchHeight);
    final searchFontSize = scaled(AppSizes.chatSearchFontSize);
    final searchLineHeight = scaled(AppSizes.chatSearchLineHeight);
    final searchIconInset = scaled(AppSizes.chatSearchIconInset);
    final searchIconSize = scaled(AppSizes.chatSearchIconSize);
    final searchIconTextGap = scaled(AppSizes.chatSearchIconTextGap);
    final searchTextHeight = searchFontSize > 0
        ? searchLineHeight / searchFontSize
        : AppTypography.chatInboxSearchInput.height;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        scaled(AppSizes.chatSearchPaddingLeft),
        AppSpacing.xs,
        scaled(AppSizes.chatSearchPaddingRight),
        scaled(AppSizes.chatInboxSectionGap),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(scaled(AppRadius.chatSearch)),
        child: Container(
          width: searchWidth,
          height: searchHeight,
          color: AppColors.chatOutgoingBubble,
          padding: EdgeInsets.only(
            left: searchIconInset,
            right: scaled(AppSpacing.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: searchIconSize,
                color: AppColors.chatThreadDateLabel,
              ),
              SizedBox(width: searchIconTextGap),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: AppTypography.chatInboxSearchInput.copyWith(
                    fontSize: searchFontSize,
                    height: searchTextHeight,
                  ),
                  cursorColor: AppColors.chatTextBlack,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: AppTypography.chatInboxSearchHint.copyWith(
                      fontSize: searchFontSize,
                      height: searchTextHeight,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesSectionHeader() {
    final requestCount = _requestSummaries.length;
    final messagesTitleWidth =
        AppSizes.chatInboxScaleW(context, AppSizes.chatMessagesTitleWidth);
    final messagesTitleHeight =
        AppSizes.chatInboxScaleH(context, AppSizes.chatMessagesTitleHeight);
    final sectionFontSize = AppSizes.chatInboxScaleW(context, 16);
    final sectionLineHeight = AppSizes.chatInboxScaleH(context, 17);
    final sectionWidth =
        AppSizes.chatInboxScaleW(context, AppSizes.chatMessagesSectionWidth);
    final sectionPaddingVertical = AppSizes.chatInboxScaleH(
      context,
      AppSizes.chatMessagesSectionPaddingVertical,
    );
    final sectionBorderWidth = AppSizes.chatInboxScaleH(
      context,
      AppSizes.chatMessagesSectionBorderWidth,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppPadding.screenHorizontal.left,
      ),
      child: Container(
        width: sectionWidth,
        padding: EdgeInsets.symmetric(vertical: sectionPaddingVertical),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.chatMessagesSectionBorder,
              width: sectionBorderWidth,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              ChatAssets.messagesTitle,
              width: messagesTitleWidth,
              height: messagesTitleHeight,
              fit: BoxFit.contain,
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        MessageRequestsScreen(requests: _requestSummaries),
                  ),
                );
              },
              child: Text(
                requestCount > 0 ? 'Requests ($requestCount)' : 'Requests',
                style: AppTypography.chatInboxRequestsTitle.copyWith(
                  fontSize: sectionFontSize,
                  height: sectionLineHeight / sectionFontSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxList() {
    if (_controller.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandMagenta),
      );
    }

    if (_controller.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.chatTextSecondary,
              size: 48,
            ),
            SizedBox(height: AppSpacing.md - AppSpacing.xs),
            Text(
              _controller.error!,
              style: AppTypography.chatTilePreview,
            ),
          ],
        ),
      );
    }

    final summaries = _filteredPrimarySummaries;
    if (summaries.isEmpty) {
      final isSearching = _searchController.text.trim().isNotEmpty;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.chat_bubble_outline,
              color: AppColors.chatTextSecondary.withValues(alpha: 0.5),
              size: 48,
            ),
            SizedBox(height: AppSpacing.md - AppSpacing.xs),
            Text(
              isSearching ? 'No conversations found' : 'No conversations yet',
              style: AppTypography.chatTilePreview,
            ),
            if (!isSearching) ...[
              SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: _openNewMessage,
                child: Text(
                  'Start a conversation',
                  style: AppTypography.chatTilePreview.copyWith(
                    color: AppColors.brandDeepMagenta,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: AppSpacing.xs, bottom: AppSizes.bottomNavBarHeight),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return ChatTile(summary: summary, onTap: () => _openThread(summary));
      },
    );
  }
}

class _ChatNotesRow extends StatelessWidget {
  const _ChatNotesRow({
    required this.summaries,
    required this.currentUid,
    required this.currentUser,
    required this.onTapNote,
  });

  final List<ChatSummaryModel> summaries;
  final String? currentUid;
  final AppUserModel? currentUser;
  final void Function(ChatSummaryModel?) onTapNote;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final noteUsers = <_NoteUser>[];

    for (final s in summaries) {
      if (s.type == ChatTypes.group) continue;
      final otherUid = s.participantIds.firstWhere(
        (id) => id != currentUid,
        orElse: () => '',
      );
      if (otherUid.isEmpty || seen.contains(otherUid)) continue;
      seen.add(otherUid);
      noteUsers.add(
        _NoteUser(
          name: s.title,
          avatarUrl: s.avatarUrl,
          summary: s,
        ),
      );
      if (noteUsers.length >= 3) break;
    }

    final sectionGap =
        AppSizes.chatInboxScaleH(context, AppSizes.chatInboxSectionGap);
    final rowHeight =
        AppSizes.chatInboxScaleH(context, AppSizes.chatNotesRowHeight);
    final itemGap =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteItemGap);
    final rowPadding =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNotesRowPaddingHorizontal);

    final currentAvatarUrl = currentUser?.profileImage?.trim();
    final currentName = (currentUser?.displayName ?? '').trim().isNotEmpty
        ? currentUser!.displayName!.trim()
        : (currentUser?.username ?? '').trim();

    return Padding(
      padding: EdgeInsets.only(bottom: sectionGap),
      child: SizedBox(
        height: rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: rowPadding),
          itemCount: noteUsers.length + 1,
          separatorBuilder: (_, _) => SizedBox(width: itemGap),
          itemBuilder: (context, index) {
            final itemWidth =
                AppSizes.chatInboxScaleW(context, AppSizes.chatNoteItemWidth);
            final stackWidth =
                AppSizes.chatInboxScaleW(context, AppSizes.chatNoteAvatarFrame);
            final stackHeightDefault = AppSizes.chatInboxScaleH(
              context,
              AppSizes.chatNoteItemStackHeight,
            );
            final stackHeightWithBubble = AppSizes.chatInboxScaleH(
              context,
              AppSizes.chatNoteItemStackHeightWithBubble,
            );

            if (index == 0) {
              final yourNoteItemWidth = AppSizes.chatInboxScaleW(
                context,
                AppSizes.chatNoteYourItemWidth,
              );
              return Align(
                alignment: Alignment.bottomCenter,
                child: _ChatNoteItem(
                  itemWidth: yourNoteItemWidth,
                  stackWidth: stackWidth,
                  stackHeight: stackHeightDefault,
                  name: currentName.isNotEmpty ? currentName : 'Your note',
                  avatarUrl: currentAvatarUrl?.isNotEmpty == true
                      ? currentAvatarUrl
                      : null,
                  noteText: 'Note..',
                  isPlaceholderBubble: true,
                  locationLabel: 'Location Off',
                  locationIconColor: AppColors.brandMagenta,
                  onTap: () => onTapNote(null),
                ),
              );
            }

            final noteUser = noteUsers[index - 1];
            final hasTopLocation =
                noteUser.locationLabel != null &&
                noteUser.locationLabel!.trim().isNotEmpty;
            return Align(
              alignment: Alignment.bottomCenter,
              child: _ChatNoteItem(
                itemWidth: itemWidth,
                stackWidth: stackWidth,
                stackHeight: noteUser.noteText == null
                    ? stackHeightDefault
                    : stackHeightWithBubble,
                name: noteUser.name,
                avatarUrl: noteUser.avatarUrl.isNotEmpty
                    ? noteUser.avatarUrl
                    : null,
                noteText: noteUser.noteText,
                noteSubtext: noteUser.noteSubtext,
                topLocationLabel:
                    hasTopLocation ? noteUser.locationLabel : null,
                onTap: () => onTapNote(noteUser.summary),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NoteUser {
  const _NoteUser({
    required this.name,
    required this.avatarUrl,
    required this.summary,
    this.noteText,
    this.noteSubtext,
    this.locationLabel,
  });

  final String name;
  final String avatarUrl;
  final ChatSummaryModel summary;
  final String? noteText;
  final String? noteSubtext;
  final String? locationLabel;
}

class _ChatNoteItem extends StatelessWidget {
  const _ChatNoteItem({
    required this.itemWidth,
    required this.stackWidth,
    required this.stackHeight,
    required this.name,
    required this.avatarUrl,
    required this.onTap,
    this.noteText,
    this.noteSubtext,
    this.isPlaceholderBubble = false,
    this.locationLabel,
    this.topLocationLabel,
    this.locationIconColor,
  });

  final double itemWidth;
  final double stackWidth;
  final double stackHeight;
  final String name;
  final String? avatarUrl;
  final String? noteText;
  final String? noteSubtext;
  final bool isPlaceholderBubble;
  final String? locationLabel;
  final String? topLocationLabel;
  final Color? locationIconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelGap =
        AppSizes.chatInboxScaleH(context, AppSizes.chatNoteLabelGap);
    final locationTopGap =
        AppSizes.chatInboxScaleH(context, AppSizes.chatNoteLocationTopGap);
    final labelSlotHeight = AppSizes.chatInboxScaleH(
      context,
      AppSizes.chatNoteNameLabelHeight,
    );
    final nameFontSize = AppSizes.chatInboxScaleW(context, 16);
    final nameLineHeight = AppSizes.chatInboxScaleH(context, 17);
    final hasBottomLocation = locationLabel != null;
    final hasTopLocation = topLocationLabel != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasTopLocation) ...[
              _NoteLocationLabel(
                label: topLocationLabel!,
                iconColor: locationIconColor ?? AppColors.chatTextSecondary,
                maxWidth: itemWidth,
              ),
              SizedBox(height: locationTopGap),
            ],
            SizedBox(
              width: stackWidth,
              height: stackHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  _buildAvatar(context),
                  if (noteText != null)
                    Positioned(
                      top: -AppSizes.chatInboxScaleH(
                        context,
                        AppSizes.chatNoteBubbleTopOffset,
                      ),
                      left: (stackWidth -
                              AppSizes.chatInboxScaleW(
                                context,
                                isPlaceholderBubble
                                    ? AppSizes.chatNoteBubbleWidth
                                    : AppSizes.chatNoteBubbleActiveWidth,
                              )) /
                          2,
                      child: _NoteBubble(
                        text: noteText!,
                        subtext: noteSubtext,
                        isPlaceholder: isPlaceholderBubble,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: labelGap),
            if (hasBottomLocation)
              SizedBox(
                height: labelSlotHeight,
                width: itemWidth,
                child: Center(
                  child: _NoteLocationLabel(
                    label: locationLabel!,
                    iconColor: locationIconColor ?? AppColors.brandMagenta,
                    maxWidth: itemWidth,
                  ),
                ),
              )
            else
              SizedBox(
                height: labelSlotHeight,
                width: itemWidth,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.chatNoteNameLabel.copyWith(
                    fontSize: nameFontSize,
                    height: nameLineHeight / nameFontSize,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final avatarFrame =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteAvatarFrame);
    final avatarFrameHeight =
        AppSizes.chatInboxScaleH(context, AppSizes.chatNoteAvatarFrame);
    final imageWidth =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteAvatarImageWidth);
    final imageHeight =
        AppSizes.chatInboxScaleH(context, AppSizes.chatNoteAvatarImageHeight);
    final imageLeft =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteAvatarImageLeft);
    final imageTop =
        AppSizes.chatInboxScaleH(context, AppSizes.chatNoteAvatarImageTop);
    final avatarIcon =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteAvatarIcon);
    final avatarTopInset = AppSizes.chatInboxScaleH(
      context,
      AppSizes.chatNoteAvatarTopInset,
    );

    Widget buildPhoto({required double width, required double height}) {
      if (hasImage) {
        return CachedNetworkImage(
          imageUrl: avatarUrl!,
          fit: BoxFit.cover,
          width: width,
          height: height,
          placeholder: (_, _) => ColoredBox(
            color: AppColors.chatSearchFill,
            child: Icon(
              Icons.person,
              color: AppColors.chatTextSecondary,
              size: avatarIcon,
            ),
          ),
          errorWidget: (_, _, _) => Icon(
            Icons.person,
            color: AppColors.chatTextSecondary,
            size: avatarIcon,
          ),
        );
      }

      return ColoredBox(
        color: AppColors.chatSearchFill,
        child: Icon(
          Icons.person,
          color: AppColors.chatTextSecondary,
          size: avatarIcon,
        ),
      );
    }

    return Positioned(
      top: avatarTopInset,
      child: SizedBox(
        width: avatarFrame,
        height: avatarFrameHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: imageLeft,
              top: imageTop,
              child: ClipOval(
                child: SizedBox(
                  width: imageWidth,
                  height: imageHeight,
                  child: buildPhoto(
                    width: imageWidth,
                    height: imageHeight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteLocationLabel extends StatelessWidget {
  const _NoteLocationLabel({
    required this.label,
    required this.iconColor,
    this.maxWidth,
  });

  final String label;
  final Color iconColor;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final iconSize =
        AppSizes.chatInboxScaleW(context, AppSizes.chatNoteLocationIcon);
    final fontSize = AppSizes.chatInboxScaleW(context, 12);
    final lineHeight = AppSizes.chatInboxScaleH(context, 17);
    final gap = AppSizes.chatInboxScaleW(context, 2);

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.near_me_outlined,
          size: iconSize,
          color: iconColor,
        ),
        SizedBox(width: gap),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: AppTypography.chatNoteLocationLabel.copyWith(
            fontSize: fontSize,
            height: lineHeight / fontSize,
          ),
        ),
      ],
    );

    if (maxWidth == null) return row;

    return SizedBox(
      width: maxWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: row,
      ),
    );
  }
}

class _NoteBubble extends StatelessWidget {
  const _NoteBubble({
    required this.text,
    this.subtext,
    this.isPlaceholder = false,
  });

  final String text;
  final String? subtext;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final hasSubtext = subtext != null && subtext!.trim().isNotEmpty;
    final designBubbleWidth = isPlaceholder
        ? AppSizes.chatNoteBubbleWidth
        : AppSizes.chatNoteBubbleActiveWidth;
    final designBubbleHeight = isPlaceholder
        ? AppSizes.chatNoteBubbleHeight
        : AppSizes.chatNoteBubbleActiveHeight;
    final designBubbleBodyHeight = isPlaceholder
        ? AppSizes.chatNoteBubbleBodyHeight
        : AppSizes.chatNoteBubbleActiveBodyHeight;

    final bubbleWidth =
        AppSizes.chatInboxScaleW(context, designBubbleWidth);
    final bubbleHeight =
        AppSizes.chatInboxScaleH(context, designBubbleHeight);
    final bubbleBodyHeight = AppSizes.chatInboxScaleH(
      context,
      designBubbleBodyHeight,
    );
    final horizontalPadding =
        AppSizes.chatInboxScaleW(context, AppSpacing.sm);
    final textAreaWidth = bubbleWidth - (horizontalPadding * 2);
    /// Speech-bubble tail sits bottom-left; nudge label toward visual center (Figma).
    final bubbleTextOffsetX =
        AppSizes.chatInboxScaleW(context, isPlaceholder ? 2 : 3);
    final placeholderFontSize = AppSizes.chatInboxScaleW(context, 14);
    final placeholderLineHeight = AppSizes.chatInboxScaleH(context, 17);
    final activeFontSize = AppSizes.chatInboxScaleW(context, 12);
    final activeLineHeight = AppSizes.chatInboxScaleH(context, 12);
    final subtextFontSize = AppSizes.chatInboxScaleW(context, 9.36);
    final subtextLineHeight = AppSizes.chatInboxScaleH(context, 11);
    final textStyle = isPlaceholder
        ? AppTypography.chatNoteBubbleText.copyWith(
            fontSize: placeholderFontSize,
            height: placeholderLineHeight / placeholderFontSize,
          )
        : AppTypography.chatNoteActiveBubbleText.copyWith(
            fontSize: activeFontSize,
            height: activeLineHeight / activeFontSize,
          );

    return SizedBox(
      width: bubbleWidth,
      height: bubbleHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              isPlaceholder
                  ? ChatAssets.noteBubble
                  : ChatAssets.noteBubbleActive,
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bubbleBodyHeight,
            child: Center(
              child: Transform.translate(
                offset: Offset(bubbleTextOffsetX, 0),
                child: SizedBox(
                  width: textAreaWidth,
                  child: isPlaceholder || !hasSubtext
                      ? Text(
                          text,
                          maxLines: isPlaceholder ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: textStyle,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textStyle,
                            ),
                            SizedBox(
                              height: AppSizes.chatInboxScaleH(context, 2),
                            ),
                            Text(
                              subtext!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTypography.chatNoteActiveBubbleSubtext
                                  .copyWith(
                                fontSize: subtextFontSize,
                                height: subtextLineHeight / subtextFontSize,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
