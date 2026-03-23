import 'package:flutter/material.dart';
import '../login/login_page.dart';
import '../settings/api_settings_page.dart';
import '../../services/local_storage_service.dart';

class ProfilePage extends StatefulWidget {
  final String userPhone;

  const ProfilePage({super.key, this.userPhone = 'User'});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Clear user data/session from local storage
                await LocalStorageService.clearAllData();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[900]
                    : Theme.of(context).colorScheme.inversePrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.account_circle,
                    size: 80,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.tealAccent
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trip Claim User',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.userPhone,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Account Settings Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Account Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              icon: Icons.electric_meter,
              title: 'Meter Information',
              subtitle: 'View and manage meter details',
              onTap: () {
                // TODO: Navigate to meter info page
              },
            ),
            const SizedBox(height: 8),
            _buildSettingsCard(
              icon: Icons.phone,
              title: 'Phone Number',
              subtitle: 'Update your phone number',
              onTap: () {
                // TODO: Navigate to update phone page
              },
            ),
            const SizedBox(height: 8),
            _buildSettingsCard(
              icon: Icons.security,
              title: 'Change Password',
              subtitle: 'Update your password',
              onTap: () {
                // TODO: Navigate to change password page
              },
            ),
            const SizedBox(height: 32),
            // Other Settings Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Other Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              icon: Icons.api,
              title: 'API Settings',
              subtitle: 'Configure API URL and authentication',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ApiSettingsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildSettingsCard(
              icon: Icons.cloud_off,
              title: 'Offline Claims',
              subtitle: 'View and sync offline submissions',
              onTap: _showOfflineClaimsDialog,
            ),
            const SizedBox(height: 8),
            _buildSettingsCard(
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'Get help with your account',
              onTap: () {
                // TODO: Navigate to help page
              },
            ),
            const SizedBox(height: 8),
            _buildSettingsCard(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              onTap: () {
                // TODO: Navigate to privacy policy
              },
            ),
            const SizedBox(height: 32),
            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _showLogoutConfirmation,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showOfflineClaimsDialog() async {
    final stats = await LocalStorageService.getStorageStats();
    final unsyncedClaims = await LocalStorageService.getUnsyncedClaims();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Offline Claims'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statistics
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Storage Statistics',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Claims: ${stats['totalClaims']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Synced: ${stats['syncedClaims']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Pending: ${stats['unsyncedClaims']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Unsynced Claims List
                if (unsyncedClaims.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Submissions (${unsyncedClaims.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          itemCount: unsyncedClaims.length,
                          itemBuilder: (context, index) {
                            final claim = unsyncedClaims[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        claim['description'] ??
                                            'No description',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Saved: ${claim['savedAt'] ?? 'Unknown'}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            if (stats['unsyncedClaims'] > 0)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Retry sync in Trip Claim page when online',
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Sync Now',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
