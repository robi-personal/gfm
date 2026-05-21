import 'package:bloc/bloc.dart';

import '../../../../core/api/drive_client.dart';
import '../../../../core/api/forms_client.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/webview_session_manager.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../notifications/data/services/notification_service.dart';
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
  final NotificationService _notificationService;
  final WebViewSessionManager _webViewSession;

  SignInCubit({
    required SignInWithGoogle signInWithGoogle,
    required SignInSilently signInSilently,
    required SignOut signOut,
    required FormsClient formsClient,
    required DriveClient driveClient,
    required SubscriptionService subscriptionService,
    required NotificationService notificationService,
    required WebViewSessionManager webViewSessionManager,
  })  : _signInWithGoogle = signInWithGoogle,
        _signInSilently = signInSilently,
        _signOut = signOut,
        _formsClient = formsClient,
        _driveClient = driveClient,
        _subscriptionService = subscriptionService,
        _notificationService = notificationService,
        _webViewSession = webViewSessionManager,
        super(const SignInInitial());

  /// Called on app launch. Uses cached credentials — no UI prompt.
  Future<void> checkAuth() async {
    emit(const SignInLoading());
    final result = await _signInSilently(const NoParams());
    await result.fold<Future<void>>(
      (_) async => emit(const Unauthenticated()),
      (user) async {
        AnalyticsService.setUser(user.email);
        _subscriptionService.identifyUser(user.googleId).ignore();
        // Awaited so the dashboard never renders while a WebView clear is
        // still in flight — otherwise Import could open against half-cleared
        // cookies. Same-user case is a fast storage read + write (no clear).
        await _webViewSession.syncWithUser(user.googleId);
        // Notification registration is owned by the dashboard so it can show
        // a soft-ask rationale before triggering the system permission prompt.
        emit(Authenticated(user));
      },
    );
  }

  /// Interactive sign-in triggered by the user.
  Future<void> signIn() async {
    emit(const SignInLoading());
    final result = await _signInWithGoogle(const NoParams());
    await result.fold<Future<void>>(
      (failure) async => switch (failure) {
        AuthCancelledFailure() => emit(const Unauthenticated()),
        _ => emit(SignInError(failure.message)),
      },
      (user) async {
        AnalyticsService.setUser(user.email);
        _subscriptionService.identifyUser(user.googleId).ignore();
        await _webViewSession.syncWithUser(user.googleId);
        emit(Authenticated(user));
      },
    );
  }

  Future<void> signOut() async {
    await _notificationService.unregisterForUser();
    await _signOut();
    _formsClient.reset();
    _driveClient.reset();
    AnalyticsService.clearUser();
    _subscriptionService.clearUser().ignore();
    emit(const Unauthenticated());
  }
}
