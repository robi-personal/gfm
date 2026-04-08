import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/auth_cubit.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: Column(
              children: [
                if (state case AuthSignInFailed())
                  _ErrorBanner(
                    message: _errorMessage(state),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Form Manager',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create, edit, and share Google Forms\nfrom your phone.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 64),
                        FilledButton.icon(
                          onPressed:
                              isLoading
                                  ? null
                                  : () =>
                                      context.read<AuthCubit>().signIn(),
                          icon:
                              isLoading
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.login),
                          label: Text(
                            isLoading ? 'Signing in…' : 'Sign in with Google',
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'By signing in, you agree to Google\'s Terms of Service '
                          'and Privacy Policy. Your forms are stored in your own '
                          'Google Drive.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _errorMessage(AuthSignInFailed state) {
    // Network-related errors get the user-facing copy from §8.2
    final msg = state.message.toLowerCase();
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('timeout')) {
      return "Couldn't reach Google. Check your connection.";
    }
    return "Couldn't reach Google. Check your connection.";
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.warning_outlined, color: Colors.orange[800], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.orange[900], fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: () => context.read<AuthCubit>().signIn(),
            child: Icon(Icons.close, color: Colors.orange[800], size: 20),
          ),
        ],
      ),
    );
  }
}
