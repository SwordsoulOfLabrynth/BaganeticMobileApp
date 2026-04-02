import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/trip_provider.dart';
import '../map/map_screen.dart';
import '../pagoda_detail/pagoda_detail_screen.dart';
import '../pagodas/pagodas_list_screen.dart';
import '../trips/trip_detail_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageProvider = context.watch<LanguageProvider>();
    final languageCode = languageProvider.locale.languageCode;
    final languageLabel = languageCode == 'my'
        ? l10n.translate('profile.languageMyanmar')
        : l10n.translate('profile.languageEnglish');
    final pagePadding = Responsive.pagePadding(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('profile.title')),
        elevation: 0,
      ),
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: pagePadding.copyWith(
            bottom: pagePadding.bottom + 136 + bottomInset,
          ),
          child: Column(
            children: [
              _buildProfileHeader(context),
              const SizedBox(height: 24),
              _buildFavorites(context),
              const SizedBox(height: 16),
              _buildTrips(context),
              const SizedBox(height: 24),
              _buildSettingsTile(
                icon: Icons.language,
                title: l10n.translate('profile.language'),
                subtitle: languageLabel,
                onTap: () => _showLanguagePicker(context),
              ),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.user == null) {
                    return const SizedBox.shrink();
                  }

                  final user = auth.user!;
                  final displayName = (user.displayName ?? '').trim();
                  final subtitle = displayName.isNotEmpty
                      ? displayName
                      : ((user.email ?? '').split('@').first);

                  return _buildSettingsTile(
                    icon: Icons.person_outline,
                    title: l10n.translate('profile.editName'),
                    subtitle: subtitle,
                    onTap: () => _showEditDisplayNameDialog(context),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.info,
                title: l10n.translate('profile.about'),
                onTap: () => _showAboutDialog(context),
              ),
              const SizedBox(height: 16),
              _buildSessionAction(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final l10n = context.l10n;

    return Consumer3<AuthProvider, PagodaProvider, TripProvider>(
      builder: (context, auth, pagodaProvider, tripProvider, _) {
        final user = auth.user;
        final isGuest = auth.isGuest || user == null;
        final displayName = (user?.displayName ?? '').trim();
        final title = isGuest
            ? l10n.translate('profile.guestTitle')
            : (displayName.isNotEmpty
                  ? displayName
                  : (user.email ?? l10n.translate('profile.userDefault')));
        final subtitle = isGuest
            ? l10n.translate('profile.guestSubtitle')
            : (user.email ?? '');
        final avatarLabel = title.isEmpty ? 'G' : title.substring(0, 1);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: _gold,
                  child: Text(
                    avatarLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildStatPill(
                      icon: Icons.favorite_border,
                      label:
                          '${pagodaProvider.favorites.length} ${l10n.translate('profile.favorites')}',
                    ),
                    _buildStatPill(
                      icon: Icons.route_outlined,
                      label:
                          '${tripProvider.trips.length} ${l10n.translate('trips.title')}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavorites(BuildContext context) {
    final l10n = context.l10n;

    return Consumer2<AuthProvider, PagodaProvider>(
      builder: (context, auth, provider, _) {
        final isLoggedIn = auth.user != null;
        final favorites = provider.favorites;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.translate('profile.favorites'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${favorites.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isLoggedIn)
                  _buildEmptyCardAction(
                    context,
                    message: l10n.translate('auth.loginRequired'),
                    label: l10n.translate('auth.signIn'),
                    icon: Icons.login,
                    onTap: () => AuthGate.openSignIn(context),
                  )
                else if (favorites.isEmpty)
                  _buildEmptyCardAction(
                    context,
                    message: l10n.translate('profile.noFavorites'),
                    label: l10n.translate('home.actionExplore'),
                    icon: Icons.explore_outlined,
                    onTap: () => _openPagodas(context),
                  )
                else
                  Column(
                    children: [
                      ...favorites
                          .take(3)
                          .map(
                            (pagoda) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFF3CD),
                                child: Icon(
                                  Icons.temple_buddhist,
                                  color: _gold,
                                ),
                              ),
                              title: Text(
                                context.l10n.pagodaName(pagoda.id, pagoda.name),
                              ),
                              subtitle: Text(
                                context.l10n.categoryLabel(pagoda.category),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              dense: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PagodaDetailScreen(pagoda: pagoda),
                                  ),
                                );
                              },
                            ),
                          ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _openPagodas(context),
                          icon: const Icon(Icons.explore_outlined),
                          label: Text(l10n.translate('home.actionExplore')),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrips(BuildContext context) {
    final l10n = context.l10n;

    return Consumer2<AuthProvider, TripProvider>(
      builder: (context, auth, provider, _) {
        final isLoggedIn = auth.user != null;
        final trips = provider.trips;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.translate('trips.title'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${trips.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isLoggedIn)
                  _buildEmptyCardAction(
                    context,
                    message: l10n.translate('trips.signInPrompt'),
                    label: l10n.translate('auth.signIn'),
                    icon: Icons.login,
                    onTap: () => AuthGate.openSignIn(context),
                  )
                else if (trips.isEmpty)
                  _buildEmptyCardAction(
                    context,
                    message: l10n.translate('trips.emptySubtitle'),
                    label: l10n.translate('map.planTrip'),
                    icon: Icons.route_outlined,
                    onTap: () => _openTrips(context),
                  )
                else
                  Column(
                    children: [
                      ...trips
                          .take(2)
                          .map(
                            (trip) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFFF3CD),
                                child: Text(
                                  '${trip.stops.length}',
                                  style: const TextStyle(
                                    color: Color(0xFF8A6D00),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(trip.name),
                              subtitle: Text(
                                '${Helpers.formatDate(trip.date)} • ${context.l10n.translate('common.stopsCount', args: {'count': trip.stops.length.toString()})}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              dense: true,
                              onTap: () => _openTripDetail(context, trip),
                            ),
                          ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _openTrips(context),
                          icon: const Icon(Icons.route_outlined),
                          label: Text(l10n.translate('map.planTrip')),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyCardAction(
    BuildContext context, {
    required String message,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label)),
      ],
    );
  }

  Widget _buildStatPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A6D00),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: _gold),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSessionAction(BuildContext context) {
    final l10n = context.l10n;

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final isGuest = auth.isGuest || auth.user == null;
        if (isGuest) {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                AuthGate.openSignIn(context);
              },
              icon: const Icon(Icons.login),
              label: Text(l10n.translate('auth.signIn')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final shouldSignOut = await _confirmSignOut(context);
              if (shouldSignOut != true || !context.mounted) {
                return;
              }
              await Future<void>.delayed(const Duration(milliseconds: 150));
              if (!context.mounted) {
                return;
              }
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Helpers.showSnackBar(
                  context,
                  l10n.translate('profile.signedOut'),
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(l10n.translate('profile.signOut')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        );
      },
    );
  }

  void _openPagodas(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PagodasListScreen()),
    );
  }

  void _openTrips(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapScreen(initialMode: MapTripMode.trips),
      ),
    );
  }

  void _openTripDetail(BuildContext context, Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TripDetailScreen(trip: trip)),
    );
  }

  Future<void> _showEditDisplayNameDialog(BuildContext context) async {
    final l10n = context.l10n;
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return;
    }

    final initialName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : (user.email ?? '').split('@').first;

    final updatedName = await showDialog<String>(
      context: context,
      builder: (_) => _EditDisplayNameDialog(initialName: initialName),
    );

    if (updatedName == null || !context.mounted) {
      return;
    }

    Helpers.showSnackBar(
      context,
      l10n.translate('profile.nameUpdated'),
    );
  }

  Future<bool?> _confirmSignOut(BuildContext context) {
    final l10n = context.l10n;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.translate('profile.signOut')),
        content: Text(l10n.translate('profile.signOutConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.translate('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.translate('profile.signOut')),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final l10n = context.l10n;
    final languageProvider = context.read<LanguageProvider>();
    final currentCode = languageProvider.locale.languageCode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              l10n.translate('profile.chooseLanguage'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.translate('profile.languageEnglish')),
              trailing: currentCode == 'en'
                  ? const Icon(Icons.check_circle, color: _gold)
                  : null,
              onTap: () async {
                await languageProvider.setLocale(const Locale('en'));
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(l10n.translate('profile.languageMyanmar')),
              trailing: currentCode == 'my'
                  ? const Icon(Icons.check_circle, color: _gold)
                  : null,
              onTap: () async {
                await languageProvider.setLocale(const Locale('my'));
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.temple_buddhist,
              size: 28,
              color: _gold,
            ),
            const SizedBox(width: 12),
            const Text('Baganetic'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.translate('profile.aboutSummary')),
              const SizedBox(height: 12),
              Text(l10n.translate('profile.aboutBody')),
              const SizedBox(height: 12),
              Text(l10n.translate('profile.aboutFooter')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.translate('common.done')),
          ),
        ],
      ),
    );
  }
}

class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || _formKey.currentState?.validate() != true) {
      return;
    }

    final nextName = _controller.text.trim();
    if (nextName == widget.initialName) {
      Navigator.of(context).pop();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final success = await context.read<AuthProvider>().updateDisplayName(
      nextName,
    );
    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _isSaving = false;
        _errorText = context.l10n.translate('profile.nameUpdateFailed');
      });
      return;
    }

    Navigator.of(context).pop(nextName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.translate('profile.editName')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: l10n.translate('profile.displayNameLabel'),
                hintText: l10n.translate('profile.displayNameHint'),
                errorText: _errorText,
              ),
              enabled: !_isSaving,
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.translate('profile.displayNameRequired');
                }
                return null;
              },
              onFieldSubmitted: (_) {
                _save();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.translate('common.cancel')),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.translate('common.save')),
        ),
      ],
    );
  }
}
