import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/sign_in/presentation/cubit/sign_in_cubit.dart';
import 'features/sign_in/presentation/screens/sign_in_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SignInCubit>()..checkAuth(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
    return BlocBuilder<SignInCubit, SignInState>(
      builder: (context, state) {
        return switch (state) {
          Authenticated() => const DashboardPage(),
          SignInInitial() || SignInLoading() => const _SplashScreen(),
          Unauthenticated() || SignInError() => const SignInScreen(),
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
