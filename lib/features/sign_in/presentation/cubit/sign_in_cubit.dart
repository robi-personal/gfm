import 'package:bloc/bloc.dart';

import '../../../../core/api/drive_client.dart';
import '../../../../core/api/forms_client.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../paywall/data/services/subscription_service.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/usecases/sign_in_silently.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';

part 'sign_in_state.dart';

class SignInCubit extends Cubit<SignInState> {
  final SignInWithGoogle _signInWithGoogle;
  final SignInSilently _signInSilently;
  final SignOut _signOut;
  final FormsClient _formsClient;
  final DriveClient _driveClient;
  final SubscriptionService _subscriptionService;

  SignInCubit({
    required SignInWithGoogle signInWithGoogle,
    required SignInSilently signInSilently,
    required SignOut signOut,
    required FormsClient formsClient,
    required DriveClient driveClient,
    required SubscriptionService subscriptionService,
  })  : _signInWithGoogle = signInWithGoogle,
        _signInSilently = signInSilently,
        _signOut = signOut,
        _formsClient = formsClient,
        _driveClient = driveClient,
        _subscriptionService = subscriptionService,
        super(const SignInInitial());

  /// Called on app launch. Uses cached credentials — no UI prompt.
  Future<void> checkAuth() async {
    emit(const SignInLoading());
    final result = await _signInSilently(const NoParams());
    result.fold(
      (_) => emit(const Unauthenticated()),
      (user) {
        AnalyticsService.setUser(user.email);
        _subscriptionService.identifyUser(user.googleId).ignore();
        emit(Authenticated(user));
      },
    );
  }

  /// Interactive sign-in triggered by the user.
  Future<void> signIn() async {
    emit(const SignInLoading());
    final result = await _signInWithGoogle(const NoParams());
    result.fold(
      (failure) => switch (failure) {
        AuthCancelledFailure() => emit(const Unauthenticated()),
        _ => emit(SignInError(failure.message)),
      },
      (user) {
        AnalyticsService.setUser(user.email);
        _subscriptionService.identifyUser(user.googleId).ignore();
        emit(Authenticated(user));
      },
    );
  }

  Future<void> signOut() async {
    await _signOut();
    _formsClient.reset();
    _driveClient.reset();
    AnalyticsService.clearUser();
    _subscriptionService.clearUser().ignore();
    emit(const Unauthenticated());
  }
}
