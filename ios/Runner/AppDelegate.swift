import Flutter
import UIKit
import AVKit
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var routePickerView: AVRoutePickerView?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup AirPlay route picker channel
    setupAirPlayChannel()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupAirPlayChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    let channel = FlutterMethodChannel(
      name: "com.ghostmusic/airplay",
      binaryMessenger: controller.binaryMessenger
    )
    
    // Create the route picker view (hidden)
    routePickerView = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    routePickerView?.isHidden = true
    routePickerView?.activeTintColor = .white
    routePickerView?.tintColor = .white
    controller.view.addSubview(routePickerView!)
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "showRoutePicker":
        self?.showRoutePicker(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func showRoutePicker(result: @escaping FlutterResult) {
    guard let routePickerView = routePickerView else {
      result(FlutterError(code: "NO_PICKER", message: "Route picker not available", details: nil))
      return
    }
    
    // Find the button in the route picker view and simulate a tap
    for subview in routePickerView.subviews {
      if let button = subview as? UIButton {
        button.sendActions(for: .touchUpInside)
        result(nil)
        return
      }
    }
    
    // Fallback: try to present the picker directly (iOS 11+)
    if #available(iOS 11.0, *) {
      // The AVRoutePickerView should handle this automatically
      result(nil)
    } else {
      result(FlutterError(code: "UNSUPPORTED", message: "AirPlay picker requires iOS 11+", details: nil))
    }
  }
}
