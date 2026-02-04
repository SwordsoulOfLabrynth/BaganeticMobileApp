import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pagoda_provider.dart';
import '../../providers/language_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/responsive.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageProvider = context.watch<LanguageProvider>();
    final languageCode = languageProvider.locale.languageCode;
    final languageLabel = languageCode == 'my'
        ? l10n.translate('profile.languageMyanmar')
        : l10n.translate('profile.languageEnglish');
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('profile.title')),
        elevation: 0,
      ),
      body: ResponsiveContent(
        child: SingleChildScrollView(
          padding: Responsive.pagePadding(context),
          child: Column(
            children: [
              _buildProfileHeader(context),
              const SizedBox(height: 32),
              _buildFavorites(context),
              const SizedBox(height: 32),
              _buildSettingsTile(
                icon: Icons.language,
                title: l10n.translate('profile.language'),
                subtitle: languageLabel,
                onTap: () => _showLanguagePicker(context),
              ),
              _buildSettingsTile(
                icon: Icons.notifications,
                title: l10n.translate('profile.notifications'),
                subtitle: l10n.translate('profile.enabled'),
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.help,
                title: l10n.translate('profile.helpSupport'),
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.info,
                title: l10n.translate('profile.about'),
                onTap: () {},
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await context.read<AuthProvider>().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.translate('profile.signOut')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
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
                  radius: 50,
                  backgroundColor: const Color(0xFFD4AF37),
                  child: Text(
                    user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? l10n.translate('profile.userDefault'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: Colors.grey[600]),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${favorites.length}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isLoggedIn)
                  Text(l10n.translate('auth.loginRequired'))
                else if (favorites.isEmpty)
                  Text(l10n.translate('profile.noFavorites'))
                else
                  ...favorites
                      .take(3)
                      .map(
                        (pagoda) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.temple_buddhist),
                          title: Text(pagoda.name),
                          dense: true,
                        ),
                      ),
              ],
            ),
          ),
        );
      },
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
        leading: Icon(icon, color: const Color(0xFFD4AF37)),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
                  ? const Icon(Icons.check_circle, color: Color(0xFFD4AF37))
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
                  ? const Icon(Icons.check_circle, color: Color(0xFFD4AF37))
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
}
