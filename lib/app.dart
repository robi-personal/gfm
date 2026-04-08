import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/auth/auth_cubit.dart';
import 'core/di/injection.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/sign_in/sign_in_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) =>
              AuthCubit(
                getIt(),
                getIt(),
                getIt(),
              )..checkAuth(),
      child: MaterialApp(
        title: 'Form Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4285F4)),
          useMaterial3: true,
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthSignedIn() => const DashboardScreen(),
          AuthInitial() || AuthLoading() => const _SplashScreen(),
          AuthSignedOut() || AuthSignInFailed() => const SignInScreen(),
        };
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
