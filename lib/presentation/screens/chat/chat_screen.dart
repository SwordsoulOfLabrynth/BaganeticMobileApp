import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/pagoda_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/ai_chatbot_service.dart';
import '../../../core/utils/responsive.dart';
import '../../providers/pagoda_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const String _historyPrefsKey = 'chat_history_v1';

  final AIChatbotService _chatbotService = AIChatbotService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<AIChatMessage> _messages = [];
  bool _isSending = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _messages
          ..clear()
          ..addAll(
            decoded.whereType<Map<String, dynamic>>().map(
              AIChatMessage.fromJson,
            ),
          );
      }
    } catch (_) {
      _messages.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        _scrollToBottom(jump: true);
      }
    }
  }

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString(_historyPrefsKey, encoded);
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

    setState(() {
      _messages.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyPrefsKey);
  }

  Future<void> _sendMessage() async {
    final prompt = _messageController.text.trim();
    if (prompt.isEmpty || _isSending) {
      return;
    }

    final userMessage = AIChatMessage(
      role: AIChatMessage.roleUser,
      text: prompt,
      createdAt: DateTime.now(),
    );

    _messageController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(userMessage);
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
    final languageCode = Localizations.localeOf(context).languageCode;
    _scrollToBottom();
    await _persistHistory();
    if (!mounted) return;

    try {
      final reply = await _chatbotService.generateReply(
        prompt: prompt,
        history: List<AIChatMessage>.from(_messages),
        languageCode: languageCode,
        pagodaContext: pagodas,
      );
      if (!mounted) return;

      setState(() {
        _messages.add(
          AIChatMessage(
            role: AIChatMessage.roleAssistant,
            text: reply,
            createdAt: DateTime.now(),
          ),
        );
        _isSending = false;
      });
      _scrollToBottom();
      await _persistHistory();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.translate('chat.sendError'))),
      );
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('chat.title')),
        actions: [
          IconButton(
            onPressed: _messages.isEmpty ? null : _clearHistory,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: l10n.translate('chat.clear'),
          ),
        ],
      ),
      body: ResponsiveContent(
        child: Column(
          children: [
            Expanded(child: _buildMessagesBody(context)),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesBody(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: Responsive.pagePadding(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
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
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
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
        return _ChatBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildComposer(BuildContext context) {
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
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: l10n.translate('chat.inputHint'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: Icon(
                Icons.send,
                color: _isSending
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
