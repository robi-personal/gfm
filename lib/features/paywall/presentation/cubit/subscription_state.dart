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
  final String? currentProductId;

  /// True only immediately after a successful purchase or restore.
  final bool justPurchased;

  const SubscriptionLoaded({
    required this.isPremium,
    this.offering,
    this.currentProductId,
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

/// Apple ID is already bound to a different Google account.
/// The overlay dismisses and a dialog is shown; the paywall stays open.
class SubscriptionAppleBindingConflict extends SubscriptionState {
  final String message;
  final bool isPremium;
  final Offering? offering;
  const SubscriptionAppleBindingConflict({
    required this.message,
    required this.isPremium,
    this.offering,
  });
}
