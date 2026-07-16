import 'package:flutter/material.dart';
import '../../core/widgets/settings/settings_inner_app_bar.dart';
import 'package:vyooo/core/widgets/app_gradient_background.dart';
import '../../core/theme/app_light_surface.dart';

class ChatSupportScreen extends StatefulWidget {
  const ChatSupportScreen({super.key});

  @override
  State<ChatSupportScreen> createState() => _ChatSupportScreenState();
}

class _ChatSupportScreenState extends State<ChatSupportScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    // Date Separator
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Divider(color: AppLightSurface.mutedText, thickness: 1),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppLightSurface.border,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Today',
                              style: TextStyle(
                                color: AppLightSurface.secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: AppLightSurface.mutedText, thickness: 1),
                          ),
                        ],
                      ),
                    ),

                    // Support Messages
                    _ChatBubble(
                      message: 'Hello Goku! Welcome to vyoo support.',
                      time: '08:20 AM',
                      isUser: false,
                      senderName: 'Support',
                    ),
                    _ChatBubble(
                      message: 'How can I help you?',
                      time: '08:20 AM',
                      isUser: false,
                      senderName: 'Support',
                    ),

                    // User Message
                    _ChatBubble(
                      message: 'How can I help you?',
                      time: '08:20 AM',
                      isUser: true,
                      senderName: 'You',
                      showTicks: true,
                    ),
                  ],
                ),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return const SettingsInnerAppBar(title: 'Support');
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: AppLightSurface.border,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppLightSurface.cardFill),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(
                    color: AppLightSurface.primaryText, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Type...',
                  hintStyle: TextStyle(color: AppLightSurface.mutedText),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Icon(Icons.send_rounded, color: AppLightSurface.mutedText, size: 24),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.time,
    required this.isUser,
    required this.senderName,
    this.showTicks = false,
  });

  final String message;
  final String time;
  final bool isUser;
  final String senderName;
  final bool showTicks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              senderName,
              style: TextStyle(
                color: AppLightSurface.secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFFF81945)
                    : AppLightSurface.cardFill,
                borderRadius: BorderRadius.circular(16),
                border: isUser
                    ? null
                    : Border.all(color: AppLightSurface.cardFill),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : AppLightSurface.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showTicks) ...[
                        Icon(
                          Icons.done_all_rounded,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.75)
                              : AppLightSurface.mutedText,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        time,
                        style: TextStyle(
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.75)
                              : AppLightSurface.secondaryText,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
