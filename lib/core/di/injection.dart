import 'package:get_it/get_it.dart';

import '../api/drive_client.dart';
import '../api/forms_client.dart';
import '../auth/google_auth_datasource.dart';
import '../services/webview_session_manager.dart';
import '../../features/paywall/data/services/purchase_activation_service.dart';
import '../../features/paywall/data/services/subscription_service.dart';
import '../../features/paywall/presentation/cubit/subscription_cubit.dart';
import '../../features/dashboard/data/datasources/drive_datasource.dart';
import '../../features/dashboard/data/datasources/forms_datasource.dart';
import '../../features/dashboard/data/repositories/form_repository_impl.dart';
import '../../features/dashboard/domain/repositories/form_repository.dart';
import '../../features/dashboard/domain/usecases/create_form.dart';
import '../../features/dashboard/domain/usecases/delete_form.dart';
import '../../features/dashboard/domain/usecases/get_forms.dart';
import '../../features/dashboard/domain/usecases/get_imported_forms.dart';
import '../../features/dashboard/domain/usecases/import_form.dart';
import '../../features/dashboard/domain/usecases/remove_imported_form.dart';
import '../../features/dashboard/domain/usecases/rename_form.dart';
import '../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../features/sign_in/data/repositories/auth_repository_impl.dart';
import '../../features/sign_in/domain/repositories/auth_repository.dart';
import '../../features/sign_in/domain/usecases/sign_in_silently.dart';
import '../../features/sign_in/domain/usecases/sign_in_with_google.dart';
import '../../features/sign_in/domain/usecases/sign_out.dart';
import '../../features/editor/data/datasources/editor_datasource.dart';
import '../../features/editor/data/repositories/editor_repository_impl.dart';
import '../../features/editor/domain/repositories/editor_repository.dart';
import '../../features/editor/domain/usecases/execute_batch.dart';
import '../../features/editor/domain/usecases/load_form.dart';
import '../../features/editor/domain/usecases/refresh_revision.dart';
import '../../features/editor/domain/usecases/update_editor_settings.dart';
import '../../features/editor/presentation/pages/tabs/questions/cubit/questions_cubit.dart';
import '../../features/editor/presentation/pages/tabs/settings/cubit/settings_cubit.dart';
import '../../features/editor/data/repositories/responses_repository_impl.dart';
import '../../features/editor/domain/repositories/responses_repository.dart';
import '../../features/editor/domain/usecases/get_responses.dart';
import '../../features/editor/presentation/pages/tabs/responses/cubit/responses_cubit.dart';
import '../../features/sign_in/presentation/cubit/sign_in_cubit.dart';
import '../../features/ai_form_builder/data/datasources/ai_form_datasource.dart';
import '../../features/ai_form_builder/data/repositories/ai_form_repository_impl.dart';
import '../../features/ai_form_builder/domain/repositories/ai_form_repository.dart';
import '../../features/ai_form_builder/domain/usecases/create_form_from_ai.dart';
import '../../features/ai_form_builder/domain/usecases/generate_form.dart';
import '../../features/ai_form_builder/domain/usecases/get_user_status.dart';
import '../../features/ai_form_builder/presentation/cubit/ai_form_builder_cubit.dart';
import '../../features/notifications/data/datasources/notifications_api.dart';
import '../../features/notifications/data/services/notification_service.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  // ── Infrastructure ────────────────────────────────────────────────────────
  getIt.registerLazySingleton<GoogleAuthDataSource>(
    GoogleAuthDataSource.new,
  );

  getIt.registerLazySingleton<FormsClient>(
    () => FormsClient(getIt<GoogleAuthDataSource>()),
  );

  getIt.registerLazySingleton<DriveClient>(
    () => DriveClient(getIt<GoogleAuthDataSource>()),
  );

  getIt.registerLazySingleton<WebViewSessionManager>(
    () => WebViewSessionManager(),
  );

  // ── Sign-in feature ───────────────────────────────────────────────────────
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<GoogleAuthDataSource>()),
  );

  getIt.registerLazySingleton(
    () => SignInWithGoogle(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => SignInSilently(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton(
    () => SignOut(getIt<AuthRepository>()),
  );

  getIt.registerFactory(
    () => SignInCubit(
      signInWithGoogle: getIt(),
      signInSilently: getIt(),
      signOut: getIt(),
      formsClient: getIt(),
      driveClient: getIt(),
      driveDataSource: getIt(),
      subscriptionService: getIt(),
      notificationService: getIt(),
      webViewSessionManager: getIt(),
    ),
  );

  // ── Dashboard feature ─────────────────────────────────────────────────────
  getIt.registerLazySingleton(
    () => DriveDataSource(getIt<DriveClient>()),
  );

  getIt.registerLazySingleton(
    () => FormsDataSource(getIt<FormsClient>()),
  );

  getIt.registerLazySingleton<FormRepository>(
    () => FormRepositoryImpl(
      getIt<DriveDataSource>(),
      getIt<FormsDataSource>(),
    ),
  );

  getIt.registerLazySingleton(
    () => GetForms(getIt<FormRepository>()),
  );
  getIt.registerLazySingleton(
    () => CreateForm(getIt<FormRepository>()),
  );
  getIt.registerLazySingleton(
    () => DeleteForm(getIt<FormRepository>()),
  );
  getIt.registerLazySingleton(
    () => RenameForm(getIt<FormRepository>()),
  );
  getIt.registerLazySingleton(
    () => GetImportedForms(getIt<FormRepository>()),
  );
  getIt.registerLazySingleton(
    () => ImportForm(getIt<FormRepository>()),
  );
  getIt.registerLazySingleton(
    () => RemoveImportedForm(getIt<FormRepository>()),
  );

  getIt.registerFactory(
    () => DashboardCubit(
      getForms: getIt(),
      createForm: getIt(),
      deleteForm: getIt(),
      renameForm: getIt(),
      getImportedForms: getIt(),
      importForm: getIt(),
      removeImportedForm: getIt(),
    ),
  );

  // ── Responses feature ─────────────────────────────────────────────────────
  getIt.registerLazySingleton<ResponsesRepository>(
    () => ResponsesRepositoryImpl(getIt<EditorDataSource>()),
  );

  getIt.registerLazySingleton(
    () => GetResponses(getIt<ResponsesRepository>()),
  );

  getIt.registerFactory(
    () => ResponsesCubit(getIt<GetResponses>()),
  );

  // ── Editor feature ────────────────────────────────────────────────────────
  getIt.registerLazySingleton(
    () => EditorDataSource(getIt<FormsClient>()),
  );

  getIt.registerLazySingleton<EditorRepository>(
    () => EditorRepositoryImpl(getIt<EditorDataSource>()),
  );

  getIt.registerLazySingleton(
    () => LoadForm(getIt<EditorRepository>()),
  );
  getIt.registerLazySingleton(
    () => ExecuteBatch(getIt<EditorRepository>()),
  );
  getIt.registerLazySingleton(
    () => RefreshRevision(getIt<EditorRepository>()),
  );
  getIt.registerLazySingleton(
    () => UpdateEditorSettings(getIt<EditorRepository>()),
  );

  getIt.registerFactory(
    () => QuestionsCubit(
      loadForm: getIt(),
      executeBatch: getIt(),
      refreshRevision: getIt(),
    ),
  );

  getIt.registerFactory(
    () => SettingsCubit(getIt<UpdateEditorSettings>()),
  );

  // ── AI Form Builder feature ───────────────────────────────────────────────
  getIt.registerLazySingleton(
    () => AiFormDataSource(auth: getIt<GoogleAuthDataSource>()),
  );

  getIt.registerLazySingleton<AiFormRepository>(
    () => AiFormRepositoryImpl(
      aiDataSource: getIt<AiFormDataSource>(),
      formsDataSource: getIt<FormsDataSource>(),
    ),
  );

  getIt.registerLazySingleton(
    () => GetUserStatus(getIt<AiFormRepository>()),
  );
  getIt.registerLazySingleton(
    () => GenerateForm(getIt<AiFormRepository>()),
  );
  getIt.registerLazySingleton(
    () => CreateFormFromAi(getIt<AiFormRepository>()),
  );

  getIt.registerFactory(
    () => AiFormBuilderCubit(
      getUserStatus: getIt<GetUserStatus>(),
      generateForm: getIt<GenerateForm>(),
      createFormFromAi: getIt<CreateFormFromAi>(),
      activation: getIt<PurchaseActivationService>(),
    ),
  );

  // ── Paywall / subscription feature ────────────────────────────────────────
  getIt.registerLazySingleton(() => SubscriptionService());

  getIt.registerLazySingleton(
    () => PurchaseActivationService(
      getIt<NotificationsApi>(),
      getIt<SubscriptionService>(),
    ),
  );

  getIt.registerFactory(
    () => SubscriptionCubit(
      getIt<SubscriptionService>(),
      getIt<PurchaseActivationService>(),
    ),
  );

  // ── Push notifications ────────────────────────────────────────────────────
  getIt.registerLazySingleton(
    () => NotificationsApi(auth: getIt<GoogleAuthDataSource>()),
  );
  getIt.registerLazySingleton(
    () => NotificationService(getIt<NotificationsApi>()),
  );
}
