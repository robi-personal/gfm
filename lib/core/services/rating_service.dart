import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks meaningful user actions (form generations and saves) and requests
/// a native App Store review after every [_threshold] actions.
///
/// Apple silently throttles the prompt to ~3 times per year, so calling this
/// frequently is safe — the OS decides whether to actually show the dialog.
class RatingService {
  static const _key = 'rating_action_count';
  static const _threshold = 3;

  final SharedPreferences _prefs;

  RatingService(this._prefs);

  /// Call after a successful form generation or form save.
  Future<void> recordAction() async {
    final count = (_prefs.getInt(_key) ?? 0) + 1;
    await _prefs.setInt(_key, count);

    if (count % _threshold == 0) {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    }
  }
}
