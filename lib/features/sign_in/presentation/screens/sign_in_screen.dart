import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design.dart';
import '../cubit/sign_in_cubit.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/sign_in_error_row.dart';
import '../widgets/sign_in_hero.dart';
import '../widgets/sign_in_legal_row.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocBuilder<SignInCubit, SignInState>(
        builder: (context, state) {
          final isLoading = state is SignInLoading;
          final error = state is SignInError ? state.message : null;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Expanded(child: SignInHero()),
                  if (error != null) ...[
                    SignInErrorRow(
                      message: error,
                      onRetry: () => context.read<SignInCubit>().signIn(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  GoogleSignInButton(
                    isLoading: isLoading,
                    onTap: isLoading
                        ? null
                        : () => context.read<SignInCubit>().signIn(),
                  ),
                  const SizedBox(height: 14),
                  const SignInLegalRow(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
