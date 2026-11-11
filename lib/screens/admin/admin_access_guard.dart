import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AdminAccessGuard extends StatelessWidget {
  final Widget child;

  const AdminAccessGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.isAuthenticated && auth.isAdmin) return child;

        return Scaffold(
          appBar: AppBar(title: const Text('Administrator access')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 52,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This area is only available to administrators.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  if (!auth.isAuthenticated)
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: const Text('Sign in'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
