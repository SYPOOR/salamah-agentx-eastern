import Flutter
import UIKit
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testLocalPPEOfflineAndOrientation() throws {
    let plugin = LocalPPEPlugin()
    let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "workers", withExtension: "jpg"))
    let data = try Data(contentsOf: url)
    let result = infer(plugin, data)
    let predictions = result["predictions"] as? [[String:Any]] ?? []
    let labels = predictions.compactMap { $0["class"] as? String }
    XCTAssertTrue(labels.contains("Hardhat"), "Helmet must be detected from bundled image")
    XCTAssertTrue(labels.contains("Safety Vest"))
    XCTAssertTrue(labels.contains("Person"), "Native Vision must recover full-body people")
    XCTAssertTrue(predictions.allSatisfy { ($0["confidence"] as? Double ?? 0) >= 0.4 })
    let image = try XCTUnwrap(result["image"] as? [String:Double])
    XCTAssertEqual(image["width"], 518)
    XCTAssertEqual(image["height"], 880)
    XCTAssertLessThan(result["elapsed_ms"] as? Double ?? 99999, 15000)
    let attachment = XCTAttachment(string: String(describing: result))
    attachment.lifetime = .keepAlways
    add(attachment)
    let blank = UIGraphicsImageRenderer(size: CGSize(width:640,height:640)).image { ctx in
      UIColor.black.setFill(); ctx.fill(CGRect(x:0,y:0,width:640,height:640))
    }.jpegData(compressionQuality:1)!
    let empty = infer(plugin, blank)
    XCTAssertTrue((empty["predictions"] as? [[String:Any]] ?? []).isEmpty, "Blank frames must not pass as PPE")
    // EXIF orientation should be applied before converting boxes to display coordinates.
    let source = try XCTUnwrap(UIImage(data:data)?.cgImage)
    let rotated = UIImage(cgImage:source,scale:1,orientation:.right).jpegData(compressionQuality:1)!
    let rotatedResult = infer(plugin, rotated)
    let rotatedSize = try XCTUnwrap(rotatedResult["image"] as? [String:Double])
    XCTAssertEqual(rotatedSize["width"], 880)
    XCTAssertEqual(rotatedSize["height"], 518)
  }
  func testRawVideoFramesAndBusyDrop() throws {
    let plugin = LocalPPEPlugin()
    let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "workers", withExtension: "jpg"))
    let image = try XCTUnwrap(UIImage(data: Data(contentsOf: url))?.cgImage)
    let width = image.width, height = image.height, stride = width * 4 + 32
    var pixels = Data(count: stride * height)
    pixels.withUnsafeMutableBytes { ptr in
      let context = CGContext(data: ptr.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: stride,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
      context.draw(image, in: CGRect(x:0,y:0,width:width,height:height))
    }
    let args: [String:Any] = ["pixels": FlutterStandardTypedData(bytes:pixels), "width":width,"height":height,"bytesPerRow":stride,"confidence":0.4]
    let done=expectation(description:"Accepted video frame")
    let dropped=expectation(description:"Busy frame discarded immediately")
    plugin.handle(FlutterMethodCall(methodName:"inferFrame",arguments:args)) { value in
      let result=value as? [String:Any] ?? [:]
      let objects=result["predictions"] as? [[String:Any]] ?? []
      XCTAssertTrue(objects.contains { ($0["class"] as? String) == "Hardhat" })
      XCTAssertEqual(objects.filter { ($0["class"] as? String) == "Person" }.count,2)
      let helmet=objects.first { ($0["class"] as? String) == "Hardhat" }
      XCTAssertLessThan(helmet?["y"] as? Double ?? 9999,Double(height)/2)
      let size=result["image"] as? [String:Double]
      XCTAssertEqual(size?["width"],Double(width));XCTAssertEqual(size?["height"],Double(height))
      let attachment=XCTAttachment(string:String(describing:result));attachment.lifetime = .keepAlways;self.add(attachment)
      done.fulfill()
    }
    plugin.handle(FlutterMethodCall(methodName:"inferFrame",arguments:args)) { value in
      XCTAssertEqual((value as? FlutterError)?.code,"FRAME_DROPPED");dropped.fulfill()
    }
    wait(for:[done,dropped],timeout:30)
    // Repeated warm frames exercise pixel-buffer ownership without any JPEG encoding/files.
    for _ in 0..<20 {
      let frame=expectation(description:"Next raw frame")
      plugin.handle(FlutterMethodCall(methodName:"inferFrame",arguments:args)) { value in
        XCTAssertNotNil(value as? [String:Any]);frame.fulfill()
      }
      wait(for:[frame],timeout:5)
    }
    let invalid=expectation(description:"Malformed stride rejected")
    plugin.handle(FlutterMethodCall(methodName:"inferFrame",arguments:["pixels":FlutterStandardTypedData(bytes:Data(count:4)),"width":width,"height":height,"bytesPerRow":1])) { value in
      XCTAssertEqual((value as? FlutterError)?.code,"LOCAL_PPE");invalid.fulfill()
    }
    wait(for:[invalid],timeout:5)
  }
  private func infer(_ plugin:LocalPPEPlugin,_ data:Data) -> [String:Any] {
    let done=expectation(description:"Local Core ML inference")
    var response:[String:Any]=[:]
    plugin.handle(FlutterMethodCall(methodName:"infer",arguments:["image":FlutterStandardTypedData(bytes:data),"confidence":0.4])) { value in
      if let error=value as? FlutterError { XCTFail("\(error.code): \(error.message ?? "")") }
      response=value as? [String:Any] ?? [:]; done.fulfill()
    }
    wait(for:[done],timeout:30)
    return response
  }
}
