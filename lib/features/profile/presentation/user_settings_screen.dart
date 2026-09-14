import 'dart:developer' show log;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/utils/utils.dart';
import 'package:hooper/core/widgets/background_image.dart';
import 'package:hooper/features/profile/data/user_preferences.dart';

class UserSettingsScreen extends ConsumerStatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  ConsumerState<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends ConsumerState<UserSettingsScreen> {
  bool _saving = false;

  // Optimistic local value so the preview under the Glass toggle animates
  // the instant the user flips it, instead of waiting on the Firestore
  // round-trip. Cleared once the save settles (success or failure), at
  // which point the real prefs.glass value takes over again.
  bool? _localGlassOverride;

  Future<void> _savePrefs(UserPreference prefs) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(preferencesRepoProvider);
      final uid = ref.read(currentUserIdProvider);
      await repo.updatePreferences(uid, prefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      log(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setGlass(UserPreference prefs, bool value) async {
    setState(() => _localGlassOverride = value);
    await _savePrefs(prefs.copyWith(glass: value));
    if (mounted) setState(() => _localGlassOverride = null);
  }

  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in at any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    Navigator.of(context).pop();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();
  }

  void _showExplanation(String title, String body) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it'))],
      ),
    );
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
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: prefsAsync.when(
        data: (UserPreference prefs) => _buildBody(prefs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          log(e.toString());
          return Center(child: Text('Could not load settings: ${friendlyError(e)}'));
        },
      ),
    );
  }

  Widget _buildBody(UserPreference prefs) {
    final effectiveGlass = _localGlassOverride ?? prefs.glass;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection('Appearance', [
          _buildToggleRow(
            title: 'Glass effect',
            subtitle: 'Frosted, blurred backgrounds instead of flat cards',
            explanation:
                "When on, cards and panels use a translucent frosted-glass look over your photos. When off, they're "
                'flat solid cards instead — usually easier to read, and lighter on older devices.',
            value: effectiveGlass,
            onChanged: (v) => _setGlass(prefs, v),
          ),
          const SizedBox(height: 12),
          _buildGlassPreview(effectiveGlass),
          const SizedBox(height: 4),
        ]),
        const SizedBox(height: 12),
        _buildSection('Privacy', [
          ListTile(
            title: const Text('Blocked users'),
            subtitle: Text(prefs.blockedUsers.isEmpty ? 'None' : prefs.blockedUsers.join(', ')),
          ),
        ]),
        const SizedBox(height: 12),
        _buildSection('Match Preferences', [
          _buildToggleRow(
            title: 'Friendly matches by default',
            subtitle: 'New challenges will be friendly',
            explanation:
                "Friendly matches don't affect either player's ELO rating. You can still "
                'change this for each match before sending it.',
            value: prefs.defaultFriendly,
            onChanged: (v) => _savePrefs(prefs.copyWith(defaultFriendly: v)),
          ),
          const SizedBox(height: 4),
          _buildToggleRow(
            title: 'Private matches by default',
            subtitle: 'New challenges will be private',
            explanation:
                'Private matches are hidden from other players, only you and your opponent can see any details. '
                'Your ELO still updates normally.',
            value: prefs.defaultPrivate,
            onChanged: (v) => _savePrefs(prefs.copyWith(defaultPrivate: v)),
          ),
        ]),
        const SizedBox(height: 12),
        _buildSection('Account', [
          ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: _logOut),
        ]),
      ],
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required String explanation,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: .center,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: .center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: .w600)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.help_outline_rounded, size: 18),
                  tooltip: 'What does this do?',
                  onPressed: () => _showExplanation(title, explanation),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _BlackToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildGlassPreview(bool glassOn) {
    return ClipRSuperellipse(
      borderRadius: .circular(24),
      child: SizedBox(
        height: 130,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackgroundImage(),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: AnimatedContainer(
                  duration: Durations.medium2,
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                  decoration: ShapeDecoration(
                    color: glassOn ? Colors.white.withAlpha(55) : Colors.white,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: .circular(20),
                      side: glassOn ? BorderSide(color: Colors.white.withAlpha(110)) : .none,
                    ),
                    shadows: glassOn
                        ? const []
                        : const [BoxShadow(color: Color.fromARGB(60, 0, 0, 0), spreadRadius: -1, blurRadius: 16)],
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: Durations.medium2,
                    style: TextStyle(color: glassOn ? Colors.white : Colors.black, fontWeight: .w700, fontSize: 13),
                    textAlign: .center,
                    child: Text(glassOn ? 'Glass preview' : 'Flat preview'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final colors = HooprTheme.instance;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.elevationColors[0],
        borderRadius: BorderRadius.circular(23),
        boxShadow: [colors.blurredContainerShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _BlackToggle extends StatelessWidget {
  const _BlackToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: Durations.short4,
        curve: Curves.easeInOut,
        width: 52,
        height: 32,
        padding: const EdgeInsets.all(4),
        decoration: ShapeDecoration(
          color: value ? Colors.black : const Color(0x1F000000),
          shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        ),
        child: AnimatedAlign(
          duration: Durations.short4,
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
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
