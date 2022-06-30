import PlaygroundSupport
import MetalKit

//获取默认设备（guard类似于if not，如果device是空，则执行）
guard let device = MTLCreateSystemDefaultDevice() else{
    fatalError("GPU is not support")
}

//初始化窗口尺寸、清屏颜色
let frame = CGRect(x: 0, y: 0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device)
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)

//模型IO
//管理模型数据
let allocator = MTKMeshBufferAllocator(device: device)
//创建一个sphere
let mdlMesh = MDLMesh(sphereWithExtent: [0.75, 0.75, 0.75], segments: [100, 100], inwardNormals: false, geometryType: .triangles, allocator: allocator)
//将输入（这里是创建的）mesh转化为MetalKit mesh
let mesh = try MTKMesh(mesh: mdlMesh, device: device)

//创建命令队列
guard let commandQueue = device.makeCommandQueue() else{
    fatalError("Could not create a command queue")
}

//shader代码（一般是另起一个文件）
let shader = """
#include <metal_stdlib>
using namespace metal;

struct VSInput{
    float4 position [[attribute(0)]];   //[[xxx]]类似于SV_Target
};

vertex float4 vertex_main(const VSInput v[[stage_in]]){
    return v.position;
}

fragment float4 fragment_main(){
    return float4(0,1,0,1);
}
"""

//创建shader library
let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunc = library.makeFunction(name: "vertex_main")
let fragmentFunc = library.makeFunction(name: "fragmnet_main")

//创建pipeline state descriptor
let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
renderPipelineDescriptor.vertexFunction = vertexFunc
renderPipelineDescriptor.fragmentFunction = fragmentFunc
renderPipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

//创建pipeline state
let pipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

//创建命令缓冲区
guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderPassDescriptor = view.currentRenderPassDescriptor,
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
else{fatalError()}

renderEncoder.setRenderPipelineState(pipelineState)
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)    //这里的sphere只有一个submesh

//submesh
guard let submesh = mesh.submeshes.first else{
    fatalError()
}

//draw call
renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)

//提交渲染命令
renderEncoder.endEncoding()
guard let drawable = view.currentDrawable else{
    fatalError()
}
commandBuffer.present(drawable)
commandBuffer.commit()

//展示
PlaygroundPage.current.liveView = view

