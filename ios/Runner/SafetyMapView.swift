import Flutter
import MapKit
import UIKit

final class SafetyMapFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(_ messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?) -> FlutterPlatformView {
    SafetyMapView(frame: frame, id: id, messenger: messenger, args: args as? [String:Any] ?? [:])
  }
}

private final class SafetyPin: MKPointAnnotation {
  var index: Int?
  var zoneID: String?
  var tone = UIColor.systemGreen
}

final class SafetyMapView: NSObject, FlutterPlatformView, MKMapViewDelegate, UIGestureRecognizerDelegate {
  let map = MKMapView()
  let channel: FlutterMethodChannel
  var editable = false
  var tones: [ObjectIdentifier: UIColor] = [:]
  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, args: [String:Any]) {
    channel = FlutterMethodChannel(name: "ai.safetylens/map/\(id)", binaryMessenger: messenger)
    super.init()
    map.frame = frame; map.delegate = self
    map.isRotateEnabled = false; map.isPitchEnabled = false
    map.showsCompass = true; map.showsScale = true
    map.pointOfInterestFilter = .excludingAll
    map.setRegion(MKCoordinateRegion(center: coordinate(args), latitudinalMeters: 350, longitudinalMeters: 350), animated: false)
    let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
    tap.delegate = self; map.addGestureRecognizer(tap)
    update(args)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let a = call.arguments as? [String:Any] ?? [:]
      switch call.method {
      case "update": self.update(a)
      case "move": self.map.setRegion(MKCoordinateRegion(center: self.coordinate(a), latitudinalMeters: a["meters"] as? Double ?? 350, longitudinalMeters: a["meters"] as? Double ?? 350), animated: true)
      case "zoom":
        let region = self.map.region, factor = a["factor"] as? Double ?? 1
        self.map.setRegion(MKCoordinateRegion(center: region.center, span: MKCoordinateSpan(latitudeDelta: min(120,region.span.latitudeDelta*factor), longitudeDelta: min(180,region.span.longitudeDelta*factor))), animated: true)
      case "dispose": self.map.delegate = nil; self.channel.setMethodCallHandler(nil)
      default: result(FlutterMethodNotImplemented); return
      }
      result(nil)
    }
  }
  func view() -> UIView { map }
  func coordinate(_ a: [String:Any]) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: a["latitude"] as? Double ?? 24.7136, longitude: a["longitude"] as? Double ?? 46.6753)
  }
  func color(_ type: String) -> UIColor {
    type == "restricted" ? UIColor(red:0.91,green:0.25,blue:0.29,alpha:1) : type == "highRisk" ? .systemOrange : UIColor(red:0.04,green:0.55,blue:0.38,alpha:1)
  }
  func update(_ args: [String:Any]) {
    editable = args["editing"] as? Bool ?? false
    map.mapType = args["satellite"] as? Bool == true ? .hybrid : .standard
    map.removeOverlays(map.overlays); map.removeAnnotations(map.annotations); tones.removeAll()
    for z in args["zones"] as? [[String:Any]] ?? [] {
      let tone = color(z["type"] as? String ?? "work")
      let vertices = z["vertices"] as? [[String:Any]] ?? []
      let overlay: MKOverlay
      if vertices.count >= 3 {
        var coords = vertices.map(coordinate)
        overlay = MKPolygon(coordinates: &coords, count: coords.count)
      } else {
        overlay = MKCircle(center: coordinate(z), radius: z["radius"] as? Double ?? 30)
      }
      tones[ObjectIdentifier(overlay as AnyObject)] = tone; map.addOverlay(overlay)
      if !editable {
        let pin = SafetyPin(); pin.coordinate = coordinate(z); pin.title = z["name"] as? String
        pin.zoneID = z["id"] as? String; pin.tone = tone; map.addAnnotation(pin)
      }
    }
    if let user = args["user"] as? [String:Any] {
      let pin = SafetyPin(); pin.coordinate = coordinate(user); pin.title = "موقعك الحالي"; pin.tone = .systemBlue; map.addAnnotation(pin)
    }
    for (index,p) in (args["handles"] as? [[String:Any]] ?? []).enumerated() {
      let pin = SafetyPin(); pin.coordinate = coordinate(p); pin.index = index
      pin.title = "نقطة \(index+1)"; pin.tone = .systemTeal; map.addAnnotation(pin)
    }
    let points = args["draft"] as? [[String:Any]] ?? []
    if points.count >= 2 {
      var coords = points.map(coordinate)
      let line = MKPolyline(coordinates: &coords, count: coords.count)
      tones[ObjectIdentifier(line)] = .systemTeal; map.addOverlay(line)
    }
  }
  @objc func tapped(_ gesture: UITapGestureRecognizer) {
    let p = map.convert(gesture.location(in:map), toCoordinateFrom:map)
    channel.invokeMethod("tap", arguments:["latitude":p.latitude,"longitude":p.longitude])
  }
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    var node = touch.view
    while let v = node { if v is MKAnnotationView { return false }; node = v.superview }
    return true
  }
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    let renderer: MKOverlayPathRenderer
    if let polygon = overlay as? MKPolygon { renderer = MKPolygonRenderer(polygon:polygon) }
    else if let circle = overlay as? MKCircle { renderer = MKCircleRenderer(circle:circle) }
    else if let line = overlay as? MKPolyline { renderer = MKPolylineRenderer(polyline:line) }
    else { return MKOverlayRenderer(overlay:overlay) }
    let tone = tones[ObjectIdentifier(overlay as AnyObject)] ?? .systemTeal
    renderer.fillColor = tone.withAlphaComponent(0.18); renderer.strokeColor = tone
    renderer.lineWidth = 2.5; renderer.lineDashPattern = [7,4]
    return renderer
  }
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    guard let pin = annotation as? SafetyPin else { return nil }
    let view = MKMarkerAnnotationView(annotation:pin,reuseIdentifier:nil)
    view.markerTintColor = pin.tone; view.canShowCallout = true
    view.isDraggable = pin.index != nil && editable
    view.glyphText = pin.index.map { "\($0+1)" }
    view.displayPriority = pin.index == nil ? .defaultHigh : .required
    return view
  }
  func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
    if newState == .ending, let pin = view.annotation as? SafetyPin, let index = pin.index {
      view.dragState = .none
      channel.invokeMethod("drag", arguments:["index":index,"latitude":pin.coordinate.latitude,"longitude":pin.coordinate.longitude])
    } else if newState == .canceling { view.dragState = .none }
  }
  func mapView(_ mapView: MKMapView, didFailLoadingMapWithError error: Error) {
    channel.invokeMethod("error", arguments:"تعذر تحميل الخريطة. تحقق من اتصال الإنترنت.")
  }
  deinit { map.delegate = nil; channel.setMethodCallHandler(nil) }
}
