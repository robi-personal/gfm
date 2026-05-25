import 'package:flutter/foundation.dart';

@immutable
class QuotaSnapshot {
  final int balance;
  final int quotaCost;
  final bool unlimited;
  final int youtubeMinutesUsed;
  final int youtubeMinutesLimit;

  const QuotaSnapshot({
    required this.balance,
    required this.quotaCost,
    required this.unlimited,
    this.youtubeMinutesUsed = 0,
    this.youtubeMinutesLimit = 300,
  });

  int get remaining => balance;
  bool get isExhausted => !unlimited && balance < quotaCost;
  int get youtubeMinutesRemaining =>
      (youtubeMinutesLimit - youtubeMinutesUsed).clamp(0, youtubeMinutesLimit);

  factory QuotaSnapshot.fromJson(Map<String, dynamic> json) {
    return QuotaSnapshot(
      balance:   (json['balance']   as num).toInt(),
      quotaCost: (json['quotaCost'] as num).toInt(),
      unlimited: json['unlimited']  as bool,
      youtubeMinutesUsed:  (json['youtubeMinutesUsed']  as num?)?.toInt() ?? 0,
      youtubeMinutesLimit: (json['youtubeMinutesLimit'] as num?)?.toInt() ?? 300,
    );
  }
}
