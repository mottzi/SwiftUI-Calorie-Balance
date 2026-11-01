import Foundation
import CoreGraphics
import CoreText
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct Point: Decodable { let x: Double; let y: Double }
struct Phone: Decodable { let centerX: Double; let centerY: Double; let height: Double; let finalCenterX: Double; let finalCenterY: Double; let finalHeight: Double }
struct Brand: Decodable { let x: Double; let y: Double; let size: Double }
struct Heading: Decodable { let x: Double; let firstBaseline: Double; let secondBaseline: Double; let size: Double }
struct ReadingPosition: Decodable { let x: Double; let labelY: Double; let valueY: Double; let unitX: Double; let unitY: Double; let startX: Double; let startY: Double }
struct Health: Decodable { let x: Double; let y: Double; let size: Double; let captionSize: Double }
struct Layout: Decodable { let width: Int; let height: Int; let phone: Phone; let brand: Brand; let earlyHeading: Heading; let finalHeading: Heading; let readings: [ReadingPosition]; let labelSize: Double; let valueSize: Double; let unitSize: Double; let health: Health; let phoneEntryX: Double }
struct Reading: Decodable { let name: String; let value: String; let unit: String; let color: String; let pulseStart: Double; let cardFraction: Double }
struct Timing: Decodable { let readingsFadeStart: Double; let readingsFadeEnd: Double; let forwardStart: Double; let forwardEnd: Double; let holdStart: Double; let holdEnd: Double; let resetEnd: Double; let poster: Double; let finalPoster: Double; let headingFadeStart: Double; let headingFadeEnd: Double; let healthFadeStart: Double; let healthFadeEnd: Double; let finalHeadingStart: Double; let finalHeadingEnd: Double }
struct Assets: Decodable { let phone: String; let capture: String; let health: String; let posePattern: String; let poseCount: Int; let poseWidth: Int; let poseHeight: Int }
struct Config: Decodable { let title: String; let duration: Double; let fps: Int; let background: String; let assets: Assets; let colors: [String:String]; let readingData: [Reading]; let timing: Timing; let layouts: [String:Layout] }

let configURL = URL(fileURLWithPath: CommandLine.arguments[1])
let cfg = try JSONDecoder().decode(Config.self, from: Data(contentsOf: configURL))
let collection = configURL.deletingLastPathComponent().deletingLastPathComponent()
let variant = CommandLine.arguments[2]
let mode = CommandLine.arguments[3]
let output = CommandLine.arguments[4]
let outWidth = Int(CommandLine.arguments[5])!
let layout = cfg.layouts[variant]!
let outHeight = Int((Double(outWidth) * Double(layout.height) / Double(layout.width)).rounded())
let scale = Double(outWidth) / Double(layout.width)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let format = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
var imageCache = [String:CGImage]()
var imageOrder = [String]()
func image(_ relative: String) -> CGImage {
    if let hit = imageCache[relative] { return hit }
    let url = collection.appendingPathComponent(relative)
    let source = CGImageSourceCreateWithURL(url as CFURL,nil)!
    let value = CGImageSourceCreateImageAtIndex(source,0,nil)!
    imageCache[relative] = value; imageOrder.append(relative)
    if imageOrder.count > 8 { imageCache.removeValue(forKey: imageOrder.removeFirst()) }
    return value
}
func color(_ hex: String, _ alpha: Double = 1) -> CGColor {
    let n = UInt32(hex.replacingOccurrences(of:"#",with:""),radix:16)!
    return CGColor(red:Double((n>>16)&255)/255,green:Double((n>>8)&255)/255,blue:Double(n&255)/255,alpha:max(0,min(1,alpha)))
}
func clamp(_ x: Double) -> Double { max(0,min(1,x)) }
func smooth(_ x: Double) -> Double { let p=clamp(x); return p*p*(3-2*p) }
func soft(_ x: Double) -> Double { let p=clamp(x); return p*p*p*(p*(p*6-15)+10) }
func ramp(_ t: Double, _ a: Double, _ b: Double) -> Double { smooth((t-a)/(b-a)) }
func mix(_ a: Double, _ b: Double, _ p: Double) -> Double { a+(b-a)*p }
func text(_ c: CGContext,_ str: String,_ x: Double,_ y: Double,_ size: Double,_ weight: NSFont.Weight,_ hex: String,_ opacity: Double=1,_ kern: Double=0) {
    guard opacity>0 else{return}
    let font=NSFont.systemFont(ofSize:size,weight:weight) as CTFont
    let attrs=[kCTFontAttributeName:font,kCTForegroundColorAttributeName:color(hex,opacity),kCTKernAttributeName:kern] as CFDictionary
    let attr=CFAttributedStringCreate(nil,str as CFString,attrs)!
    c.saveGState(); c.translateBy(x:x,y:y); c.scaleBy(x:1,y:-1); c.textMatrix = .identity; c.textPosition = .zero
    CTLineDraw(CTLineCreateWithAttributedString(attr),c); c.restoreGState()
}
func centeredText(_ c:CGContext,_ str:String,_ x:Double,_ y:Double,_ size:Double,_ hex:String,_ alpha:Double) {
    let font=NSFont.systemFont(ofSize:size,weight:.regular) as CTFont
    let attrs=[kCTFontAttributeName:font] as CFDictionary
    let line=CTLineCreateWithAttributedString(CFAttributedStringCreate(nil,str as CFString,attrs)!)
    text(c,str,x-CTLineGetTypographicBounds(line,nil,nil,nil)/2,y,size,.regular,hex,alpha)
}
func drawImage(_ c:CGContext,_ img:CGImage,_ rect:CGRect,_ alpha:Double=1) {
    c.saveGState(); c.setAlpha(alpha); c.translateBy(x:rect.minX,y:rect.maxY); c.scaleBy(x:1,y:-1)
    c.draw(img,in:CGRect(x:0,y:0,width:rect.width,height:rect.height)); c.restoreGState()
}
func bezier(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint,_ d:CGPoint,_ p:Double)->CGPoint {
    let u=1-p
    return CGPoint(x:u*u*u*a.x+3*u*u*p*b.x+3*u*p*p*c.x+p*p*p*d.x,y:u*u*u*a.y+3*u*u*p*b.y+3*u*p*p*c.y+p*p*p*d.y)
}
func route(_ index:Int)->[CGPoint] {
    let reading=layout.readings[index], h=layout.health
    let a=CGPoint(x:reading.startX,y:reading.startY), d=CGPoint(x:h.x,y:h.y)
    var points=[CGPoint]()
    let b:CGPoint, cc:CGPoint, target:CGPoint, out1:CGPoint, out2:CGPoint
    if variant == "wide" {
        b=CGPoint(x:850,y:reading.startY); cc=CGPoint(x:910,y:h.y)
        let targetY=layout.phone.centerY-layout.phone.height/2+layout.phone.height*cfg.readingData[index].cardFraction
        target=CGPoint(x:layout.phoneEntryX+20,y:targetY)
        out1=CGPoint(x:h.x+118,y:h.y); out2=CGPoint(x:layout.phoneEntryX-38,y:targetY)
    } else {
        b=CGPoint(x:reading.startX,y:590); cc=CGPoint(x:h.x,y:564)
        target=CGPoint(x:540,y:layout.phone.centerY-layout.phone.height/2+70)
        out1=CGPoint(x:h.x,y:h.y+90); out2=CGPoint(x:540,y:target.y-65)
    }
    for i in 0...90 { points.append(bezier(a,b,cc,d,Double(i)/90)) }
    for i in 1...90 { points.append(bezier(d,out1,out2,target,Double(i)/90)) }
    return points
}
let routes=(0..<3).map{route($0)}
func path(_ points:[CGPoint],_ from:Double=0,_ to:Double=1)->CGPath? {
    let lo=max(0,Int(from*Double(points.count-1))), hi=min(points.count-1,Int(to*Double(points.count-1)))
    guard hi>lo else{return nil}
    let p=CGMutablePath();p.move(to:points[lo]);for k in (lo+1)...hi {p.addLine(to:points[k])};return p
}
func stroke(_ c:CGContext,_ p:CGPath,_ width:Double,_ hex:String,_ opacity:Double,_ glow:Double=0) {
    guard opacity>0 else{return}
    c.saveGState();if glow>0 {c.setShadow(offset:.zero,blur:glow,color:color(hex,opacity*0.35))}
    c.setStrokeColor(color(hex,opacity));c.setLineWidth(width);c.setLineCap(.round);c.setLineJoin(.round);c.addPath(p);c.strokePath();c.restoreGState()
}
func render(_ inputTime:Double,_ dark:Bool)->CGImage {
    let t=inputTime>=cfg.duration ? 0:inputTime
    let c=CGContext(data:nil,width:outWidth,height:outHeight,bitsPerComponent:8,bytesPerRow:outWidth*4,space:space,bitmapInfo:format)!
    c.interpolationQuality = .high; c.setShouldAntialias(true)
    c.scaleBy(x:scale,y:scale);c.translateBy(x:0,y:Double(layout.height));c.scaleBy(x:1,y:-1)
    if dark {c.setFillColor(color(cfg.background));c.fill(CGRect(x:0,y:0,width:layout.width,height:layout.height))}
    let timing=cfg.timing
    let reset=soft((t-timing.holdEnd)/(timing.resetEnd-timing.holdEnd))
    let forward=soft((t-timing.forwardStart)/(timing.forwardEnd-timing.forwardStart))*(1-reset)
    let support=1-ramp(t,timing.readingsFadeStart,timing.readingsFadeEnd)
    let early=ramp(t,0.12,0.70)*(1-ramp(t,timing.headingFadeStart,timing.headingFadeEnd))
    let final=ramp(t,timing.finalHeadingStart,timing.finalHeadingEnd)*(1-ramp(t,9.2,9.72))
    let h=layout.health
    let healthAlpha=ramp(t,1.4,1.95)*(1-ramp(t,timing.healthFadeStart,timing.healthFadeEnd))
    // Quiet data routes sit behind the authentic phone image.
    for i in 0..<3 {
        let r=cfg.readingData[i], u=(t-r.pulseStart)/0.95
        let reveal=ramp(t,1.65+Double(i)*0.12,2.05+Double(i)*0.12)*support
        if let full=path(routes[i]) {stroke(c,full,variant == "wide" ? 1.8:2.6,r.color,0.24*reveal)}
        if u>=0 && u<=1, let pulse=path(routes[i],max(0,u-0.18),min(1,u)) {
            stroke(c,pulse,variant == "wide" ? 3.4:4.4,r.color,0.90*sin(.pi*clamp(u))*support,16)
        }
        let receive=sin(.pi*clamp((u-0.40)/0.28))
        if u>0.40 && u<0.68 {
            let p=CGMutablePath();p.addEllipse(in:CGRect(x:h.x-49-receive*7,y:h.y-49-receive*7,width:98+receive*14,height:98+receive*14))
            stroke(c,p,1.5,r.color,0.28*receive*healthAlpha,9)
        }
    }
    // The source dashboard is never reconstructed. Only its complete alpha
    // fades slightly as the three real inputs arrive, then holds fully clear.
    let phone=layout.phone
    let ph=mix(phone.height,phone.finalHeight,forward)
    let px=mix(phone.centerX,phone.finalCenterX,forward), py=mix(phone.centerY,phone.finalCenterY,forward)
    let pw=ph*Double(cfg.assets.poseWidth)/Double(cfg.assets.poseHeight)
    let pose=Int((forward*Double(cfg.assets.poseCount-1)).rounded())
    let imagePath=String(format:cfg.assets.posePattern,pose)
    let nativeAlpha=mix(0.78,1,ramp(t,1.9,4.8))*(1-reset)+0.78*reset
    drawImage(c,image(imagePath),CGRect(x:px-pw/2,y:py-ph/2,width:pw,height:ph),nativeAlpha)
    drawImage(c,image(cfg.assets.health),CGRect(x:h.x-h.size/2,y:h.y-h.size/2,width:h.size,height:h.size),healthAlpha)
    centeredText(c,"Apple Health",h.x,h.y+h.size/2+29,h.captionSize,cfg.colors["muted"]!,healthAlpha)
    text(c,"Count.kcal",layout.brand.x,layout.brand.y,layout.brand.size,.medium,cfg.colors["muted"]!)
    let e=layout.earlyHeading, f=layout.finalHeading
    text(c,"Your day,",e.x,e.firstBaseline,e.size,.medium,cfg.colors["white"]!,early,-2)
    text(c,"brought together.",e.x,e.secondBaseline,e.size,.medium,cfg.colors["white"]!,early,-2)
    text(c,"Your day.",f.x,f.firstBaseline,f.size,.medium,cfg.colors["white"]!,final,-2)
    text(c,"One clear picture.",f.x,f.secondBaseline,f.size,.medium,cfg.colors["white"]!,final,-2)
    for i in 0..<3 {
        let r=cfg.readingData[i], p=layout.readings[i]
        let enter=ramp(t,0.22+Double(i)*0.40,0.82+Double(i)*0.40)
        let alpha=enter*support, lift=12*(1-enter)
        text(c,r.name,p.x,p.labelY+lift,layout.labelSize,.regular,cfg.colors["muted"]!,alpha)
        text(c,r.value,p.x,p.valueY+lift,layout.valueSize,.medium,r.color,alpha,-1)
        text(c,r.unit,p.unitX,p.unitY+lift,layout.unitSize,.regular,cfg.colors["muted"]!,alpha)
    }
    return c.makeImage()!
}
func png(_ img:CGImage,_ p:String) {
    let dest=CGImageDestinationCreateWithURL(URL(fileURLWithPath:p) as CFURL,UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(dest,img,nil);precondition(CGImageDestinationFinalize(dest))
}
if mode == "poster" || mode == "poster-dark" {
    png(render(Double(CommandLine.arguments[6])!,mode == "poster-dark"),output)
} else {
    let stdout=FileHandle.standardOutput
    for i in 0..<Int(cfg.duration*Double(cfg.fps)) {
        autoreleasepool {
            let img=render(Double(i)/Double(cfg.fps),false)
            let ctx=CGContext(data:nil,width:outWidth,height:outHeight,bitsPerComponent:8,bytesPerRow:outWidth*4,space:space,bitmapInfo:format)!
            ctx.draw(img,in:CGRect(x:0,y:0,width:outWidth,height:outHeight))
            let ptr=ctx.data!.assumingMemoryBound(to:UInt8.self)
            for k in stride(from:0,to:outWidth*outHeight*4,by:4) {
                let a=Int(ptr[k+3]);if a>0 && a<255 {for j in 0..<3 {ptr[k+j]=UInt8(min(255,(Int(ptr[k+j])*255+a/2)/a))}}
            }
            stdout.write(Data(bytes:ptr,count:outWidth*outHeight*4))
        }
        if i%60 == 0 {FileHandle.standardError.write(Data("Rendered \(variant) \(i)/300 frames\n".utf8))}
    }
}
