import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/pagoda_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/ai_chatbot_service.dart';
import '../../../core/services/logger.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/sign_in_required_view.dart';

class ChatScreen extends StatefulWidget {
  final AIEntryContext entryContext;

  const ChatScreen({
    super.key,
    this.entryContext = const AIEntryContext.global(),
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AIChatbotService _chatbotService = AIChatbotService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AIChatMessage> _pendingMessages = [];
  final List<AIChatMessage> _sessionMessages = [];
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<AIChatMessage>>? _messageSub;
  List<AIChatMessage> _messages = const [];
  bool _isSending = false;
  bool _didWarnAboutSync = false;

  @override
  void initState() {
    super.initState();
    _messageSub = _chatbotService.messageStream().listen(
      (messages) {
        if (!mounted) return;
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      },
      onError: (error, stackTrace) {
        Logger.warn('AI chat Firestore stream failed: $error');
        if (!mounted) return;
        setState(() {
          _messages = const [];
        });
        if (_didWarnAboutSync) {
          return;
        }
        _didWarnAboutSync = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cloud chat sync is unavailable. Messages will stay in this session only.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.translate('chat.clear')),
          content: Text(l10n.translate('chat.clearConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.translate('common.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.translate('common.delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _chatbotService.clearHistory();
    if (!mounted) {
      return;
    }
    setState(() {
      _sessionMessages.clear();
      _pendingMessages.clear();
    });
  }

  Future<void> _sendMessage() async {
    final prompt = _messageController.text.trim();
    if (prompt.isEmpty || _isSending) {
      return;
    }
    if (!_chatbotService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.translate('chat.setupRequiredBody')),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final requestId = _uuid.v4().replaceAll('-', '');
    final userMessage = AIChatMessage(
      id: requestId,
      role: AIChatMessage.roleUser,
      text: prompt,
      createdAt: DateTime.now(),
    );
    final historyForRequest = _conversationHistory();

    _messageController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _pendingMessages.add(userMessage);
      _isSending = true;
    });
    final pagodas = context
        .read<PagodaProvider>()
        .allPagodas
        .map(
          (p) => AIPagodaContext(
            id: p.id,
            name: p.name,
            category: p.category,
            summary: _buildPagodaSummary(p),
            bestTime: _compactText(p.bestTimeToVisit ?? '', maxChars: 120),
            openingHours: _compactText(p.openingHours ?? '', maxChars: 90),
            location: _compactText(p.visitorLocation ?? '', maxChars: 90),
          ),
        )
        .toList(growable: false);
    final tripProvider = context.read<TripProvider>();
    AITripContext? tripContext;
    final tripId = widget.entryContext.tripId;
    if (tripId != null) {
      for (final trip in tripProvider.trips) {
        if (trip.id == tripId) {
          tripContext = AITripContext.fromTrip(trip);
          break;
        }
      }
    }
    _scrollToBottom();
    if (!mounted) return;

    try {
      final result = await _chatbotService.generateReply(
        prompt: prompt,
        requestId: requestId,
        pagodaContext: pagodas,
        entryContext: widget.entryContext,
        tripContext: tripContext,
        historyOverride: historyForRequest,
      );
      if (!mounted) return;

      final assistantMessage = AIChatMessage(
        id: '${requestId}_assistant',
        role: AIChatMessage.roleAssistant,
        text: result.reply,
        createdAt: result.createdAt,
      );
      setState(() {
        _upsertSessionMessage(userMessage);
        _upsertSessionMessage(assistantMessage);
        _pendingMessages.removeWhere((message) => message.id == requestId);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere((message) => message.id == requestId);
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_readableErrorMessage(context, error)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  List<AIChatMessage> _mergedMessages() {
    final deduped = <String, AIChatMessage>{};

    void addAll(Iterable<AIChatMessage> source) {
      for (final message in source) {
        deduped[message.id] = message;
      }
    }

    addAll(_messages);
    addAll(_sessionMessages);
    addAll(_pendingMessages);

    final merged = deduped.values.toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  List<AIChatMessage> _conversationHistory() {
    return _mergedMessages()
        .where((message) => message.text.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _buildPagodaSummary(Pagoda pagoda) {
    final description = _compactText(pagoda.description, maxChars: 210);
    final history = _compactText(pagoda.historicalInfo ?? '', maxChars: 160);
    if (description.isEmpty && history.isEmpty) {
      return '${pagoda.name} (${pagoda.category})';
    }
    return [
      description,
      history,
    ].where((part) => part.isNotEmpty).take(2).join(' ');
  }

  String _compactText(String text, {int maxChars = 150}) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty || compact.length <= maxChars) {
      return compact;
    }
    return '${compact.substring(0, maxChars - 1)}…';
  }

  String _readableErrorMessage(BuildContext context, Object error) {
    if (error is TimeoutException) {
      return 'The AI request timed out. Check your connection and try again.';
    }
    if (error is SocketException) {
      return 'Cannot reach the AI service. Check your network connection.';
    }

    final text = error.toString().trim();
    final cleaned = text
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();

    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    return context.l10n.translate('chat.sendError');
  }

  void _upsertSessionMessage(AIChatMessage message) {
    final index = _sessionMessages.indexWhere((item) => item.id == message.id);
    if (index >= 0) {
      _sessionMessages[index] = message;
      return;
    }
    _sessionMessages.add(message);
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final offset = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(offset);
      } else {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSignedIn = context.select<AuthProvider, bool>(
      (auth) => auth.user != null,
    );
    final isAiConfigured = _chatbotService.isConfigured;
    final messages = _mergedMessages();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('chat.title')),
        actions: [
          if (isSignedIn)
            IconButton(
              onPressed: messages.isEmpty ? null : _clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.translate('chat.clear'),
            ),
        ],
      ),
      body: isSignedIn
          ? ResponsiveContent(
              child: Column(
                children: [
                  Expanded(child: _buildMessagesBody(context, messages)),
                  if (!isAiConfigured) _buildSetupNotice(context),
                  _buildComposer(context, enabled: isAiConfigured),
                ],
              ),
            )
          : SignInRequiredView(
              icon: Icons.support_agent_outlined,
              message: l10n.translate('chat.signInPrompt'),
              onSignIn: () {
                AuthGate.openSignIn(context);
              },
            ),
    );
  }

  Widget _buildSetupNotice(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.key_off_outlined, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.translate('chat.setupRequiredTitle'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.translate('chat.setupRequiredBody'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesBody(
    BuildContext context,
    List<AIChatMessage> messages,
  ) {
    final l10n = context.l10n;
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: Responsive.pagePadding(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.support_agent_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.translate('chat.emptyTitle'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('chat.emptyBody'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: Responsive.pagePadding(context),
      itemCount: messages.length + (_isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.translate('chat.typing'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }
        return _ChatBubble(message: messages[index]);
      },
    );
  }

  Widget _buildComposer(BuildContext context, {required bool enabled}) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: enabled && !_isSending,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => _sendMessage() : null,
                decoration: InputDecoration(
                  hintText: enabled
                      ? l10n.translate('chat.inputHint')
                      : l10n.translate('chat.setupRequiredTitle'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: enabled && !_isSending ? _sendMessage : null,
              icon: Icon(
                Icons.send,
                color: !enabled || _isSending
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final AIChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);
    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final timeLabel = TimeOfDay.fromDateTime(message.createdAt).format(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isUser ? 14 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(color: textColor, height: 1.35),
              ),
              const SizedBox(height: 4),
              Text(
                timeLabel,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
