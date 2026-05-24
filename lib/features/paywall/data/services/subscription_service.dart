import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static const String _appId = 'appl_MkzXtKeEEhIYCwtQEgOdWquRCGK';
  static const String entitlement = 'GFMPremium';
  static const String _offeringId = 'default';

  static Future<void> configure() async {
    await Purchases.setLogLevel(LogLevel.error);
    await Purchases.configure(PurchasesConfiguration(_appId));
  }

  Future<void> identifyUser(String userId) async {
    debugPrint('[rc] identifyUser: $userId');
    final result = await Purchases.logIn(userId);
    debugPrint('[rc] identifyUser done — created=${result.created}');
  }

  Future<void> clearUser() async {
    debugPrint('[rc] clearUser');
    await Purchases.logOut();
    debugPrint('[rc] clearUser done');
  }

  Future<bool> isPremium() async {
    final info = await Purchases.getCustomerInfo();
    final active = info.entitlements.active.keys.toList();
    debugPrint('[rc] isPremium — active entitlements: $active');
    return info.entitlements.active.containsKey(entitlement);
  }

  Future<Offering?> getOffering() async {
    final offerings = await Purchases.getOfferings();
    final offering = offerings.getOffering(_offeringId) ?? offerings.current;
    debugPrint('[rc] getOffering — id=${offering?.identifier}, packages=${offering?.availablePackages.map((p) => p.storeProduct.identifier).toList()}');
    return offering;
  }

  Future<CustomerInfo> purchase(Package package) async {
    debugPrint('[rc] purchase start — package=${package.identifier} product=${package.storeProduct.identifier}');
    final result = await Purchases.purchase(PurchaseParams.package(package));
    final active = result.customerInfo.entitlements.active.keys.toList();
    debugPrint('[rc] purchase done — active entitlements: $active');
    return result.customerInfo;
  }

  Future<CustomerInfo> restore() async {
    debugPrint('[rc] restore start');
    final info = await Purchases.restorePurchases();
    final active = info.entitlements.active.keys.toList();
    debugPrint('[rc] restore done — active entitlements: $active');
    return info;
  }
}
