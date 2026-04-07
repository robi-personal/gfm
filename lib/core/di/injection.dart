import 'package:get_it/get_it.dart';

import '../api/drive_client.dart';
import '../api/forms_client.dart';
import '../auth/google_auth_service.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  getIt.registerLazySingleton<GoogleAuthService>(GoogleAuthService.new);

  getIt.registerLazySingleton<FormsClient>(
    () => FormsClient(getIt<GoogleAuthService>()),
  );

  getIt.registerLazySingleton<DriveClient>(
    () => DriveClient(getIt<GoogleAuthService>()),
  );
}
