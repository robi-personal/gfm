import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../data/services/subscription_service.dart';

part 'subscription_state.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  final SubscriptionService _service;

  SubscriptionCubit(this._service) : super(const SubscriptionInitial());

  Future<void> load() async {
    emit(const SubscriptionLoading());
    try {
      final results = await Future.wait([
        _service.isPremium(),
        _service.getOffering(),
      ]);
      emit(SubscriptionLoaded(
        isPremium: results[0] as bool,
        offering: results[1] as Offering?,
      ));
    } catch (_) {
      emit(const SubscriptionLoaded(isPremium: false));
    }
  }

  Future<void> purchase(Package package) async {
    final current = state;
    if (current is! SubscriptionLoaded) return;
    emit(SubscriptionPurchasing(isPremium: current.isPremium, offering: current.offering));
    try {
      final info = await _service.purchase(package);
      final isPremium = info.entitlements.active.containsKey(SubscriptionService.entitlement);
      if (isClosed) return;
      emit(SubscriptionLoaded(
        isPremium: isPremium,
        offering: current.offering,
        justPurchased: isPremium,
      ));
    } on PlatformException catch (e) {
      if (isClosed) return;
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        emit(SubscriptionLoaded(isPremium: current.isPremium, offering: current.offering));
      } else {
        emit(SubscriptionError(_errorMessage(code)));
      }
    } catch (_) {
      if (isClosed) return;
      emit(const SubscriptionError('Purchase failed. Please try again.'));
    }
  }

  Future<void> restore() async {
    final current = state;
    if (current is! SubscriptionLoaded) return;
    emit(SubscriptionPurchasing(isPremium: current.isPremium, offering: current.offering));
    try {
      final info = await _service.restore();
      if (isClosed) return;
      final isPremium = info.entitlements.active.containsKey(SubscriptionService.entitlement);
      emit(SubscriptionLoaded(
        isPremium: isPremium,
        offering: current.offering,
        justPurchased: isPremium,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(const SubscriptionError('Restore failed. Please try again.'));
    }
  }

  String _errorMessage(PurchasesErrorCode code) => switch (code) {
        PurchasesErrorCode.networkError => 'No internet connection. Please try again.',
        PurchasesErrorCode.purchaseNotAllowedError => 'Purchases are not allowed on this device.',
        PurchasesErrorCode.paymentPendingError => 'Your payment is pending. Check back soon.',
        _ => 'Something went wrong. Please try again.',
      };
}
