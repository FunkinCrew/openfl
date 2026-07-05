package openfl.display3D.backends.bgfx.textures;

import haxe.Int64;
#if bgfx
import lime.graphics.bgfx.BGFXTexture;
import lime.graphics.bgfx.BGFXTextureFormat;
import lime.graphics.bgfx.BGFXFrameBuffer;
import openfl.display3D._internal.GLFramebuffer;
import openfl.display3D._internal.GLRenderbuffer;
import openfl.display3D._internal.GLTexture;
import openfl.display3D._internal.ATFGPUFormat;
import openfl.display._internal.SamplerState;
import openfl.display.BitmapData;
import openfl.events.EventDispatcher;
import openfl.errors.Error;
import openfl.utils._internal.Log;
#if lime
import lime._internal.graphics.ImageCanvasUtil;
import lime.graphics.Image;
import lime.graphics.RenderContext;
#end

/**
	The TextureBase class is the base class for Context3D texture objects.

	**Note:** You cannot create your own texture classes using TextureBase. To add
	functionality to a texture class, extend either Texture or CubeTexture instead.
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(openfl.display._internal.SamplerState)
@:access(openfl.display3D.backends.bgfx.Context3D)
@:access(openfl.display.BitmapData)
@:access(openfl.display.Stage)
class TextureBase extends EventDispatcher
{
	@:noCompletion private static var __compressedFormats:Map<Int, BGFXTextureFormat>;
	@:noCompletion private static var __compressedFormatsAlpha:Map<Int, BGFXTextureFormat>;
	@:noCompletion private static var __supportsBGRA:Null<Bool> = null;
	@:noCompletion private static var __textureFormat:BGFXTextureFormat;
	@:noCompletion private static var __textureInternalFormat:BGFXTextureFormat;

	@:noCompletion private var __alphaTexture:TextureBase;
	// private var __compressedMemoryUsage:Int;
	@:noCompletion private var __context:Context3D;
	@:noCompletion private var __format:Int;
	@:noCompletion private var __framebuffer:BGFXFrameBuffer;
	@:noCompletion private var __height:Int;
	@:noCompletion private var __internalFormat:Int;
	private var __memoryUsage:Int;
	@:noCompletion private var __optimizeForRenderToTexture:Bool;
	// private var __outputTextureMemoryUsage:Bool = false;
	@:noCompletion private var __premultiplyAlpha:Bool;
	@:noCompletion private var __samplerState:SamplerState;
	@:noCompletion private var __streamingLevels:Int;
	@SuppressWarnings("checkstyle:Dynamic")
	@:noCompletion private var __textureContext:#if lime RenderContext #else Dynamic #end;
	@:noCompletion private var __textureID:BGFXTexture;
	@:noCompletion private var __width:Int;
	@:noCompletion private var __samplerStateFlags:Int;

	@:noCompletion private function new(context:Context3D)
	{
		super();

		__context = context;
		var bgfx = __context.bgfx;

		if (__supportsBGRA == null)
		{
			__textureInternalFormat = BGFXTextureFormat.BGRA8;

			var bgraExtension:Dynamic = null;
			var bgraFormat = bgfx.getCaps().formats[BGFXTextureFormat.BGRA8];
			if (bgraFormat & bgfx.CAPS_FORMAT_TEXTURE_2D != 0)
			{
				__supportsBGRA = true;
				__textureFormat = BGFXTextureFormat.BGRA8;
			}
			else
			{
				__supportsBGRA = false;
				__textureFormat = BGFXTextureFormat.RGBA8;
			}

			// actually junk but keeepin it to avoid null object reference :/
			__compressedFormats = new Map();
			__compressedFormatsAlpha = new Map();
		}

		__internalFormat = __textureInternalFormat;
		__format = __textureFormat;

		// __memoryUsage = 0;
		// __compressedMemoryUsage = 0;
	}

	/**
		Frees all GPU resources associated with this texture. After disposal, calling
		`upload()` or rendering with this object fails.
	**/
	public function dispose():Void
	{
		var gl = __context.gl;
		var bgfx = __context.bgfx;

		if (__framebuffer != null)
		{
			bgfx.destroyFrameBuffer(__framebuffer);
			__framebuffer = null;
		}
		else
		{
			bgfx.destroyTexture(__textureID);
			__textureID = null;
		}
	}

	@SuppressWarnings("checkstyle:Dynamic")
	@:noCompletion private function __getFramebuffer(enableDepthAndStencil:Bool, antiAlias:Int, surfaceSelector:Int):GLFramebuffer
	{
		var bgfx = __context.bgfx;

		if (__framebuffer == null)
		{
			if (__textureID == null) __textureID = bgfx.createTexture2D(__width, __height, false, 1, __internalFormat, bgfx.TEXTURE_RT);

			var textures = [__textureID];
			if (enableDepthAndStencil) textures.push(bgfx.createTexture2D(__width, __height, false, 1, __context.__getSupportedDepth(),
				bgfx.TEXTURE_RT_WRITE_ONLY));

			__framebuffer = bgfx.createFrameBufferFromTextures(textures, true);
		}

		return __framebuffer;
	}

	#if lime
	@:noCompletion private function __getImage(bitmapData:BitmapData):Image
	{
		var image = bitmapData.image;

		if (!bitmapData.__isValid || image == null)
		{
			return null;
		}

		if (#if openfl_power_of_two !image.powerOfTwo || #end (!image.premultiplied && image.transparent))
		{
			image = image.clone();
			image.premultiplied = true;
			#if openfl_power_of_two
			image.powerOfTwo = true;
			#end
		}

		return image;
	}
	#end

	@:noCompletion private function __getTexture():BGFXTexture
	{
		return __textureID;
	}

	@:noCompletion private function __setSamplerState(state:SamplerState):Bool
	{
		if (!state.equals(__samplerState))
		{
			var bgfx = __context.bgfx;
			__samplerStateFlags = 0;

			switch (state.wrap)
			{
				case CLAMP:
					__samplerStateFlags |= bgfx.SAMPLER_U_CLAMP | bgfx.SAMPLER_V_CLAMP;
				case CLAMP_U_REPEAT_V:
					__samplerStateFlags |= bgfx.SAMPLER_U_CLAMP;
				case REPEAT: // nothing
				case REPEAT_U_CLAMP_V:
					__samplerStateFlags |= bgfx.SAMPLER_V_CLAMP;
			}

			if (state.filter == NEAREST) __samplerStateFlags |= bgfx.SAMPLER_MAG_POINT | bgfx.SAMPLER_MIN_POINT;

			switch (state.mipfilter)
			{
				case MIPNEAREST:
					__samplerStateFlags |= bgfx.SAMPLER_MIP_POINT;
				case MIPLINEAR, MIPNONE: // nothin
			}

			if (__samplerState == null) __samplerState = state.clone();
			__samplerState.copyFrom(state);

			return true;
		}

		return false;
	}

	#if lime
	@:noCompletion private function __uploadFromImage(image:Image):Void
	{
		var bgfx = __context.bgfx;
		var format:Int;

		// TODO: find an alternative for this?
		if (this is openfl.display3D.textures.CubeTexture) return;

		if (image.buffer.bitsPerPixel == 1) format = BGFXTextureFormat.R8;
		else
			format = TextureBase.__textureFormat;

		var hasMips = __samplerState != null && __samplerState.mipfilter != MIPNONE;
		var flags:Int64 = Int64.make(0, 0);
		if (__optimizeForRenderToTexture) flags |= bgfx.TEXTURE_RT;

		__textureID = bgfx.createTexture2D(image.buffer.width, image.buffer.height, hasMips, 1, format, flags, bgfx.copy(image.buffer.data));

		// not wrong actally i think?
		__memoryUsage = image.buffer.width * image.buffer.height * image.buffer.bitsPerPixel;
	}
	#end
}
#end
