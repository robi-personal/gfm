import 'package:flutter/foundation.dart';

enum QuotaTier { free, premium }

@immutable
class QuotaSnapshot {
  final QuotaTier tier;
  final int used;
  final int limit;
  final DateTime resetsAt;

  const QuotaSnapshot({
    required this.tier,
    required this.used,
    required this.limit,
    required this.resetsAt,
  });

  int get remaining => (limit - used).clamp(0, limit);
  bool get isExhausted => used >= limit;

  factory QuotaSnapshot.fromJson(Map<String, dynamic> json) {
    return QuotaSnapshot(
      tier: json['tier'] == 'premium' ? QuotaTier.premium : QuotaTier.free,
      used: (json['used'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      resetsAt: DateTime.parse(json['resetsAt'] as String),
    );
  }
}
