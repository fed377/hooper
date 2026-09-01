import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hooper/core/utils/utils.dart';

class AccountRestrictedScreen extends StatelessWidget {
  final String status; // 'suspended' | 'banned'
  final String? reason;

  const AccountRestrictedScreen({super.key, required this.status, this.reason});

  @override
  Widget build(BuildContext context) {
    final isBanned = status == 'banned';
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBanned ? Icons.block : Icons.pause_circle_outline,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(isBanned ? 'Account banned' : 'Account suspended', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                isBanned
                    ? "Your account has been permanently banned from $appname. "
                          'You can no longer be found or contacted by other players, '
                          'and any scheduled matches have been cancelled.'
                    : 'Your account has been temporarily suspended. '
                          'You can no longer be found or contacted by other players '
                          'while this is in effect, and any scheduled matches have '
                          'been cancelled.',
                textAlign: TextAlign.center,
              ),
              if (reason != null && reason!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('Reason:', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(reason!, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}
