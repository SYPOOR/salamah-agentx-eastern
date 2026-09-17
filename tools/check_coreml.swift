import Foundation
import CoreML
import Vision
let model = try VNCoreMLModel(for: MLModel(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
for path in CommandLine.arguments.dropFirst(2) {
 let req = VNCoreMLRequest(model: model)
 req.imageCropAndScaleOption = .scaleFit
 let started = Date()
 try VNImageRequestHandler(url: URL(fileURLWithPath:path)).perform([req])
 let objects = (req.results as? [VNRecognizedObjectObservation] ?? []).compactMap { o -> [String:Any]? in
   guard let l=o.labels.first, l.confidence >= 0.4 else { return nil }
   return ["label":l.identifier,"confidence":Double(l.confidence),"objectConfidence":Double(o.confidence),"x":o.boundingBox.midX,"y":o.boundingBox.midY]
 }
 let data=try JSONSerialization.data(withJSONObject:["image":URL(fileURLWithPath:path).lastPathComponent,"elapsedMs":Date().timeIntervalSince(started)*1000,"objects":objects],options:.sortedKeys)
 print(String(data:data,encoding:.utf8)!)
}
