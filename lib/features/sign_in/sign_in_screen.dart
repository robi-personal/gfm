import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/auth_cubit.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: Column(
              children: [
                if (state case AuthSignInFailed())
                  _ErrorBanner(message: _errorMessage(state)),

                // Banner illustration — takes upper portion of screen
                Expanded(
                  child: SvgPicture.asset(
                    'assets/login_banner.svg',
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),

                // Bottom area — sign-in button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                  child: _GoogleSignInButton(
                    isLoading: isLoading,
                    onPressed:
                        isLoading ? null : () => context.read<AuthCubit>().signIn(),
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

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8E6F0), width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                SvgPicture.asset('assets/google_icon.svg', width: 22, height: 22),
              const SizedBox(width: 12),
              Text(
                isLoading ? 'Signing in…' : 'Continue with Google',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
