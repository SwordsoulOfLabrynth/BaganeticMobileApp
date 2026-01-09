import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pagoda_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 32),
            _buildFavorites(context),
            const SizedBox(height: 32),
            _buildSettingsTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: 'English',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Enabled',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.refresh,
              title: 'Reload Sample Data',
              subtitle: 'Debug: Clear and reload pagoda data',
              onTap: () async {
                final pagodaProvider = context.read<PagodaProvider>();
                await pagodaProvider.reloadSampleData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sample data reloaded!')),
                  );
                }
              },
            ),
            _buildSettingsTile(
              icon: Icons.help,
              title: 'Help & Support',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.info,
              title: 'About',
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
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileHeader(BuildContext context) {
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
                  user?.displayName ?? 'User',
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
    return Consumer<PagodaProvider>(
      builder: (context, provider, _) {
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
                    const Text(
                      'Favorites',
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
                if (favorites.isEmpty)
                  const Text('No favorites yet')
                else
                  ...favorites.take(3).map((pagoda) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.temple_buddhist),
                    title: Text(pagoda.name),
                    dense: true,
                  )),
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
}
