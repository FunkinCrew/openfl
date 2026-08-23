package openfl.display3D._internal;

import lime.graphics.opengl.GL;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLFramebuffer;
import lime.graphics.opengl.GLRenderbuffer;
import lime.graphics.opengl.GLTexture;
import openfl.display.Shader;
import openfl.display._internal.SamplerState;
import openfl.display3D.Context3DBlendFactor;
import openfl.display3D.Context3DCompareMode;
import openfl.display3D.Context3DStencilAction;
import openfl.display3D.Context3DTriangleFace;
import openfl.display3D.Program3D;
import openfl.display3D.textures.TextureBase;
import openfl.geom.Rectangle;

@SuppressWarnings("checkstyle:FieldDocComment")
class Context3DState
{
	public var backBufferEnableDepthAndStencil:Bool;
	public var blendDestinationAlphaFactor:Context3DBlendFactor;
	public var blendSourceAlphaFactor:Context3DBlendFactor;
	public var blendDestinationRGBFactor:Context3DBlendFactor;
	public var blendSourceRGBFactor:Context3DBlendFactor;
	public var colorMaskRed:Bool;
	public var colorMaskGreen:Bool;
	public var colorMaskBlue:Bool;
	public var colorMaskAlpha:Bool;
	public var culling:Context3DTriangleFace;
	public var depthCompareMode:Context3DCompareMode;
	public var depthMask:Bool;
	// public var fillMode:Context3DFillMode;
	public var program:Program3D;
	// program constants?
	public var renderToTexture:TextureBase;
	public var renderToTextureAntiAlias:Int;
	public var renderToTextureDepthStencil:Bool;
	public var renderToTextureSurfaceSelector:Int;
	public var samplerStates:Array<SamplerState>;
	public var scissorEnabled:Bool;
	public var scissorRectangle:Rectangle;
	public var stencilCompareMode:Context3DCompareMode;
	public var stencilDepthFail:Context3DStencilAction;
	public var stencilFail:Context3DStencilAction;
	public var stencilPass:Context3DStencilAction;
	public var stencilReadMask:UInt;
	public var stencilReferenceValue:UInt;
	public var stencilTriangleFace:Context3DTriangleFace;
	public var stencilWriteMask:UInt;
	public var textures:Array<TextureBase>;
	// vertex buffer at?
	public var shader:Shader; // TODO: Merge shader/program3d

	@:noCompletion private var __currentGLArrayBuffer:GLBuffer;
	@:noCompletion private var __currentGLElementArrayBuffer:GLBuffer;
	@:noCompletion private var __currentGLFramebuffer:GLFramebuffer;
	@:noCompletion private var __currentGLTexture2D:GLTexture;
	@:noCompletion private var __currentGLTextureCubeMap:GLTexture;
	@:noCompletion private var __enableGLBlend:Bool;
	@:noCompletion private var __enableGLCullFace:Bool;
	@:noCompletion private var __enableGLDepthTest:Bool;
	@:noCompletion private var __enableGLScissorTest:Bool;
	@:noCompletion private var __enableGLStencilTest:Bool;
	@:noCompletion private var __frontFaceGLCCW:Bool;
	@:noCompletion private var __glBlendEquation:Int;
	@:noCompletion private var __primaryGLFramebuffer:GLFramebuffer;
	@:noCompletion private var __rttDepthGLRenderbuffer:GLRenderbuffer;
	@:noCompletion private var __rttGLFramebuffer:GLFramebuffer;
	@:noCompletion private var __rttGLRenderbuffer:GLRenderbuffer;
	@:noCompletion private var __rttStencilGLRenderbuffer:GLRenderbuffer;

	public function new()
	{
		backBufferEnableDepthAndStencil = false;
		blendDestinationAlphaFactor = ZERO;
		blendSourceAlphaFactor = ONE;
		blendDestinationRGBFactor = ZERO;
		blendSourceRGBFactor = ONE;
		colorMaskRed = true;
		colorMaskGreen = true;
		colorMaskBlue = true;
		colorMaskAlpha = true;
		culling = NONE;
		depthCompareMode = LESS;
		depthMask = true;
		samplerStates = new Array();
		scissorRectangle = new Rectangle();
		stencilCompareMode = ALWAYS;
		stencilDepthFail = KEEP;
		stencilFail = KEEP;
		stencilPass = KEEP;
		stencilReadMask = 0xFF;
		stencilReferenceValue = 0;
		stencilTriangleFace = FRONT_AND_BACK;
		stencilWriteMask = 0xFF;
		textures = new Array();
		__frontFaceGLCCW = true;
		__glBlendEquation = GL.FUNC_ADD;
	}
}
