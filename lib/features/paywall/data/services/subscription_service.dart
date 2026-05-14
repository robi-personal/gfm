import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static const String _appId = 'appl_VqBfURjMPtsRNeYwSTgjKBoJifp';
  static const String entitlement = 'gfm_premium';
  static const String _offeringId = 'GFMDefault';

  static Future<void> configure() async {
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

  Future<Offering?> getOffering() async {
    final offerings = await Purchases.getOfferings();
    return offerings.getOffering(_offeringId) ?? offerings.current;
  }

  Future<CustomerInfo> purchase(Package package) {
    return Purchases.purchasePackage(package);
  }

  Future<CustomerInfo> restore() {
    return Purchases.restorePurchases();
  }
}
