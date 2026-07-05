package openfl.display3D;

import openfl.display.BitmapData;
import openfl.display.Shader;
import openfl.display.Stage3D;
import openfl.display3D.textures.ASTCTexture;
import openfl.display3D.textures.CubeTexture;
import openfl.display3D.textures.RectangleTexture;
import openfl.display3D.textures.Texture;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.textures.VideoTexture;
import openfl.geom.Matrix3D;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import openfl.utils.ByteArray;
import openfl.Vector;
#if lime
import lime.graphics.WebGLRenderContext;
import lime.graphics.BGFXRenderContext;
#end

interface IContext3D
{
	public var gl:#if lime WebGLRenderContext #else Dynamic #end;
	public var bgfx:#if lime BGFXRenderContext #else Dynamic #end;
	public var totalGPUMemory(get, never):Float;

	private var __glDepthStencilFormat(get, never):Int;
	private var __bgfxDepthFormat(get, never):Int;
	private var __maxTextureMaxAnisotropy:Int;
	private var __textureMaxAnisotropy:Int;

	private var __frontBufferTexture:RectangleTexture;

	public function configureBackBuffer(width:Int, height:Int, antiAlias:Int, enableDepthAndStencil:Bool = true, wantsBestResolution:Bool = false,
		wantsBestResolutionOnBrowserZoom:Bool = false):Void;
	public function clear(red:Float = 0, green:Float = 0, blue:Float = 0, alpha:Float = 1, depth:Float = 1, stencil:UInt = 0,
		mask:UInt = Context3DClearMask.ALL):Void;
	public function present():Void;
	public function dispose(recreate:Bool = true):Void;
	public function drawTriangles(indexBuffer:IndexBuffer3D, firstIndex:Int = 0, numTriangles:Int = -1):Void;
	public function drawToBitmapData(destination:BitmapData, srcRect:Rectangle = null, destPoint:Point = null):Void;

	public function createProgram(format:Context3DProgramFormat = AGAL):Program3D;
	public function createVertexBuffer(numVertices:Int, data32PerVertex:Int, bufferUsage:Context3DBufferUsage = STATIC_DRAW):VertexBuffer3D;
	public function createIndexBuffer(numIndices:Int, bufferUsage:Context3DBufferUsage = STATIC_DRAW):IndexBuffer3D;
	public function createTexture(width:Int, height:Int, format:Context3DTextureFormat, optimizeForRenderToTexture:Bool, streamingLevels:Int = 0):Texture;
	public function createRectangleTexture(width:Int, height:Int, format:Context3DTextureFormat, optimizeForRenderToTexture:Bool):RectangleTexture;
	public function createCubeTexture(size:Int, format:Context3DTextureFormat, optimizeForRenderToTexture:Bool, streamingLevels:Int = 0):CubeTexture;
	public function createVideoTexture():VideoTexture;
	public function createASTCTexture(data:ByteArray):ASTCTexture;
	public function isASTCSupported():Bool;

	public function setProgram(program:Program3D):Void;
	public function setProgramConstantsFromByteArray(programType:Context3DProgramType, firstRegister:Int, numRegisters:Int, data:ByteArray,
		byteArrayOffset:UInt):Void;
	public function setProgramConstantsFromMatrix(programType:Context3DProgramType, firstRegister:Int, matrix:Matrix3D, transposedMatrix:Bool = false):Void;
	public function setProgramConstantsFromVector(programType:Context3DProgramType, firstRegister:Int, data:Vector<Float>, numRegisters:Int = -1):Void;
	public function setProgramConstantsFromArray(programType:Context3DProgramType, firstRegister:Int, data:Array<Float>, numRegisters:Int = -1):Void;
	public function setVertexBufferAt(index:Int, buffer:VertexBuffer3D, bufferOffset:Int = 0, format:Context3DVertexBufferFormat = FLOAT_4):Void;
	public function setTextureAt(sampler:Int, texture:TextureBase):Void;
	public function setSamplerStateAt(sampler:Int, wrap:Context3DWrapMode, filter:Context3DTextureFilter, mipfilter:Context3DMipFilter):Void;

	public function setRenderToTexture(texture:TextureBase, enableDepthAndStencil:Bool = false, antiAlias:Int = 0, surfaceSelector:Int = 0):Void;
	public function setRenderToBackBuffer():Void;

	public function setBlendFactors(sourceFactor:Context3DBlendFactor, destinationFactor:Context3DBlendFactor):Void;
	private function setBlendFactorsSeparate(sourceRGBFactor:Context3DBlendFactor, destinationRGBFactor:Context3DBlendFactor,
		sourceAlphaFactor:Context3DBlendFactor, destinationAlphaFactor:Context3DBlendFactor):Void;
	public function setColorMask(red:Bool, green:Bool, blue:Bool, alpha:Bool):Void;
	public function setCulling(triangleFaceToCull:Context3DTriangleFace):Void;
	public function setDepthTest(depthMask:Bool, passCompareMode:Context3DCompareMode):Void;
	public function setScissorRectangle(rectangle:Rectangle):Void;
	public function setStencilActions(triangleFace:Context3DTriangleFace = FRONT_AND_BACK, compareMode:Context3DCompareMode = ALWAYS,
		actionOnBothPass:Context3DStencilAction = KEEP, actionOnDepthFail:Context3DStencilAction = KEEP,
		actionOnDepthPassStencilFail:Context3DStencilAction = KEEP):Void;
	public function setStencilReferenceValue(referenceValue:UInt, readMask:UInt = 0xFF, writeMask:UInt = 0xFF):Void;

	private function __clear(useScissor:Bool, red:Float = 0, green:Float = 0, blue:Float = 0, alpha:Float = 1, depth:Float = 1, stencil:UInt = 0,
		mask:UInt = Context3DClearMask.ALL):Void;
	private function __flush():Void;
	private function __flushProgram():Void;
	private function __flushTextures():Void;
	private function __drawTriangles(firstIndex:Int = 0, count:Int):Void;
	private function __renderStage3D(stage3D:Stage3D):Void;
	private function __dispose():Void;
	private function __setGLBlend(enable:Bool):Void;
	private function __setGLBlendEquation(value:Int):Void;
	private function __setGLScissorTest(enable:Bool):Void;
	private function __bindGLTexture2D(texture:Dynamic):Void;
	private function __bindGLTextureCubeMap(texture:Dynamic):Void;
	private function __bindGLArrayBuffer(buffer:Dynamic):Void;
	private function __bindGLElementArrayBuffer(buffer:Dynamic):Void;
	private function __bindGLFramebuffer(framebuffer:Dynamic):Void;
}
