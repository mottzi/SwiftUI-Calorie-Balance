import Foundation
import AppKit
import SceneKit
import Metal
import ImageIO
import UniformTypeIdentifiers

struct MaterialInfo:Decodable { let name:String; let color:[Double]; let metalness:Double; let roughness:Double; let alphaMode:String; let texture:String? }
struct MeshInfo:Decodable { let name:String; let vertices:String; let indices:String; let vertexCount:Int; let indexCount:Int; let material:Int }
struct SceneInfo:Decodable { let meshes:[MeshInfo]; let materials:[MaterialInfo] }
let scenePath=URL(fileURLWithPath:CommandLine.arguments[1])
let directory=scenePath.deletingLastPathComponent()
let nativePath=CommandLine.arguments[2]
let output=CommandLine.arguments[3]
let yaw=Double(CommandLine.arguments[4])! * .pi/180
let width=Int(CommandLine.arguments[5])!
let height=width*2
let info=try JSONDecoder().decode(SceneInfo.self,from:Data(contentsOf:scenePath))
let scene=SCNScene()
scene.background.contents=NSColor.clear
scene.lightingEnvironment.contents=NSImage(contentsOf:directory.appendingPathComponent("studio-environment.png"))!
scene.lightingEnvironment.intensity=0.8
let root=SCNNode()
scene.rootNode.addChildNode(root)
let native=NSImage(contentsOfFile:nativePath)!
var materials=[SCNMaterial]()
for item in info.materials {
    let m=SCNMaterial();m.name=item.name;m.lightingModel = .physicallyBased
    m.diffuse.contents=NSColor(srgbRed:item.color[0],green:item.color[1],blue:item.color[2],alpha:1)
    m.metalness.contents=item.metalness;m.roughness.contents=item.roughness
    m.isDoubleSided=true
    if let path=item.texture {m.diffuse.contents=NSImage(contentsOf:directory.appendingPathComponent(path))!}
    if item.alphaMode == "BLEND" {m.transparency=item.color[3];m.writesToDepthBuffer=false}
    if item.name == "OLED" {
        m.lightingModel = .constant;m.diffuse.contents=native;m.emission.contents=NSColor.black
        m.metalness.contents=0;m.roughness.contents=1
        m.diffuse.wrapS = .clamp;m.diffuse.wrapT = .clamp;m.diffuse.mipFilter = .linear
    }
    if item.name == "OLED_off" || item.name == "Display_Frame" {
        m.lightingModel = .constant;m.diffuse.contents=NSColor(srgbRed:0.003,green:0.003,blue:0.004,alpha:1)
        m.metalness.contents=0;m.roughness.contents=1
    }
    if item.name == "Glass" {
        m.diffuse.contents=NSColor.black;m.transparency=0.0;m.writesToDepthBuffer=false;m.roughness.contents=1;m.metalness.contents=0
    }
    materials.append(m)
}
for mesh in info.meshes {
    let data=try Data(contentsOf:directory.appendingPathComponent(mesh.vertices))
    let pos=SCNGeometrySource(data:data,semantic:.vertex,vectorCount:mesh.vertexCount,usesFloatComponents:true,componentsPerVector:3,bytesPerComponent:4,dataOffset:0,dataStride:32)
    let normal=SCNGeometrySource(data:data,semantic:.normal,vectorCount:mesh.vertexCount,usesFloatComponents:true,componentsPerVector:3,bytesPerComponent:4,dataOffset:12,dataStride:32)
    let uv=SCNGeometrySource(data:data,semantic:.texcoord,vectorCount:mesh.vertexCount,usesFloatComponents:true,componentsPerVector:2,bytesPerComponent:4,dataOffset:24,dataStride:32)
    let indices=try Data(contentsOf:directory.appendingPathComponent(mesh.indices))
    let element=SCNGeometryElement(data:indices,primitiveType:.triangles,primitiveCount:mesh.indexCount/3,bytesPerIndex:4)
    let geometry=SCNGeometry(sources:[pos,normal,uv],elements:[element]);geometry.materials=[materials[mesh.material]]
    let node=SCNNode(geometry:geometry);node.name=mesh.name;root.addChildNode(node)
}
root.eulerAngles=SCNVector3(0.025,yaw,-0.01)
func light(_ type:SCNLight.LightType,_ intensity:CGFloat,_ position:SCNVector3,_ temperature:CGFloat=6500) {
    let node=SCNNode();let l=SCNLight();l.type=type;l.intensity=intensity;l.temperature=temperature;l.color=NSColor.white
    node.light=l;node.position=position;node.look(at:SCNVector3Zero);scene.rootNode.addChildNode(node)
}
light(.ambient,210,SCNVector3Zero)
light(.directional,850,SCNVector3(-3,4,5))
light(.directional,450,SCNVector3(4,0,3))
light(.directional,700,SCNVector3(-4,-1,-3),7200)
let cameraNode=SCNNode();let camera=SCNCamera();camera.fieldOfView=28;camera.projectionDirection = .vertical;camera.zNear=0.01;camera.zFar=100;camera.wantsHDR=false;camera.wantsExposureAdaptation=false
cameraNode.camera=camera;cameraNode.position=SCNVector3(0,0,6.75);scene.rootNode.addChildNode(cameraNode)
let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
renderer.scene=scene;renderer.pointOfView=cameraNode;renderer.autoenablesDefaultLighting=false
let image=renderer.snapshot(atTime:0,with:CGSize(width:width,height:height),antialiasingMode:.multisampling4X)
var rect=CGRect(x:0,y:0,width:width,height:height)
let cg=image.cgImage(forProposedRect:&rect,context:nil,hints:nil)!
let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:output) as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(destination,cg,nil);precondition(CGImageDestinationFinalize(destination))
print("Rendered genuine mesh at yaw \(yaw*180 / .pi) degrees: \(output)")
