import 'package:flutter/material.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';

/// Profile lookups can fail while the identity session is still valid.
/// Keep that failure distinct from an account requiring registration.
class AuthErrorScreen extends StatelessWidget {
  const AuthErrorScreen({super.key, required this.authController});
  final AuthController authController;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Account unavailable')),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListenableBuilder(
                listenable: authController,
                builder: (context, _) =>
                    Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 16),
                  const Text('We could not load your account.'),
                  const SizedBox(height: 12),
                  Text(authController.errorMessage ?? 'Please retry.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: authController.isLoading
                          ? null
                          : authController.initialize,
                      child: Text(
                          authController.isLoading ? 'Retrying…' : 'Retry')),
                  TextButton(
                      onPressed: authController.isLoading
                          ? null
                          : () async {
                              try {
                                await authController.signOut();
                              } catch (_) {
                                // The controller clears local state even if remote sign-out fails.
                              }
                            },
                      child: const Text('Sign out')),
                ]),
              )),
        )),
      );
}
