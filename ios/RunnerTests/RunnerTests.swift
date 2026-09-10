import Flutter
import UIKit
import XCTest
import ImageIO
@testable import Runner

class RunnerTests: XCTestCase {

  func testHeicConvertsToDecodableJpegWithPortraitOrientation() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let original = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20), format: format).image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
    }
    let heic = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      heic, "public.heic" as CFString, 1, nil) else {
      throw XCTSkip("HEIC encoder unavailable on this simulator; run on iPhone")
    }
    CGImageDestinationAddImage(destination, try XCTUnwrap(original.cgImage),
      [kCGImagePropertyOrientation: 6] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw XCTSkip("HEIC encoding unavailable on this simulator; run on iPhone")
    }
    let jpeg = try XCTUnwrap(PhotoConversion.jpeg(from: heic as Data))
    XCTAssertEqual(Array(jpeg.prefix(3)), [0xff, 0xd8, 0xff])
    let decoded = try XCTUnwrap(UIImage(data: jpeg))
    XCTAssertEqual(decoded.imageOrientation, .up)
    XCTAssertEqual(decoded.size.width, original.size.height)
    XCTAssertEqual(decoded.size.height, original.size.width)
  }

  func testInvalidPhotoDoesNotProduceFakeJpeg() {
    XCTAssertNil(PhotoConversion.jpeg(from: Data([1, 2, 3])))
  }

}
