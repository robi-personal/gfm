import 'package:flutter/foundation.dart';

@immutable
class UserStatus {
  final bool isPremium;
  final int aiFreeUsed;
  final int aiFreeLimit;
  final DateTime? freeResetsAt;
  final int aiPremiumUsed;
  final int aiPremiumLimit;
  final DateTime? premiumResetsAt;
  final DateTime? gracePeriodUntil;

  const UserStatus({
    required this.isPremium,
    required this.aiFreeUsed,
    required this.aiFreeLimit,
    this.freeResetsAt,
    required this.aiPremiumUsed,
    required this.aiPremiumLimit,
    this.premiumResetsAt,
    this.gracePeriodUntil,
  });

  int get effectiveUsed => isPremium ? aiPremiumUsed : aiFreeUsed;
  int get effectiveLimit => isPremium ? aiPremiumLimit : aiFreeLimit;
  int get effectiveRemaining => (effectiveLimit - effectiveUsed).clamp(0, effectiveLimit);
  bool get isQuotaExhausted => effectiveUsed >= effectiveLimit;
  DateTime? get effectiveResetsAt => isPremium ? premiumResetsAt : freeResetsAt;

  factory UserStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullable(String? raw) =>
        raw == null ? null : DateTime.parse(raw);

    return UserStatus(
      isPremium: json['isPremium'] as bool,
      aiFreeUsed: (json['aiFreeUsed'] as num).toInt(),
      aiFreeLimit: (json['aiFreeLimit'] as num).toInt(),
      freeResetsAt: parseNullable(json['freeResetsAt'] as String?),
      aiPremiumUsed: (json['aiPremiumUsed'] as num).toInt(),
      aiPremiumLimit: (json['aiPremiumLimit'] as num).toInt(),
      premiumResetsAt: parseNullable(json['premiumResetsAt'] as String?),
      gracePeriodUntil: parseNullable(json['gracePeriodUntil'] as String?),
    );
  }
}
