import AppKit
import Foundation
let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
func render(_ pixels:Int,_ filename:String) {
 let color = CGColor(red:12/255,green:97/255,blue:78/255,alpha:1)
 let context = CGContext(data:nil,width:pixels,height:pixels,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
 context.scaleBy(x:CGFloat(pixels)/1024,y:CGFloat(pixels)/1024)
 context.setFillColor(CGColor(red:243/255,green:246/255,blue:248/255,alpha:1));context.fill(CGRect(x:0,y:0,width:1024,height:1024))
 let shield=CGMutablePath();shield.move(to:CGPoint(x:512,y:850));shield.addLine(to:CGPoint(x:792,y:740));shield.addLine(to:CGPoint(x:776,y:470));shield.addCurve(to:CGPoint(x:512,y:168),control1:CGPoint(x:761,y:329),control2:CGPoint(x:638,y:215));shield.addCurve(to:CGPoint(x:248,y:470),control1:CGPoint(x:386,y:215),control2:CGPoint(x:263,y:329));shield.addLine(to:CGPoint(x:232,y:740));shield.closeSubpath();context.addPath(shield);context.setFillColor(color);context.fillPath()
 context.setStrokeColor(CGColor(red:1,green:1,blue:1,alpha:1));context.setLineWidth(27);context.setLineCap(.round);context.setLineJoin(.round)
 // A hardhat and verification mark, drawn as scalable vector geometry.
 let helmet=CGMutablePath();helmet.move(to:CGPoint(x:364,y:519));helmet.addLine(to:CGPoint(x:364,y:562));helmet.addCurve(to:CGPoint(x:484,y:685),control1:CGPoint(x:364,y:630),control2:CGPoint(x:419,y:685));helmet.move(to:CGPoint(x:540,y:685));helmet.addCurve(to:CGPoint(x:660,y:562),control1:CGPoint(x:606,y:685),control2:CGPoint(x:660,y:630));helmet.addLine(to:CGPoint(x:660,y:519));helmet.move(to:CGPoint(x:330,y:519));helmet.addLine(to:CGPoint(x:694,y:519));context.addPath(helmet);context.strokePath()
 context.setFillColor(CGColor(red:1,green:1,blue:1,alpha:1));context.addPath(CGPath(roundedRect:CGRect(x:491,y:574,width:42,height:144),cornerWidth:15,cornerHeight:15,transform:nil));context.fillPath()
 context.setStrokeColor(CGColor(red:114/255,green:231/255,blue:187/255,alpha:1));context.setLineWidth(33)
 context.move(to:CGPoint(x:431,y:409));context.addLine(to:CGPoint(x:494,y:348));context.addLine(to:CGPoint(x:606,y:450));context.strokePath()
 let image=context.makeImage()!;let bitmap=NSBitmapImageRep(cgImage:image);let data=bitmap.representation(using:.png,properties:[:])!;try! data.write(to:URL(fileURLWithPath:filename))
}
let iconPath="\(root)/ios/Runner/Assets.xcassets/AppIcon.appiconset"
let data=try! Data(contentsOf:URL(fileURLWithPath:"\(iconPath)/Contents.json"));let manifest=try! JSONSerialization.jsonObject(with:data) as! [String:Any]
for entry in manifest["images"] as! [[String:String]] {let size=Double(entry["size"]!.components(separatedBy:"x")[0])!;let scale=Double(entry["scale"]!.replacingOccurrences(of:"x",with:""))!;render(Int(size*scale),"\(iconPath)/\(entry["filename"]!)")}
for (density,size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {render(size,"\(root)/android/app/src/main/res/mipmap-\(density)/ic_launcher.png")}
render(1024,"\(root)/docs/app-icon.png")
