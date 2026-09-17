import ARKit
import SceneKit
import Flutter
import UIKit

final class SafetyARFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(_ messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?) -> FlutterPlatformView {
    SafetyARView(frame:frame,id:id,messenger:messenger)
  }
}

final class SafetyARView: NSObject, FlutterPlatformView, ARSCNViewDelegate, ARSessionDelegate {
  let scene = ARSCNView()
  let channel: FlutterMethodChannel
  let zonesRoot = SCNNode()
  var origin: (lat:Double,lon:Double)?
  var originOffset = SIMD3<Float>(repeating:0)
  var ground: Float?
  var data: [[String:Any]] = []
  var selected: String?
  var markers: [(String,SCNVector3)] = []
  var displayLink: CADisplayLink?
  var latest: [String:Any] = [:]
  var active = false
  var tracking = "initializing"
  var projectionOutstanding = false
  // Kept for the lifetime of this platform view; no Flutter camera session is opened.
  init(frame:CGRect,id:Int64,messenger:FlutterBinaryMessenger) {
    channel=FlutterMethodChannel(name:"ai.safetylens/ar/\(id)",binaryMessenger:messenger)
    super.init()
    scene.frame=frame;scene.scene=SCNScene();scene.scene.rootNode.addChildNode(zonesRoot)
    scene.delegate=self;scene.session.delegate=self;scene.session.delegateQueue = .main
    scene.automaticallyUpdatesLighting=true;scene.preferredFramesPerSecond=30
    channel.setMethodCallHandler { [weak self] call,result in
      guard let self=self else {result(nil);return}
      switch call.method {
      case "update": self.update(call.arguments as? [String:Any] ?? [:]);result(nil)
      case "start": self.start();result(["supported":ARWorldTrackingConfiguration.isSupported])
      case "pause": self.pause();result(nil)
      case "reset": self.origin=nil;self.originOffset = .zero;self.ground=nil;self.start(reset:true);self.update(self.latest);result(nil)
      case "dispose": self.pause();self.channel.setMethodCallHandler(nil);result(nil)
      default:result(FlutterMethodNotImplemented)
      }
    }
    NotificationCenter.default.addObserver(self,selector:#selector(background),name:UIApplication.didEnterBackgroundNotification,object:nil)
  }
  func view()->UIView {scene}
  func start(reset:Bool=false) {
    guard ARWorldTrackingConfiguration.isSupported else {channel.invokeMethod("state",arguments:["error":"الواقع المعزز غير متاح على هذا الجهاز"]);return}
    let configuration=ARWorldTrackingConfiguration()
    configuration.worldAlignment = .gravityAndHeading
    configuration.planeDetection = [.horizontal]
    configuration.isLightEstimationEnabled=true
    scene.session.run(configuration,options:reset ? [.resetTracking,.removeExistingAnchors]:[])
    active=true
    if displayLink == nil {
      let link=CADisplayLink(target:self,selector:#selector(project))
      link.preferredFramesPerSecond=8;link.add(to:.main,forMode:.common);displayLink=link
    }
  }
  @objc func background(){pause()}
  func pause(){active=false;displayLink?.invalidate();displayLink=nil;scene.session.pause();zonesRoot.isHidden=true}
  func update(_ args:[String:Any]) {
    latest=args
    let fresh=args["fresh"] as? Bool ?? false
    if origin == nil, fresh, let lat=args["latitude"] as? Double,let lon=args["longitude"] as? Double, let frame=scene.session.currentFrame {
      origin=(lat,lon);originOffset=SIMD3(frame.camera.transform.columns.3.x,frame.camera.transform.columns.3.y,frame.camera.transform.columns.3.z)
    }
    data=args["zones"] as? [[String:Any]] ?? [];selected=args["selected"] as? String
    rebuild()
  }
  func point(_ lat:Double,_ lon:Double)->SCNVector3 {
    guard let o=origin else{return SCNVector3Zero}
    let east=(lon-o.lon)*111195*cos(o.lat * .pi/180)
    let north=(lat-o.lat)*111195
    return SCNVector3(Float(east)+originOffset.x,ground ?? -1.5,Float(-north)+originOffset.z)
  }
  func material(_ color:UIColor)->SCNMaterial {
    let m=SCNMaterial();m.diffuse.contents=color;m.lightingModel = .constant;m.isDoubleSided=true;m.writesToDepthBuffer=false
    return m
  }
  func rebuild() {
    zonesRoot.childNodes.forEach{$0.removeFromParentNode()};markers.removeAll()
    guard origin != nil, ground != nil else{return}
    for (rank,z) in data.prefix(12).enumerated() {
      guard let id=z["id"] as? String,let lat=z["latitude"] as? Double,let lon=z["longitude"] as? Double else{continue}
      let type=z["type"] as? String ?? "work"
      let tone=type=="restricted" ? UIColor(red:1,green:0.22,blue:0.26,alpha:1) : type=="highRisk" ? UIColor.systemOrange : UIColor(red:0.1,green:0.95,blue:0.61,alpha:1)
      let isSelected=id==selected,center=point(lat,lon)
      var vertices:[SCNVector3]=[]
      let raw=z["vertices"] as? [[String:Any]] ?? []
      if raw.count>=3 {
        vertices=raw.compactMap {v in guard let a=v["latitude"] as? Double,let b=v["longitude"] as? Double else{return nil};return point(a,b)}
      } else {
        let radius=z["radius"] as? Double ?? 30
        for n in 0..<48 {let angle=Double(n)/48 * .pi*2;vertices.append(SCNVector3(center.x+Float(cos(angle)*radius),center.y,center.z+Float(sin(angle)*radius)))}
      }
      guard vertices.count>=3 else{continue}
      let path=UIBezierPath();path.move(to:CGPoint(x:CGFloat(vertices[0].x),y:CGFloat(-vertices[0].z)))
      for p in vertices.dropFirst(){path.addLine(to:CGPoint(x:CGFloat(p.x),y:CGFloat(-p.z)))}
      path.close()
      let shape=SCNShape(path:path,extrusionDepth:0.005)
      shape.materials=[material(tone.withAlphaComponent(isSelected ? 0.25:0.12))]
      let fill=SCNNode(geometry:shape);fill.eulerAngles.x = -.pi/2;fill.position.y=(ground ?? -1.5)+Float(rank)*0.008
      zonesRoot.addChildNode(fill)
      for i in vertices.indices {
        let a=vertices[i],b=vertices[(i+1)%vertices.count]
        let length=hypot(b.x-a.x,b.z-a.z)
        guard length>0.01 else{continue}
        let height:CGFloat=type=="work" ? 0.045 : isSelected ? 1.6:1.0
        let wall=SCNBox(width:CGFloat(length),height:height,length:0.035,chamferRadius:0)
        wall.materials=[material(tone.withAlphaComponent(type=="work" ? 0.9 : 0.17))]
        let node=SCNNode(geometry:wall)
        node.position=SCNVector3((a.x+b.x)/2,a.y+Float(height)/2,(a.z+b.z)/2)
        node.eulerAngles.y = -atan2(b.z-a.z,b.x-a.x)
        zonesRoot.addChildNode(node)
        let rail=SCNBox(width:CGFloat(length),height:0.025,length:0.04,chamferRadius:0);rail.materials=[material(tone.withAlphaComponent(0.8))]
        let outline=SCNNode(geometry:rail);outline.position=SCNVector3(node.position.x,a.y+Float(height),node.position.z);outline.eulerAngles.y=node.eulerAngles.y;zonesRoot.addChildNode(outline)
      }
      markers.append((id,SCNVector3(center.x,(ground ?? -1.5)+0.8,center.z)))
    }
  }
  @objc func project() {
    guard active, let frame=scene.session.currentFrame,scene.bounds.width>0,scene.bounds.height>0,!projectionOutstanding else{return}
    if origin==nil { update(latest) }
    let accuracy=latest["accuracy"] as? Double ?? 999
    let valid=(latest["fresh"] as? Bool ?? false) && accuracy<=20 && tracking=="normal" && ground != nil
    zonesRoot.isHidden = !valid
    let projected:[[String:Any]]=valid ? markers.compactMap { id,p in
      let camera=scene.pointOfView?.convertPosition(p,from:nil) ?? SCNVector3Zero
      guard camera.z<0 else{return nil}
      let screen=scene.projectPoint(p)
      guard screen.z>=0 && screen.z<=1 else{return nil}
      return ["id":id,"x":Double(screen.x)/Double(scene.bounds.width),"y":Double(screen.y)/Double(scene.bounds.height)]
    }:[]
    projectionOutstanding=true
    channel.invokeMethod("projection",arguments:["markers":projected,"tracking":tracking,"ground":ground != nil,"calibrated":origin != nil,"visible":valid]) { [weak self] _ in self?.projectionOutstanding=false }
  }
  func session(_ session:ARSession,cameraDidChangeTrackingState camera:ARCamera) {
    switch camera.trackingState {case .normal:tracking="normal";case .notAvailable:tracking="unavailable";case .limited(let reason):switch reason {case .excessiveMotion:tracking="motion";case .insufficientFeatures:tracking="features";default:tracking="initializing"}}
  }
  func renderer(_ renderer:SCNSceneRenderer,didAdd node:SCNNode,for anchor:ARAnchor){updateGround(anchor)}
  func renderer(_ renderer:SCNSceneRenderer,didUpdate node:SCNNode,for anchor:ARAnchor){updateGround(anchor)}
  func updateGround(_ anchor:ARAnchor) {
    guard let plane=anchor as? ARPlaneAnchor,plane.alignment == .horizontal else{return}
    let y=plane.transform.columns.3.y
    DispatchQueue.main.async { [weak self] in
      guard let self=self,let camera=self.scene.session.currentFrame?.camera, y<camera.transform.columns.3.y-0.5 else{return}
      if self.ground == nil || y<(self.ground ?? y)-0.08 {self.ground=y;self.rebuild()}
    }
  }
  func sessionWasInterrupted(_ session:ARSession){tracking="unavailable";zonesRoot.isHidden=true}
  func sessionInterruptionEnded(_ session:ARSession){origin=nil;ground=nil;start(reset:true)}
  func session(_ session:ARSession,didFailWithError error:Error){pause();channel.invokeMethod("state",arguments:["error":"تعذر تتبع الواقع المعزز. أعد المعايرة وحرك الجهاز بهدوء."])}
  deinit {displayLink?.invalidate();scene.session.pause();scene.delegate=nil;scene.session.delegate=nil;channel.setMethodCallHandler(nil);NotificationCenter.default.removeObserver(self)}
}
