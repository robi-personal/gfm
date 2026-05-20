import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_status.dart';
import '../repositories/ai_form_repository.dart';

class GetUserStatus implements UseCase<UserStatus, NoParams> {
  final AiFormRepository _repository;

  GetUserStatus(this._repository);

  @override
  Future<Either<Failure, UserStatus>> call(NoParams params) =>
      _repository.getUserStatus();
}

/// Polls /user/status after a purchase until the server confirms isPremium,
/// then calls [onPremiumConfirmed]. Gives up silently after [maxRetries]
/// attempts (request → wait 3s → next attempt).
Future<void> pollUntilPremium({
  required GetUserStatus useCase,
  required Future<void> Function() onPremiumConfirmed,
  int maxRetries = 6,
}) async {
  for (var i = 0; i < maxRetries; i++) {
    final result = await useCase.call(const NoParams());
    final isPremium = result.fold((_) => false, (s) => s.isPremium);
    if (isPremium) {
      await onPremiumConfirmed();
      return;
    }
    await Future.delayed(const Duration(seconds: 3));
  }
  // Webhook did not arrive within ~24s — give up silently.
}
