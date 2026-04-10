import 'package:get_it/get_it.dart';

import '../api/drive_client.dart';
import '../api/forms_client.dart';
import '../auth/google_auth_datasource.dart';
import '../../features/dashboard/data/datasources/drive_datasource.dart';
import '../../features/dashboard/data/datasources/forms_datasource.dart';
import '../../features/dashboard/data/repositories/form_repository_impl.dart';
import '../../features/dashboard/domain/repositories/form_repository.dart';
import '../../features/dashboard/domain/usecases/create_form.dart';
import '../../features/dashboard/domain/usecases/delete_form.dart';
import '../../features/dashboard/domain/usecases/get_forms.dart';
import '../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../features/sign_in/data/repositories/auth_repository_impl.dart';
import '../../features/sign_in/domain/repositories/auth_repository.dart';
import '../../features/sign_in/domain/usecases/sign_in_silently.dart';
import '../../features/sign_in/domain/usecases/sign_in_with_google.dart';
import '../../features/sign_in/domain/usecases/sign_out.dart';
import '../../features/sign_in/presentation/cubit/sign_in_cubit.dart';

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

  getIt.registerFactory(
    () => DashboardCubit(
      getForms: getIt(),
      createForm: getIt(),
      deleteForm: getIt(),
    ),
  );
}
