import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../ai_form_builder/domain/usecases/get_user_status.dart';
import '../../data/services/purchase_activation_service.dart';
import '../../data/services/subscription_service.dart';

part 'subscription_state.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  final SubscriptionService _service;
  final PurchaseActivationService _activation;
  final GetUserStatus _getUserStatus;

  SubscriptionCubit(this._service, this._activation, this._getUserStatus)
      : super(const SubscriptionInitial());

  Future<void> load() async {
    emit(const SubscriptionLoading());
    try {
      final results = await Future.wait([
        _service.isPremium(),
        _service.getOffering(),
        _fetchBackendProductId(),
      ]);
      emit(SubscriptionLoaded(
        isPremium: results[0] as bool,
        offering: results[1] as Offering?,
        currentProductId: results[2] as String?,
      ));
    } catch (_) {
      emit(const SubscriptionLoaded(isPremium: false));
    }
  }

  Future<void> purchase(Package package) async {
    final current = state;
    if (current is! SubscriptionLoaded) return;
    debugPrint('[cubit] purchase — package=${package.identifier}');
    emit(SubscriptionPurchasing(isPremium: current.isPremium, offering: current.offering));
    try {
      final info = await _service.purchase(package);
      final isPremium = info.entitlements.active.containsKey(SubscriptionService.entitlement);
      debugPrint('[cubit] purchase — RC returned isPremium=$isPremium');
      if (isPremium) await _reconcileWithBackend();
      // Backend is authoritative for the active product (RC SDK leaks across
      // Google accounts that share an Apple ID).
      final backendProductId = isPremium ? await _fetchBackendProductId() : null;
      debugPrint('[cubit] purchase — backendProductId=$backendProductId');
      if (isClosed) return;
      emit(SubscriptionLoaded(
        isPremium: isPremium,
        offering: current.offering,
        currentProductId: backendProductId,
        justPurchased: isPremium,
      ));
    } on PlatformException catch (e) {
      if (isClosed) return;
      final code = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('[cubit] purchase — PlatformException code=$code');
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        emit(SubscriptionLoaded(isPremium: current.isPremium, offering: current.offering));
      } else {
        emit(SubscriptionError(_errorMessage(code)));
      }
    } catch (e) {
      debugPrint('[cubit] purchase — unexpected error: $e');
      if (isClosed) return;
      emit(const SubscriptionError('Purchase failed. Please try again.'));
    }
  }

  Future<void> restore() async {
    final current = state;
    if (current is! SubscriptionLoaded) return;
    debugPrint('[cubit] restore start');
    emit(SubscriptionPurchasing(isPremium: current.isPremium, offering: current.offering));
    try {
      final info = await _service.restore();
      final isPremium = info.entitlements.active.containsKey(SubscriptionService.entitlement);
      debugPrint('[cubit] restore — RC returned isPremium=$isPremium');
      if (isPremium) await _reconcileWithBackend();
      final backendProductId = isPremium ? await _fetchBackendProductId() : null;
      debugPrint('[cubit] restore — backendProductId=$backendProductId');
      if (isClosed) return;
      emit(SubscriptionLoaded(
        isPremium: isPremium,
        offering: current.offering,
        currentProductId: backendProductId,
        justPurchased: isPremium,
      ));
    } catch (e) {
      debugPrint('[cubit] restore — error: $e');
      if (isClosed) return;
      emit(const SubscriptionError('Restore failed. Please try again.'));
    }
  }

  /// Block on one sync attempt so the happy path dismisses the paywall with
  /// a fully provisioned account. If it fails, kick off background retries —
  /// the dashboard renders an activation banner while they run.
  Future<void> _reconcileWithBackend() async {
    debugPrint('[cubit] _reconcileWithBackend start');
    final ok = await _activation.syncOnce();
    debugPrint('[cubit] _reconcileWithBackend — syncOnce ok=$ok');
    if (!ok) _activation.startBackgroundRetries();
  }

  Future<String?> _fetchBackendProductId() async {
    debugPrint('[cubit] _fetchBackendProductId start');
    final result = await _getUserStatus(const NoParams());
    final productId = result.fold((_) => null, (s) => s.subscriptionProductId);
    debugPrint('[cubit] _fetchBackendProductId — productId=$productId');
    return productId;
  }

  String _errorMessage(PurchasesErrorCode code) => switch (code) {
        PurchasesErrorCode.networkError => 'No internet connection. Please try again.',
        PurchasesErrorCode.purchaseNotAllowedError => 'Purchases are not allowed on this device.',
        PurchasesErrorCode.paymentPendingError => 'Your payment is pending. Check back soon.',
        _ => 'Something went wrong. Please try again.',
      };
}
