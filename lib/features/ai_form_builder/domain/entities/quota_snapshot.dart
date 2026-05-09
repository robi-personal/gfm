import 'package:flutter/foundation.dart';

enum QuotaTier { free, premium }

@immutable
class QuotaSnapshot {
  final QuotaTier tier;
  final int used;
  final int limit;
  final DateTime resetsAt;
  final int youtubeMinutesUsed;
  final int youtubeMinutesLimit;
  final DateTime? youtubeMinutesResetsAt;

  const QuotaSnapshot({
    required this.tier,
    required this.used,
    required this.limit,
    required this.resetsAt,
    this.youtubeMinutesUsed = 0,
    this.youtubeMinutesLimit = 300,
    this.youtubeMinutesResetsAt,
  });

  int get remaining => (limit - used).clamp(0, limit);
  bool get isExhausted => used >= limit;
  int get youtubeMinutesRemaining =>
      (youtubeMinutesLimit - youtubeMinutesUsed).clamp(0, youtubeMinutesLimit);

  factory QuotaSnapshot.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullable(String? raw) =>
        raw == null ? null : DateTime.parse(raw);
    return QuotaSnapshot(
      tier:     json['tier'] == 'premium' ? QuotaTier.premium : QuotaTier.free,
      used:     (json['used']  as num).toInt(),
      limit:    (json['limit'] as num).toInt(),
      resetsAt: DateTime.parse(json['resetsAt'] as String),
      youtubeMinutesUsed:     (json['youtubeMinutesUsed']  as num?)?.toInt() ?? 0,
      youtubeMinutesLimit:    (json['youtubeMinutesLimit'] as num?)?.toInt() ?? 300,
      youtubeMinutesResetsAt: parseNullable(json['youtubeMinutesResetsAt'] as String?),
    );
  }
}
