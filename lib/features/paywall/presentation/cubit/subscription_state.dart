part of 'subscription_cubit.dart';

sealed class SubscriptionState {
  const SubscriptionState();
}

class SubscriptionInitial extends SubscriptionState {
  const SubscriptionInitial();
}

class SubscriptionLoading extends SubscriptionState {
  const SubscriptionLoading();
}

class SubscriptionLoaded extends SubscriptionState {
  final bool isPremium;
  final Offering? offering;

  /// True only immediately after a successful purchase or restore.
  final bool justPurchased;

  const SubscriptionLoaded({
    required this.isPremium,
    this.offering,
    this.justPurchased = false,
  });
}

/// Purchase / restore in flight — show loading overlay.
class SubscriptionPurchasing extends SubscriptionState {
  final bool isPremium;
  final Offering? offering;

  const SubscriptionPurchasing({required this.isPremium, this.offering});
}

class SubscriptionError extends SubscriptionState {
  final String message;
  const SubscriptionError(this.message);
}
