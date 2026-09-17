import Flutter
import CoreML
import Vision
import UIKit
import CoreVideo
import CoreImage

/// The complete inference path stays on the device. No networking or frame persistence.
final class LocalPPEPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "ai.safetylens.ppe", qos: .userInitiated)
  private var visionModel: VNCoreMLModel?
  private var processing = false
  private let imageContext = CIContext(options: [.cacheIntermediates: false])

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ai.safetylens/local_ppe", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LocalPPEPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard ["infer", "inferFrame", "snapshotFrame"].contains(call.method),
          let args = call.arguments as? [String: Any] else {
      result(FlutterMethodNotImplemented); return
    }
    guard !processing else {
      result(FlutterError(code: "FRAME_DROPPED", message: "Inference is busy; discard this frame.", details: nil)); return
    }
    processing = true
    let finish: (Any?) -> Void = { value in
      DispatchQueue.main.async { self.processing = false; result(value) }
    }
    let threshold = max(0.1, min(0.95, args["confidence"] as? Double ?? 0.4))
    queue.async {
      do {
        let started = CFAbsoluteTimeGetCurrent()
        let handler: VNImageRequestHandler
        let width: Double, height: Double
        if call.method == "inferFrame" || call.method == "snapshotFrame" {
          let buffer = try Self.pixelBuffer(args)
          // camera_avfoundation rotates its video output to locked portrait orientation.
          // The delivered BGRA buffer is already upright; do not rotate it again.
          width = Double(CVPixelBufferGetWidth(buffer))
          height = Double(CVPixelBufferGetHeight(buffer))
          if call.method == "snapshotFrame" {
            let image = CIImage(cvPixelBuffer: buffer)
            guard let data = self.imageContext.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else {
              throw NSError(domain: "SafetyPPE", code: 4, userInfo: [NSLocalizedDescriptionKey: "Snapshot encoding failed"])
            }
            finish(FlutterStandardTypedData(bytes: data)); return
          }
          handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        } else {
          guard let bytes = args["image"] as? FlutterStandardTypedData,
                let image = UIImage(data: bytes.data), let cg = image.cgImage else {
            throw NSError(domain: "SafetyPPE", code: 2, userInfo: [NSLocalizedDescriptionKey: "Image could not be decoded."])
          }
          let rotated = [.left, .leftMirrored, .right, .rightMirrored].contains(image.imageOrientation)
          width = Double(rotated ? cg.height : cg.width)
          height = Double(rotated ? cg.width : cg.height)
          handler = VNImageRequestHandler(cgImage: cg, orientation: Self.orientation(image.imageOrientation))
        }
        if self.visionModel == nil {
          guard let url = Bundle.main.url(forResource: "SafetyPPE", withExtension: "mlmodelc") else {
            throw NSError(domain: "SafetyPPE", code: 1, userInfo: [NSLocalizedDescriptionKey: "Local model is missing from the app bundle."])
          }
          let config = MLModelConfiguration()
          config.computeUnits = .all
          self.visionModel = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: config))
        }
        let request = VNCoreMLRequest(model: self.visionModel!)
        request.imageCropAndScaleOption = .scaleFit
        try handler.perform([request])
        var predictions: [[String: Any]] = (request.results as? [VNRecognizedObjectObservation] ?? []).compactMap { object in
          guard let label = object.labels.first else { return nil }
          // Vision normalizes class labels; retain the object's confidence as well.
          let confidence = Double(object.confidence) * Double(label.confidence)
          guard confidence >= threshold else { return nil }
          let b = object.boundingBox
          return ["class": label.identifier, "confidence": confidence,
                  "x": b.midX * width, "y": (1 - b.midY) * height,
                  "width": b.width * width, "height": b.height * height]
        }
        // Apple's independent person detector recovers people missed by the PPE head.
        if !predictions.contains(where: { ($0["class"] as? String)?.lowercased() == "person" }) {
          let humans = VNDetectHumanRectanglesRequest()
          humans.upperBodyOnly = false
          try handler.perform([humans])
          for human in humans.results ?? [] where human.confidence >= 0.4 {
            let b = human.boundingBox
            predictions.append(["class": "Person", "confidence": Double(human.confidence),
              "x": b.midX * width, "y": (1 - b.midY) * height,
              "width": b.width * width, "height": b.height * height])
          }
        }
        let response: [String: Any] = ["predictions": predictions,
          "image": ["width": width, "height": height],
          "supported_ppe": ["helmet", "vest", "gloves", "goggles", "mask"],
          "elapsed_ms": (CFAbsoluteTimeGetCurrent() - started) * 1000]
        finish(response)
      } catch {
        finish(FlutterError(code: "LOCAL_PPE", message: error.localizedDescription, details: nil))
      }
    }
  }

  private static func pixelBuffer(_ args: [String: Any]) throws -> CVPixelBuffer {
    guard let pixels = args["pixels"] as? FlutterStandardTypedData,
          let width = args["width"] as? Int, let height = args["height"] as? Int,
          let stride = args["bytesPerRow"] as? Int,
          width > 0, height > 0, width <= 4096, height <= 4096,
          stride >= width * 4, stride <= 32768, pixels.data.count >= stride * height else {
      throw NSError(domain: "SafetyPPE", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid BGRA frame layout"])
    }
    var pixelBuffer: CVPixelBuffer?
    guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
      [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pixelBuffer) == kCVReturnSuccess,
      let buffer = pixelBuffer else { throw NSError(domain: "SafetyPPE", code: 5) }
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let destination = CVPixelBufferGetBaseAddress(buffer)!
    let targetStride = CVPixelBufferGetBytesPerRow(buffer)
    pixels.data.withUnsafeBytes { source in
      for y in 0..<height {
        memcpy(destination.advanced(by: y * targetStride), source.baseAddress!.advanced(by: y * stride), width * 4)
      }
    }
    return buffer
  }

  private static func orientation(_ value: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch value {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}
