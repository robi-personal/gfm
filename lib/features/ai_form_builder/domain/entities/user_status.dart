import 'package:flutter/foundation.dart';

@immutable
class UserStatus {
  final bool isPremium;
  final int quotaBalance;
  final bool unlimited;
  final DateTime? gracePeriodUntil;
  // The product ID of the user's active subscription, per the backend.
  // Authoritative for "Current Plan" UI — RC SDK's CustomerInfo is keyed by
  // the device's Apple ID and leaks across Google accounts on a shared device.
  final String? subscriptionProductId;
  final int youtubeMinutesUsed;
  final int youtubeMinutesLimit;
  final DateTime? youtubeMinutesResetsAt;

  const UserStatus({
    required this.isPremium,
    required this.quotaBalance,
    required this.unlimited,
    this.gracePeriodUntil,
    this.subscriptionProductId,
    this.youtubeMinutesUsed = 0,
    this.youtubeMinutesLimit = 300,
    this.youtubeMinutesResetsAt,
  });

  int get youtubeMinutesRemaining =>
      (youtubeMinutesLimit - youtubeMinutesUsed).clamp(0, youtubeMinutesLimit);

  bool get isQuotaExhausted => !unlimited && quotaBalance <= 0;

  factory UserStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullable(String? raw) =>
        raw == null ? null : DateTime.parse(raw);

    return UserStatus(
      isPremium:     json['isPremium']    as bool,
      quotaBalance:  (json['quotaBalance'] as num).toInt(),
      unlimited:     json['unlimited']    as bool,
      gracePeriodUntil: parseNullable(json['gracePeriodUntil'] as String?),
      subscriptionProductId: json['subscriptionProductId'] as String?,
      youtubeMinutesUsed:     (json['youtubeMinutesUsed']  as num?)?.toInt() ?? 0,
      youtubeMinutesLimit:    (json['youtubeMinutesLimit'] as num?)?.toInt() ?? 300,
      youtubeMinutesResetsAt: parseNullable(json['youtubeMinutesResetsAt'] as String?),
    );
  }
}
