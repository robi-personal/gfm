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
    await Purchases.logIn(userId);
  }

  Future<void> clearUser() async {
    await Purchases.logOut();
  }

  Future<bool> isPremium() async {
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey(entitlement);
  }

  Future<String?> getCurrentProductId() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active[entitlement]?.productIdentifier;
    } catch (_) {
      return null;
    }
  }

  Future<Offering?> getOffering() async {
    final offerings = await Purchases.getOfferings();
    return offerings.getOffering(_offeringId) ?? offerings.current;
  }

  Future<CustomerInfo> purchase(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  Future<CustomerInfo> restore() {
    return Purchases.restorePurchases();
  }
}
