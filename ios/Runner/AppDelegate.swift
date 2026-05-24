import Flutter
import FirebaseCore
import FirebaseMessaging
import StoreKit
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    NSLog("[APNs] ✅ Token received (\(deviceToken.count) bytes)")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[APNs] ❌ Registration failed: \(error)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerAppleSubscriptionChannel(with: engineBridge.pluginRegistry)
  }

  // ── Apple Subscription Method Channel ─────────────────────────────────────
  // Returns the Apple originalTransactionId of the first active auto-renewable
  // subscription on this device, or nil. Used by the paywall pre-check to
  // detect "this Apple ID is already linked to another Google account."
  private func registerAppleSubscriptionChannel(with registry: FlutterPluginRegistry) {
    let registrar = registry.registrar(forPlugin: "AppleSubscriptionChannel")!
    let channel = FlutterMethodChannel(
      name: "com.rashed.gfm/apple_subscription",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getOriginalTransactionId":
        Task {
          for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else { continue }
            guard transaction.productType == .autoRenewable else { continue }
            result(String(transaction.originalID))
            return
          }
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
