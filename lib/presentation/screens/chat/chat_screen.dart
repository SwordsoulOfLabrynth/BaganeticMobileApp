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
import '../../providers/community_provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';

class ChatScreen extends StatefulWidget {
  final AIEntryContext entryContext;
  final bool embedded;
  final VoidCallback? onClose;

  const ChatScreen({
    super.key,
    this.entryContext = const AIEntryContext.global(),
    this.embedded = false,
    this.onClose,
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocalFallbackMessages());
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    _messageSub?.cancel();
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
        unawaited(_loadLocalFallbackMessages());
      },
    );
  }

  Future<void> _requestAiSignIn() async {
    final didSignIn = await AuthGate.ensureSignedIn(
      context,
      featureName: context.l10n.translate('chat.journeyGuide'),
    );
    if (!didSignIn || !mounted) {
      return;
    }
    _subscribeToMessages();
    await _loadLocalFallbackMessages();
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
    await _loadLocalFallbackMessages();
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
    if (!AuthGate.isSignedIn(context)) {
      unawaited(_requestAiSignIn());
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
            // Bundled opening hours are not sourced or date-maintained.
            openingHours: '',
            location: _compactText(p.visitorLocation ?? '', maxChars: 90),
          ),
        )
        .toList(growable: false);
    final tripProvider = context.read<TripProvider>();
    final communityPosts = context
        .read<CommunityProvider>()
        .allPosts
        .take(60)
        .map(
          (post) => AICommunityPostContext(
            id: post.id,
            authorName: post.authorName,
            type: post.type,
            title: _compactText(post.title, maxChars: 120),
            body: _compactText(post.body, maxChars: 220),
            tags: post.tags,
            createdAt: post.createdAt,
            upvoteCount: post.upvoteCount,
            commentCount: post.commentCount,
          ),
        )
        .toList(growable: false);
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
        communityContext: communityPosts,
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
      return pagoda.name;
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

    final normalized = cleaned.toLowerCase();
    if (normalized.contains('unauthenticated')) {
      return 'Please sign in before using the AI assistant.';
    }
    if (normalized.contains('not-found')) {
      return 'The AI service has not been deployed yet. Please try again later.';
    }
    if (normalized.contains('internal') || normalized.contains('unavailable')) {
      return 'The AI service is temporarily unavailable. Please try again later.';
    }

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

  Future<void> _loadLocalFallbackMessages() async {
    final localMessages = await _chatbotService.localFallbackMessages();
    if (!mounted) {
      return;
    }
    setState(() {
      _messages = localMessages;
    });
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
    final isSignedIn = context.select<AuthProvider, bool>(
      (auth) => auth.user != null,
    );
    final isAiConfigured = _chatbotService.isConfigured;
    final messages = _mergedMessages();
    final guide = ColoredBox(
      color: const Color(0xFFF5F2EB),
      child: Column(
        children: [
          _buildGuideHeader(context, messages),
          Expanded(child: _buildMessagesBody(context, messages)),
          _buildComposer(
            context,
            isSignedIn: isSignedIn,
            isAiConfigured: isAiConfigured,
          ),
        ],
      ),
    );
    return widget.embedded ? guide : Scaffold(body: guide);
  }

  Widget _buildGuideHeader(BuildContext context, List<AIChatMessage> messages) {
    final close = widget.onClose ?? () => Navigator.of(context).maybePop();
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F2EB),
          border: Border(bottom: BorderSide(color: Color(0xFFE5E0D8))),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: close,
              icon: const Icon(Icons.arrow_back, color: Color(0xFF4A3B32)),
            ),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFC8A97E)),
                        ),
                        child: const Icon(
                          Icons.smart_toy_outlined,
                          size: 18,
                          color: Color(0xFFC8A97E),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.translate('chat.journeyGuide'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF1A1C20),
                              fontSize: 28,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.translate('chat.journeyGuideSubtitle'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF4A3B32),
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 48,
              child: IconButton(
                onPressed: messages.isEmpty ? null : _clearHistory,
                icon: const Icon(Icons.delete_sweep_outlined),
                color: const Color(0xFF4A3B32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesBody(
    BuildContext context,
    List<AIChatMessage> messages,
  ) {
    final l10n = context.l10n;
    if (messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(30, 32, 30, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(28),
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              border: Border.all(color: const Color(0x4DC8A97E)),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: l10n.translate('chat.greeting'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFFC8A97E),
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: l10n.translate('chat.stitchEmptyPrompt'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1A1C20),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            l10n.translate('chat.localGuide'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF8A8078),
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _GuideSuggestion(
                label: l10n.translate('chat.suggestionSunrise'),
                onTap: () =>
                    _useSuggestion('Which temples are best for sunrise?'),
              ),
              _GuideSuggestion(
                label: l10n.translate('chat.suggestionRoads'),
                onTap: () =>
                    _useSuggestion('What are the current road conditions?'),
              ),
              _GuideSuggestion(
                label: l10n.translate('chat.suggestionPlan'),
                onTap: () => _useSuggestion('Help me plan a day in Bagan.'),
              ),
            ],
          ),
        ],
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

  Widget _buildComposer(
    BuildContext context, {
    required bool isSignedIn,
    required bool isAiConfigured,
  }) {
    final l10n = context.l10n;
    if (!isSignedIn) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
          color: const Color(0xFFF5F2EB),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.translate('chat.signInPrompt'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6E6259),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => unawaited(_requestAiSignIn()),
                icon: const Icon(Icons.lock_outline),
                label: Text(l10n.translate('auth.signIn')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: const Color(0xFF8B432B),
                  side: const BorderSide(color: Color(0xFFC8A97E)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final enabled = isAiConfigured;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
        color: const Color(0xFFF5F2EB),
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
                  filled: true,
                  fillColor: const Color(0xFFFAF9F6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0x66C8A97E)),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0x33C8A97E)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: const Color(0xFFB85D43),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: enabled && !_isSending ? _sendMessage : null,
                icon: Icon(
                  Icons.send_rounded,
                  color: !enabled || _isSending
                      ? const Color(0x88FFFFFF)
                      : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _useSuggestion(String text) async {
    if (!AuthGate.isSignedIn(context)) {
      await _requestAiSignIn();
      return;
    }
    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(offset: text.length);
  }
}

class _GuideSuggestion extends StatelessWidget {
  const _GuideSuggestion({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF4A3B32),
      side: const BorderSide(color: Color(0x66C8A97E)),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
    child: Text(label),
  );
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
