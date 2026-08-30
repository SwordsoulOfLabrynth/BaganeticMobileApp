import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';
import '../community/community_feed_screen.dart';
import '../legal/legal_document_screen.dart';
import '../map/map_screen.dart';
import '../pagodas/pagodas_list_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  static const _paper = Color(0xFFF7F2E9);
  static const _gold = Color(0xFFC19A49);

  @override
  Widget build(BuildContext context) {
    return Consumer5<
      AuthProvider,
      PagodaProvider,
      TripProvider,
      LanguageProvider,
      CommunityProvider
    >(
      builder: (context, auth, pagodas, trips, language, community, _) {
        final user = auth.user;
        final guest = auth.isGuest || user == null;
        final displayName = guest
            ? context.l10n.translate('profile.guestTitle')
            : ((user.displayName ?? '').trim().isNotEmpty
                  ? user.displayName!.trim()
                  : (user.email ?? 'Traveler').split('@').first);
        final myPostCount = guest
            ? 0
            : community.allPosts
                  .where((post) => post.authorUserId == user.uid)
                  .length;
        final languageText = language.locale.languageCode == 'my'
            ? context.l10n.translate('profile.languageMyanmar')
            : context.l10n.translate('profile.languageEnglish');

        return Scaffold(
          backgroundColor: _paper,
          appBar: AppBar(
            backgroundColor: _paper,
            leading: IconButton(
              onPressed: () {
                if (onBack != null) {
                  onBack!();
                } else {
                  Navigator.maybePop(context);
                }
              },
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(context.l10n.translate('profile.journalTitle')),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: () => _showAboutDialog(context),
                icon: const Icon(Icons.info_outline_rounded),
                tooltip: context.l10n.translate('profile.aboutBaganetic'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 42),
            children: [
              _ProfileHero(
                name: displayName,
                isGuest: guest,
                photoUrl: guest ? null : user.photoURL,
                localPhotoPath: guest ? null : auth.localProfilePhotoPath,
                isUploadingPhoto: auth.isLoading,
                onSignIn: () => AuthGate.openSignIn(context),
                onChangePhoto: () => _pickProfilePhoto(context),
              ),
              const SizedBox(height: 18),
              _StatPanel(
                saved: pagodas.favorites.length,
                journeys: trips.trips.length,
                posts: myPostCount,
              ),
              const SizedBox(height: 30),
              _SectionLabel(context.l10n.translate('profile.sectionMyBagan')),
              const SizedBox(height: 10),
              _ProfileMenuGroup(
                items: [
                  _ProfileMenuItem(
                    icon: Icons.bookmark_border_rounded,
                    title: context.l10n.translate('profile.savedPagodas'),
                    subtitle: context.l10n.translate(
                      'profile.savedPagodasSubtitle',
                    ),
                    badge: '${pagodas.favorites.length}',
                    onTap: () => _openSavedPagodas(context),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.route_outlined,
                    title: context.l10n.translate('profile.myJourneys'),
                    subtitle: context.l10n.translate(
                      'profile.myJourneysSubtitle',
                    ),
                    badge: '${trips.trips.length}',
                    onTap: () => _openTrips(context),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _SectionLabel(context.l10n.translate('profile.sectionCommunity')),
              const SizedBox(height: 10),
              _ProfileMenuGroup(
                items: [
                  _ProfileMenuItem(
                    icon: Icons.forum_outlined,
                    title: context.l10n.translate('profile.myPosts'),
                    subtitle: context.l10n.translate('profile.myPostsSubtitle'),
                    badge: '$myPostCount',
                    onTap: () => _openMyPosts(context, user?.uid),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.groups_2_outlined,
                    title: context.l10n.translate('profile.exploreCommunity'),
                    subtitle: context.l10n.translate(
                      'profile.exploreCommunitySubtitle',
                    ),
                    onTap: () => _openCommunity(context),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _SectionLabel(
                context.l10n.translate('profile.sectionPreferences'),
              ),
              const SizedBox(height: 10),
              _ProfileMenuGroup(
                items: [
                  _ProfileMenuItem(
                    icon: Icons.language_rounded,
                    title: context.l10n.translate('profile.language'),
                    subtitle: languageText,
                    onTap: () => _showLanguagePicker(context),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.info_outline_rounded,
                    title: context.l10n.translate('profile.aboutBaganetic'),
                    subtitle: context.l10n.translate(
                      'profile.aboutBaganeticSubtitle',
                    ),
                    onTap: () => _showAboutDialog(context),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.privacy_tip_outlined,
                    title: context.l10n.translate('legal.privacyTitle'),
                    subtitle: context.l10n.translate('legal.privacySubtitle'),
                    onTap: () => _openLegalDocument(
                      context,
                      titleKey: 'legal.privacyTitle',
                      bodyKey: 'legal.privacyBody',
                    ),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.gavel_outlined,
                    title: context.l10n.translate('legal.termsTitle'),
                    subtitle: context.l10n.translate('legal.termsSubtitle'),
                    onTap: () => _openLegalDocument(
                      context,
                      titleKey: 'legal.termsTitle',
                      bodyKey: 'legal.termsBody',
                    ),
                  ),
                ],
              ),
              if (!guest) ...[
                const SizedBox(height: 26),
                _SectionLabel(context.l10n.translate('profile.sectionAccount')),
                const SizedBox(height: 10),
                _ProfileMenuGroup(
                  items: [
                    _ProfileMenuItem(
                      icon: Icons.delete_forever_outlined,
                      title: context.l10n.translate('profile.deleteAccount'),
                      subtitle: context.l10n.translate(
                        'profile.deleteAccountSubtitle',
                      ),
                      onTap: () => _confirmDeleteAccount(context),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 30),
              _SessionButton(
                guest: guest,
                onTap: () => _sessionAction(context, guest),
              ),
              const SizedBox(height: 22),
              Text(
                context.l10n.translate('profile.journalFooter'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: Color(0xFFA99E95),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sessionAction(BuildContext context, bool guest) async {
    if (guest) {
      AuthGate.openSignIn(context);
      return;
    }
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.translate('profile.signOut')),
        content: Text(l10n.translate('profile.signOutConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.translate('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.translate('profile.signOut')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
      if (context.mounted) {
        Helpers.showSnackBar(context, l10n.translate('profile.signedOut'));
      }
    }
  }

  void _openLegalDocument(
    BuildContext context, {
    required String titleKey,
    required String bodyKey,
  }) {
    final l10n = context.l10n;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(
          title: l10n.translate(titleKey),
          body: l10n.translate(bodyKey),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final l10n = context.l10n;
    final passwordController = TextEditingController();
    var obscurePassword = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(l10n.translate('profile.deleteAccount')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.translate('profile.deleteAccountConfirmBody')),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: l10n.translate('auth.password'),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword,
                        ),
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.translate('common.cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.translate('profile.deleteAccount')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      passwordController.dispose();
      return;
    }

    final password = passwordController.text;
    passwordController.dispose();
    if (password.isEmpty) {
      Helpers.showSnackBar(
        context,
        l10n.translate('auth.passwordRequired'),
        isError: true,
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.deleteAccount(password: password);
    if (!context.mounted) {
      return;
    }
    if (success) {
      Helpers.showSnackBar(context, l10n.translate('profile.accountDeleted'));
      return;
    }
    Helpers.showSnackBar(
      context,
      l10n.translate(auth.errorKey ?? 'profile.deleteAccountFailed'),
      isError: true,
    );
  }

  Future<void> _pickProfilePhoto(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null || !context.mounted) {
        return;
      }

      final success = await context.read<AuthProvider>().updateProfilePhoto(
        await image.readAsBytes(),
        contentType: image.mimeType,
      );
      if (!context.mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        success
            ? l10n.translate('profile.photoUpdated')
            : l10n.translate('profile.photoUploadFailed'),
        isError: !success,
      );
    } catch (_) {
      if (context.mounted) {
        Helpers.showSnackBar(
          context,
          l10n.translate('profile.photoUploadFailed'),
          isError: true,
        );
      }
    }
  }

  void _openSavedPagodas(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const PagodasListScreen(favoritesOnly: true, showBackButton: true),
    ),
  );

  void _openTrips(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const MapScreen(initialMode: MapTripMode.trips),
    ),
  );

  void _openMyPosts(BuildContext context, String? userId) {
    if (userId == null || userId.isEmpty) {
      AuthGate.openSignIn(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityFeedScreen(
          authorUserId: userId,
          title: context.l10n.translate('profile.myPosts'),
        ),
      ),
    );
  }

  void _openCommunity(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CommunityFeedScreen()),
  );

  void _showLanguagePicker(BuildContext context) {
    final language = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.translate('profile.chooseLanguage'),
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              ListTile(
                title: Text(context.l10n.translate('profile.languageEnglish')),
                trailing: language.locale.languageCode == 'en'
                    ? const Icon(Icons.check, color: _gold)
                    : null,
                onTap: () async {
                  await language.setLocale(const Locale('en'));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                title: Text(context.l10n.translate('profile.languageMyanmar')),
                trailing: language.locale.languageCode == 'my'
                    ? const Icon(Icons.check, color: _gold)
                    : null,
                onTap: () async {
                  await language.setLocale(const Locale('my'));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.translate('profile.aboutBaganetic')),
      content: Text(context.l10n.translate('profile.aboutSummary')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.l10n.translate('common.done')),
        ),
      ],
    ),
  );
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.isGuest,
    required this.photoUrl,
    required this.localPhotoPath,
    required this.isUploadingPhoto,
    required this.onSignIn,
    required this.onChangePhoto,
  });

  final String name;
  final bool isGuest;
  final String? photoUrl;
  final String? localPhotoPath;
  final bool isUploadingPhoto;
  final VoidCallback onSignIn;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF2B1D14),
      borderRadius: BorderRadius.circular(16),
      image: const DecorationImage(
        image: AssetImage('assets/images/stitch/bagan_sunrise.jpg'),
        fit: BoxFit.cover,
        opacity: 0.14,
      ),
    ),
    child: Row(
      children: [
        _Avatar(
          name: name,
          photoUrl: photoUrl,
          localPhotoPath: localPhotoPath,
          isUploading: isUploadingPhoto,
          onTap: isGuest ? onSignIn : onChangePhoto,
          showEditControl: !isGuest,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.l10n.translate(
                  isGuest
                      ? 'profile.journalGuestPrompt'
                      : 'profile.journalSubtitle',
                ),
                style: const TextStyle(
                  color: Color(0xFFE8D7B5),
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (isGuest) ...[
                const SizedBox(height: 13),
                TextButton(
                  onPressed: onSignIn,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF2CE70),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    side: const BorderSide(color: Color(0xFFF2CE70)),
                  ),
                  child: Text(
                    context.l10n.translate('profile.signInToSave'),
                    style: const TextStyle(fontSize: 10, letterSpacing: 1.1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.photoUrl,
    required this.localPhotoPath,
    required this.isUploading,
    required this.onTap,
    required this.showEditControl,
  });

  final String name;
  final String? photoUrl;
  final String? localPhotoPath;
  final bool isUploading;
  final VoidCallback onTap;
  final bool showEditControl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    final localPath = localPhotoPath?.trim() ?? '';
    return Semantics(
      button: true,
      label: context.l10n.translate('profile.changePhoto'),
      child: InkWell(
        onTap: isUploading ? null : onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF0D9A9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF6E7C7), width: 2),
              ),
              child: ClipOval(
                child: localPath.isNotEmpty
                    ? Image.file(
                        File(localPath),
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _AvatarInitial(name: name),
                      )
                    : url.isNotEmpty
                    ? Image.network(
                        url,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _AvatarInitial(name: name),
                      )
                    : _AvatarInitial(name: name),
              ),
            ),
            if (showEditControl)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC19A49),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2B1D14),
                      width: 2,
                    ),
                  ),
                  child: isUploading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2B1D14),
                          ),
                        )
                      : const Icon(
                          Icons.edit_rounded,
                          size: 13,
                          color: Color(0xFF2B1D14),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      name.isEmpty ? 'B' : name[0].toUpperCase(),
      style: const TextStyle(
        fontFamily: 'PlayfairDisplay',
        fontSize: 34,
        color: Color(0xFF2B1D14),
      ),
    ),
  );
}

class _StatPanel extends StatelessWidget {
  const _StatPanel({
    required this.saved,
    required this.journeys,
    required this.posts,
  });

  final int saved;
  final int journeys;
  final int posts;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 15),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE4D5BB)),
      borderRadius: BorderRadius.circular(14),
      color: Colors.white.withValues(alpha: 0.45),
    ),
    child: Row(
      children: [
        _Stat(
          value: '$saved',
          label: context.l10n.translate('profile.statSaved'),
        ),
        const _StatDivider(),
        _Stat(
          value: '$journeys',
          label: context.l10n.translate('profile.statJourneys'),
        ),
        const _StatDivider(),
        _Stat(
          value: '$posts',
          label: context.l10n.translate('profile.statPosts'),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF2B1D14),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF887B71),
            fontSize: 9,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 36,
    child: VerticalDivider(color: Color(0xFFE4D5BB)),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF7A6E66),
      fontSize: 10,
      letterSpacing: 1.8,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _ProfileMenuItem {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
}

class _ProfileMenuGroup extends StatelessWidget {
  const _ProfileMenuGroup({required this.items});
  final List<_ProfileMenuItem> items;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.34),
      border: Border.all(color: const Color(0xFFE4D5BB)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        return Column(
          children: [
            ListTile(
              onTap: item.onTap,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 5,
              ),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E7D8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  color: const Color(0xFF7A5531),
                  size: 21,
                ),
              ),
              title: Text(
                item.title,
                style: const TextStyle(
                  color: Color(0xFF2B1D14),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF82766E), fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEDBAF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          color: Color(0xFF5E411D),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Color(0xFFB7A99C)),
                ],
              ),
            ),
            if (entry.key != items.length - 1)
              const Divider(height: 1, color: Color(0xFFE4D5BB)),
          ],
        );
      }).toList(),
    ),
  );
}

class _SessionButton extends StatelessWidget {
  const _SessionButton({required this.guest, required this.onTap});
  final bool guest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(guest ? Icons.login_rounded : Icons.logout_rounded),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        foregroundColor: guest
            ? const Color(0xFF8A5B16)
            : const Color(0xFF9B4425),
        side: const BorderSide(color: Color(0xFFD5C5BC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      label: Text(
        guest
            ? context.l10n.translate('profile.signInJournal')
            : context.l10n.translate('profile.signOut'),
        style: const TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.w800),
      ),
    ),
  );
}
