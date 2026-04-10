import 'package:dartz/dartz.dart';

import '../error/failure.dart';

/// Base contract for all use cases.
///
/// [T] — the success return type.
/// [P] — the input parameters type. Use [NoParams] when none are needed.
abstract class UseCase<T, P> {
  Future<Either<Failure, T>> call(P params);
}

/// Passed to [UseCase.call] when the use case requires no input.
class NoParams {
  const NoParams();
}
