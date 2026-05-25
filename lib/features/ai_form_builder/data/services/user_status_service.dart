import 'package:flutter/foundation.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/user_status.dart';
import '../../domain/usecases/get_user_status.dart';

/// Singleton cache for [UserStatus]. Fetched once on dashboard mount and
/// updated only when the user explicitly taps the refresh button or after
/// a paywall dismissal. All pages read from this cache instead of calling
/// the API independently.
class UserStatusService extends ChangeNotifier {
  final GetUserStatus _getUserStatus;

  UserStatusService(this._getUserStatus);

  UserStatus? _status;
  bool _isRefreshing = false;

  UserStatus? get status => _status;
  bool get isRefreshing => _isRefreshing;

  /// Store a known status (e.g. after a full fetch inside the cubit).
  void store(UserStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Fetch from API and update cache. No-op if already in progress.
  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    notifyListeners();
    final result = await _getUserStatus(const NoParams());
    result.fold((_) {}, (s) => _status = s);
    _isRefreshing = false;
    notifyListeners();
  }
}
