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
  final int youtubeMinutesUsed;
  final int youtubeMinutesLimit;
  final DateTime? youtubeMinutesResetsAt;

  const UserStatus({
    required this.isPremium,
    required this.aiFreeUsed,
    required this.aiFreeLimit,
    this.freeResetsAt,
    required this.aiPremiumUsed,
    required this.aiPremiumLimit,
    this.premiumResetsAt,
    this.gracePeriodUntil,
    this.youtubeMinutesUsed = 0,
    this.youtubeMinutesLimit = 300,
    this.youtubeMinutesResetsAt,
  });

  int get youtubeMinutesRemaining =>
      (youtubeMinutesLimit - youtubeMinutesUsed).clamp(0, youtubeMinutesLimit);

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
      youtubeMinutesUsed:     (json['youtubeMinutesUsed']  as num?)?.toInt() ?? 0,
      youtubeMinutesLimit:    (json['youtubeMinutesLimit'] as num?)?.toInt() ?? 300,
      youtubeMinutesResetsAt: parseNullable(json['youtubeMinutesResetsAt'] as String?),
    );
  }
}
