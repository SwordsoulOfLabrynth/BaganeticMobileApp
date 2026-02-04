import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/chat_errors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../providers/chat_messages_provider.dart';
import '../../providers/chat_membership_provider.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Future<void> _joinGroup(
    BuildContext context,
    ChatMembershipProvider membershipProvider,
  ) async {
    try {
      await context.read<ChatRepository>().joinGroup(widget.groupId);
      if (!context.mounted) return;

      // Refresh membership status
      membershipProvider.restart();

      Helpers.showSnackBar(
        context,
        context.l10n.translate('chat.joinedSuccess'),
      );
    } catch (error) {
      if (!context.mounted) return;
      Helpers.showSnackBar(
        context,
        _errorMessage(context.l10n, error, fallbackKey: 'chat.joinFailed'),
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(
    BuildContext context,
    ChatMessagesProvider messagesProvider,
    ChatMembershipProvider membershipProvider,
  ) async {
    if (messagesProvider.isSending) {
      return;
    }

    final l10n = context.l10n;
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    // Check if user is a member before sending
    if (!membershipProvider.memberGroupIds.contains(widget.groupId)) {
      Helpers.showSnackBar(
        context,
        l10n.translate('chat.mustBeMemberToSend'),
        isError: true,
      );
      return;
    }

    try {
      await messagesProvider.sendMessage(text);
      if (!context.mounted) {
        return;
      }
      _messageController.clear();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        _errorMessage(l10n, error, fallbackKey: 'chat.sendFailed'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ChatMessagesProvider(
            context.read<ChatRepository>(),
            groupId: widget.groupId,
          )..start(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ChatMembershipProvider(context.read<ChatRepository>())..start(),
        ),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(widget.groupName),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<ChatMessagesProvider>().restart();
                  context.read<ChatMembershipProvider>().restart();
                },
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Consumer2<ChatMessagesProvider, ChatMembershipProvider>(
            builder: (context, messagesProvider, membershipProvider, _) {
              final messages = messagesProvider.messages;
              final isMember = membershipProvider.memberGroupIds.contains(
                widget.groupId,
              );

              if (messagesProvider.isLoading && messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (messagesProvider.loadError != null && messages.isEmpty) {
                return Center(
                  child: Text(
                    _errorMessage(
                      l10n,
                      messagesProvider.loadError!,
                      fallbackKey: 'chat.loadFailed',
                    ),
                  ),
                );
              }

              final currentUserId = context
                  .read<ChatRepository>()
                  .currentUserId;
              return Column(
                children: [
                  Expanded(
                    child: messages.isEmpty
                        ? Center(child: Text(l10n.translate('chat.noMessages')))
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.pixels >=
                                  notification.metrics.maxScrollExtent - 200) {
                                messagesProvider.loadMore();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              itemCount:
                                  messages.length +
                                  (messagesProvider.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= messages.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final message = messages[index];
                                final isMe = message.senderId == currentUserId;
                                return _MessageBubble(
                                  message: message,
                                  isMe: isMe,
                                );
                              },
                            ),
                          ),
                  ),
                  if (isMember)
                    _InputBar(
                      controller: _messageController,
                      isSending: messagesProvider.isSending,
                      onSend: () => _sendMessage(
                        context,
                        messagesProvider,
                        membershipProvider,
                      ),
                    )
                  else
                    _JoinPrompt(
                      onJoin: () => _joinGroup(context, membershipProvider),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _errorMessage(
    AppLocalizations l10n,
    Object error, {
    required String fallbackKey,
  }) {
    if (error is AuthError) {
      return l10n.translate('chat.authRequired');
    }
    if (error is NetworkError) {
      return l10n.translate('auth.networkRequestFailed');
    }
    if (error is PermissionError && error.message.isNotEmpty) {
      return error.message;
    }
    if (error is ValidationError && error.message.isNotEmpty) {
      return error.message;
    }
    return l10n.translate(fallbackKey);
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final timeText = message.sentAt == null
        ? ''
        : Helpers.formatTime(message.sentAt!);
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMe
        ? const Color(0xFFB8860B)
        : Colors.grey.withValues(alpha: 0.2);
    final textColor = isMe ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message.senderName,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(message.text, style: TextStyle(color: textColor)),
          ),
          if (timeText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                timeText,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }
}

class _JoinPrompt extends StatelessWidget {
  final VoidCallback onJoin;

  const _JoinPrompt({required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.translate('chat.joinToParticipate'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB8860B),
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.translate('chat.join')),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: l10n.translate('chat.messageHint'),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: const Color(0xFFB8860B),
              onPressed: isSending ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
