import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/chat_errors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/chat_group.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_groups_provider.dart';
import '../../providers/chat_member_data_provider.dart';
import '../../providers/chat_membership_provider.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _joiningGroupId;

  Future<void> _openCreateGroup() async {
    final l10n = context.l10n;
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
    );
    if (result == null) return;
    final groupId = result['id'];
    final groupName = result['name'];
    if (groupId == null || groupName == null) return;

    if (!mounted) return;
    Helpers.showSnackBar(context, l10n.translate('chat.createdSuccess'));
    _openGroupChat(groupId, groupName);
  }

  void _openGroupChat(String groupId, String groupName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GroupChatScreen(groupId: groupId, groupName: groupName),
      ),
    );
  }

  Future<void> _handleJoin(ChatGroup group) async {
    setState(() {
      _joiningGroupId = group.id;
    });

    final l10n = context.l10n;
    try {
      await context.read<ChatRepository>().joinGroup(group.id);
      if (!mounted) return;
      Helpers.showSnackBar(context, l10n.translate('chat.joinedSuccess'));
      _openGroupChat(group.id, group.name);
    } catch (error) {
      if (!mounted) return;
      Helpers.showSnackBar(
        context,
        _errorMessage(l10n, error, fallbackKey: 'chat.joinFailed'),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _joiningGroupId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null || auth.isGuest) {
      return _AuthRequiredView(
        onSignIn: () {
          Navigator.of(context).pushNamed('/login');
        },
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) =>
              ChatGroupsProvider(context.read<ChatRepository>())..start(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ChatMembershipProvider(context.read<ChatRepository>())..start(),
        ),
        ChangeNotifierProxyProvider<ChatGroupsProvider, ChatMemberDataProvider>(
          create: (context) =>
              ChatMemberDataProvider(context.read<ChatRepository>()),
          update: (context, groupsProvider, memberDataProvider) {
            final provider =
                memberDataProvider ??
                ChatMemberDataProvider(context.read<ChatRepository>());
            provider.watchGroups(
              groupsProvider.groups.map((e) => e.id).toList(),
            );
            return provider;
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.translate('chat.title')),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_comment),
              onPressed: _openCreateGroup,
              tooltip: l10n.translate('chat.createGroup'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openCreateGroup,
          backgroundColor: const Color(0xFFB8860B),
          child: const Icon(Icons.add),
        ),
        body:
            Consumer3<
              ChatGroupsProvider,
              ChatMembershipProvider,
              ChatMemberDataProvider
            >(
              builder:
                  (
                    context,
                    groupsProvider,
                    membershipProvider,
                    memberDataProvider,
                    _,
                  ) {
                    if (groupsProvider.isLoading &&
                        groupsProvider.groups.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (groupsProvider.error != null &&
                        groupsProvider.groups.isEmpty) {
                      return Center(
                        child: Text(
                          _errorMessage(
                            l10n,
                            groupsProvider.error!,
                            fallbackKey: 'chat.loadFailed',
                          ),
                        ),
                      );
                    }

                    final groups = groupsProvider.groups;
                    if (groups.isEmpty) {
                      return _EmptyState(onCreate: _openCreateGroup);
                    }

                    final memberGroupIds = membershipProvider.memberGroupIds;
                    return NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent - 200) {
                          groupsProvider.loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            groups.length +
                            (groupsProvider.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= groups.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final group = groups[index];
                          final isMember = memberGroupIds.contains(group.id);
                          final isJoining = _joiningGroupId == group.id;
                          final memberCount =
                              memberDataProvider.countForGroup(group.id) ??
                              group.memberCount;

                          return _GroupTile(
                            group: group,
                            memberCount: memberCount,
                            isMember: isMember,
                            isJoining: isJoining,
                            onJoin: () => _handleJoin(group),
                            onOpen: () => _openGroupChat(group.id, group.name),
                          );
                        },
                      ),
                    );
                  },
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

class _AuthRequiredView extends StatelessWidget {
  final VoidCallback onSignIn;

  const _AuthRequiredView({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.translate('chat.authRequired'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login),
              label: Text(l10n.translate('chat.signInButton')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              l10n.translate('chat.emptyTitle'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('chat.emptyBody'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.translate('chat.createGroup')),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final ChatGroup group;
  final int memberCount;
  final bool isMember;
  final bool isJoining;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  const _GroupTile({
    required this.group,
    required this.memberCount,
    required this.isMember,
    required this.isJoining,
    required this.onJoin,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFB8860B).withValues(alpha: 0.15),
          child: const Icon(Icons.groups, color: Color(0xFFB8860B)),
        ),
        title: Text(group.name),
        subtitle: Text(
          (group.lastMessage?.isNotEmpty ?? false)
              ? group.lastMessage!
              : l10n.translate('chat.noMessages'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isJoining
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isMember
            ? _MemberCountChip(count: memberCount)
            : OutlinedButton(
                onPressed: onJoin,
                child: Text(l10n.translate('chat.join')),
              ),
        onTap: onOpen, // Allow all users to open groups
      ),
    );
  }
}

class _MemberCountChip extends StatelessWidget {
  final int count;

  const _MemberCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFB8860B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        l10n.translate('chat.memberCount', args: {'count': count.toString()}),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B4F1D),
        ),
      ),
    );
  }
}
