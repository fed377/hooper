import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/features/profile/data/user_preferences.dart';

class UserSettingsScreen extends ConsumerStatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  ConsumerState<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends ConsumerState<UserSettingsScreen> {
  bool _saving = false;

  Future<void> _savePrefs(UserPreference prefs) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(preferencesRepoProvider);
      final uid = ref.read(currentUserIdProvider);
      await repo.updatePreferences(uid, prefs);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setGlass(UserPreference prefs, bool value) async {
    await _savePrefs(prefs.copyWith(glass: value));
  }

  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    Navigator.of(context).pop();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(myPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: prefsAsync.when(
        data: (UserPreference prefs) => _buildBody(prefs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(UserPreference prefs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection('Appearance', [
          SwitchListTile(
            title: const Text('Glass effect'),
            subtitle: const Text(
              'Frosted, blurred backgrounds instead of flat cards',
            ),
            value: prefs.glass,
            onChanged: (v) => _setGlass(prefs, v),
          ),
        ]),
        const SizedBox(height: 8),
        _buildSection('Privacy', [
          ListTile(
            title: const Text('Blocked users'),
            subtitle: Text(
              prefs.blockedUsers.isEmpty
                  ? 'None'
                  : prefs.blockedUsers.join(', '),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _buildSection('Match Preferences', [
          SwitchListTile(
            title: const Text('Friendly matches by default'),
            subtitle: const Text('New challenges will be friendly'),
            value: prefs.defaultFriendly,
            onChanged: (v) => _savePrefs(prefs.copyWith(defaultFriendly: v)),
          ),
          SwitchListTile(
            title: const Text('Private matches by default'),
            subtitle: const Text('New challenges will be private'),
            value: prefs.defaultPrivate,
            onChanged: (v) => _savePrefs(prefs.copyWith(defaultPrivate: v)),
          ),
        ]),
        const SizedBox(height: 8),
        _buildSection('Account', [
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: _logOut,
          ),
        ]),
      ],
    );
  }

  // Deliberately not a BlurredContainer: this page has no background image
  // for glass to refract, so sections always use the flat, non-glass card
  // look (elevation color + shadow, no blur) regardless of the app's glass setting.
  Widget _buildSection(String title, List<Widget> children) {
    final colors = HooprTheme.instance;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.elevationColors[0],
        borderRadius: BorderRadius.circular(23),
        boxShadow: [colors.blurredContainerShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

extension PreferenceCopy on UserPreference {
  UserPreference copyWith({
    List<String>? blockedUsers,
    List<String>? blockedBy,
    bool? defaultFriendly,
    bool? defaultPrivate,
    bool? glass,
  }) {
    return UserPreference(
      blockedUsers: blockedUsers ?? this.blockedUsers,
      blockedBy: blockedBy ?? this.blockedBy,
      userId: userId,
      defaultFriendly: defaultFriendly ?? this.defaultFriendly,
      defaultPrivate: defaultPrivate ?? this.defaultPrivate,
      glass: glass ?? this.glass,
    );
  }
}
