import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let registrar = registrar(forPlugin: "VoceChatImageConversion")!
    let channel = FlutterMethodChannel(
      name: "vocechat/image_conversion", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "heifToJpeg" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let bytes = call.arguments as? FlutterStandardTypedData else {
        result(FlutterError(code: "invalid_image", message: "Missing photo data", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let jpeg = autoreleasepool { PhotoConversion.jpeg(from: bytes.data) }
        DispatchQueue.main.async {
          if let jpeg = jpeg {
            result(FlutterStandardTypedData(bytes: jpeg))
          } else {
            result(FlutterError(code: "image_conversion_failed",
              message: "Could not convert the photo to JPEG", details: nil))
          }
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

enum PhotoConversion {
  static func jpeg(from data: Data) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    // Draw to bake in EXIF orientation, flatten transparency, and use a
    // standard dynamic range image readable by non-Apple decoders.
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    format.preferredRange = .standard
    let normalized = UIGraphicsImageRenderer(size: image.size, format: format).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: image.size))
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
    return normalized.jpegData(compressionQuality: 0.9)
  }
}
