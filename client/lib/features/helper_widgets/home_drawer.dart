import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:muzic/core/screen_names.dart';
import 'package:muzic/core/services/auth_services.dart';
import 'package:muzic/features/resources/repositories/player_cubit.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileTile(user: user),
              const Divider(height: 32),
              const Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 10),
                  Text('Settings and privacy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Google sign-in gives us a profile photo; email/password doesn't. Either
/// way we show just the first word of the display name here — same
/// convention most apps (Google included) use for a compact greeting.
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.user});

  final User? user;

  String get _firstName {
    final name = user?.displayName;
    if (name == null || name.trim().isEmpty) return 'User';
    return name.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showProfileSheet(context, user),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Text(_firstName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

void _showProfileSheet(BuildContext context, User? user) {
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null ? const Icon(Icons.person, size: 36) : null,
              ),
              const SizedBox(height: 16),
              Text(user?.displayName ?? 'User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (user?.email != null) ...[
                const SizedBox(height: 4),
                Text(user!.email!, style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Stop playback before signing out — PlayerCubit lives at
                    // the app root, above the router, so navigating away from
                    // the main screen alone never touches it.
                    await sheetContext.read<PlayerCubit>().stop();
                    await AuthService().signOut();
                    if (!sheetContext.mounted) return;
                    sheetContext.goNamed(ScreenNames.loginScreen);
                  },
                  child: const Text('Log out'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
