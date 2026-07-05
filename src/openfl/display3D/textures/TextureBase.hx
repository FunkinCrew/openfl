package openfl.display3D.textures;

import lime.graphics.bgfx.BGFXTexture;
import haxe.Int64;
import openfl.display3D._internal.GLFramebuffer;
import openfl.display3D._internal.GLRenderbuffer;
import openfl.display._internal.SamplerState;
import openfl.display.BitmapData;
import openfl.events.EventDispatcher;
import openfl.errors.Error;
import openfl.utils._internal.ArrayBufferView;
import openfl.utils._internal.Log;
#if lime
import lime._internal.graphics.ImageCanvasUtil;
import lime.graphics.Image;
import lime.graphics.RenderContext;
import lime.graphics.bgfx.BGFXTextureFormat;
#end

/**
	The TextureBase class is the base class for Context3D texture objects.

	**Note:** You cannot create your own texture classes using TextureBase. To add
	functionality to a texture class, extend either Texture or CubeTexture instead.
**/
@:access(openfl.display._internal.SamplerState)
@:access(openfl.display3D.Context3D)
@:access(openfl.display.BitmapData)
@:access(openfl.display.Stage)
class TextureBase extends EventDispatcher
{
	@:noCompletion private static var __supportsBGRA:Null<Bool> = null;
	@:noCompletion private static var __textureFormat:Int;
	@:noCompletion private static var __textureInternalFormat:Int;

	@:noCompletion private var __context:Context3D;
	@:noCompletion private var __glDepthRenderbuffer:GLRenderbuffer;
	@SuppressWarnings("checkstyle:Dynamic") @:noCompletion private var __framebuffer:Dynamic;
	@:noCompletion private var __glStencilRenderbuffer:GLRenderbuffer;
	@:noCompletion private var __memoryWidth:Int = -1;
	@:noCompletion private var __memoryHeight:Int = -1;
	@:noCompletion private var __memoryFormat:Int = -1;
	@:noCompletion private var __memoryInternalFormat:Int = -1;
	@:noCompletion private var __width:Int;
	@:noCompletion private var __height:Int;
	@:noCompletion private var __format:Int;
	@:noCompletion private var __internalFormat:Int;
	@:noCompletion private var __optimizeForRenderToTexture:Bool;
	@:noCompletion private var __premultiplyAlpha:Bool;
	@:noCompletion private var __samplerState:SamplerState;
	@:noCompletion private var __streamingLevels:Int;
	@SuppressWarnings("checkstyle:Dynamic") @:noCompletion private var __textureContext:#if lime RenderContext #else Dynamic #end;
	@SuppressWarnings("checkstyle:Dynamic") @:noCompletion private var __textureID:Dynamic;
	@:noCompletion private var __textureTarget:Int;
	@:noCompletion private var __samplerStateFlags:Int;
	@:noCompletion private var __textureFlags:Int64;

	@:noCompletion private function new(context:Context3D)
	{
		super();

		__context = context;

		if (__context.isBGFX)
		{
			var bgfx = __context.bgfx;

			if (__supportsBGRA == null)
			{
				__textureInternalFormat = BGFXTextureFormat.BGRA8;

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
			}
		}
		else
		{
			var gl = __context.gl;

			__textureID = gl.createTexture();
			__textureContext = __context.__context;

			if (__supportsBGRA == null)
			{
				__textureInternalFormat = gl.RGBA;

				var bgraExtension:Dynamic = null;
				#if (!js || !html5)
				bgraExtension = gl.getExtension("EXT_bgra");
				if (bgraExtension == null) bgraExtension = gl.getExtension("EXT_texture_format_BGRA8888");
				if (bgraExtension == null) bgraExtension = gl.getExtension("APPLE_texture_format_BGRA8888");
				#end

				if (bgraExtension != null)
				{
					__supportsBGRA = true;
					__textureFormat = bgraExtension.BGRA_EXT;
				}

				// Note: Get rid of this when `ANGLE` is added.
				#if (lime && !ios)
				if (context.__context.type == OPENGLES)
				{
					__textureInternalFormat = bgraExtension.BGRA_EXT;
				}
				#end
			}
			else
			{
				__supportsBGRA = false;
				__textureFormat = gl.RGBA;
			}
		}

		__internalFormat = __textureInternalFormat;
		__format = __textureFormat;
	}

	/**
		Frees all GPU resources associated with this texture. After disposal, calling
		`upload()` or rendering with this object fails.
	**/
	public function dispose():Void
	{
		if (__context.isBGFX)
		{
			var bgfx = __context.bgfx;

			if (__framebuffer != null)
			{
				bgfx.destroyFrameBuffer(__framebuffer);
				__framebuffer = null;
				__textureID = null;
			}
			else if (__textureID != null)
			{
				bgfx.destroyTexture(__textureID);
				__textureID = null;
			}
		}
		else
		{
			var gl = __context.gl;

			if (__textureID != null)
			{
				gl.deleteTexture(__textureID);
				__textureID = null;
			}

			if (__framebuffer != null)
			{
				gl.deleteFramebuffer(__framebuffer);
				__framebuffer = null;
			}

			if (__glDepthRenderbuffer != null)
			{
				gl.deleteRenderbuffer(__glDepthRenderbuffer);
				__glDepthRenderbuffer = null;
			}

			if (__glStencilRenderbuffer != null)
			{
				gl.deleteRenderbuffer(__glStencilRenderbuffer);
				__glStencilRenderbuffer = null;
			}
		}
	}

	@SuppressWarnings("checkstyle:Dynamic")
	@:noCompletion private function __getFramebuffer(enableDepthAndStencil:Bool, antiAlias:Int, surfaceSelector:Int):GLFramebuffer
	{
		if (__context.isBGFX)
		{
			var bgfx = __context.bgfx;

			if (__framebuffer == null)
			{
				if (__textureID == null || __textureFlags & bgfx.TEXTURE_RT == 0)
				{
					if (__textureID != null)
					{
						bgfx.destroyTexture(__textureID);
						__textureID = null;
					}

					__textureFlags = bgfx.TEXTURE_RT;

					__textureID = bgfx.createTexture2D(__width, __height, false, 1, __internalFormat, bgfx.TEXTURE_RT, null);
				}

				var textures:Array<BGFXTexture> = [__textureID];
				if (enableDepthAndStencil) textures.push(bgfx.createTexture2D(__width, __height, false, 1, __context.__bgfxDepthFormat,
					bgfx.TEXTURE_RT_WRITE_ONLY));

				__framebuffer = bgfx.createFrameBufferFromTextures(textures, true);
				__textureID = bgfx.getTexture(__framebuffer, 0);
			}

			return __framebuffer;
		}

		var gl = __context.gl;

		if (__framebuffer == null)
		{
			__framebuffer = gl.createFramebuffer();
			__context.__bindGLFramebuffer(__framebuffer);
			gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, __textureID, 0);

			if (__context.enableErrorChecking)
			{
				var code = gl.checkFramebufferStatus(gl.FRAMEBUFFER);

				if (code != gl.FRAMEBUFFER_COMPLETE)
				{
					Log.warn('Error: Context3D.setRenderToTexture status:${code} width:${__width} height:${__height}');
				}
			}
		}

		if (enableDepthAndStencil && __glDepthRenderbuffer == null)
		{
			__context.__bindGLFramebuffer(__framebuffer);

			if (__context.__glDepthStencilFormat != 0)
			{
				__glDepthRenderbuffer = gl.createRenderbuffer();
				__glStencilRenderbuffer = __glDepthRenderbuffer;

				gl.bindRenderbuffer(gl.RENDERBUFFER, __glDepthRenderbuffer);
				gl.renderbufferStorage(gl.RENDERBUFFER, __context.__glDepthStencilFormat, __width, __height);
				gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, __glDepthRenderbuffer);
			}
			else
			{
				__glDepthRenderbuffer = gl.createRenderbuffer();
				__glStencilRenderbuffer = gl.createRenderbuffer();

				gl.bindRenderbuffer(gl.RENDERBUFFER, __glDepthRenderbuffer);
				gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, __width, __height);
				gl.bindRenderbuffer(gl.RENDERBUFFER, __glStencilRenderbuffer);
				gl.renderbufferStorage(gl.RENDERBUFFER, gl.STENCIL_INDEX8, __width, __height);

				gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, __glDepthRenderbuffer);
				gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.STENCIL_ATTACHMENT, gl.RENDERBUFFER, __glStencilRenderbuffer);
			}

			if (__context.enableErrorChecking)
			{
				var code = gl.checkFramebufferStatus(gl.FRAMEBUFFER);

				if (code != gl.FRAMEBUFFER_COMPLETE)
				{
					Log.warn('Error: Context3D.setRenderToTexture status:${code} width:${__width} height:${__height}');
				}
			}

			gl.bindRenderbuffer(gl.RENDERBUFFER, null);
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

		if (__context.isBGFX)
		{
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

		#if (js && html5)
		ImageCanvasUtil.sync(image, false);
		#end

		#if (js && html5)
		var gl = __context.gl;

		if (image.type != DATA && !image.premultiplied)
		{
			gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
		}
		else if (!image.premultiplied && image.transparent)
		{
			gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 0);
			image = image.clone();
			image.premultiplied = true;
		}

		// TODO: Some way to support BGRA on WebGL?

		if (image.format != RGBA32)
		{
			image = image.clone();
			image.format = RGBA32;
			image.buffer.premultiplied = true;
			#if openfl_power_of_two
			image.powerOfTwo = true;
			#end
		}
		#else
		if (#if openfl_power_of_two !image.powerOfTwo || #end (!image.premultiplied && image.transparent))
		{
			image = image.clone();
			image.premultiplied = true;
			#if openfl_power_of_two
			image.powerOfTwo = true;
			#end
		}
		#end

		return image;
	}
	#end

	@SuppressWarnings("checkstyle:Dynamic")
	@:noCompletion private function __getTexture():Dynamic
	{
		return __textureID;
	}

	@:noCompletion private function __setSamplerState(state:SamplerState):Bool
	{
		if (!state.equals(__samplerState))
		{
			if (__context.isBGFX)
			{
				var bgfx = __context.bgfx;
				__samplerStateFlags = 0;

				switch (state.wrap)
				{
					case CLAMP:
						__samplerStateFlags |= bgfx.SAMPLER_U_CLAMP | bgfx.SAMPLER_V_CLAMP;
					case CLAMP_U_REPEAT_V:
						__samplerStateFlags |= bgfx.SAMPLER_U_CLAMP;
					case REPEAT_U_CLAMP_V:
						__samplerStateFlags |= bgfx.SAMPLER_V_CLAMP;
					case REPEAT: // nothing
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
			else if (__context.isOpenGL)
			{
				var gl = __context.gl;

				if (__textureTarget == __context.gl.TEXTURE_CUBE_MAP) __context.__bindGLTextureCubeMap(__textureID);
				else
					__context.__bindGLTexture2D(__textureID);

				var wrapModeS = 0, wrapModeT = 0;

				switch (state.wrap)
				{
					case CLAMP:
						wrapModeS = gl.CLAMP_TO_EDGE;
						wrapModeT = gl.CLAMP_TO_EDGE;
					case CLAMP_U_REPEAT_V:
						wrapModeS = gl.CLAMP_TO_EDGE;
						wrapModeT = gl.REPEAT;
					case REPEAT:
						wrapModeS = gl.REPEAT;
						wrapModeT = gl.REPEAT;
					case REPEAT_U_CLAMP_V:
						wrapModeS = gl.REPEAT;
						wrapModeT = gl.CLAMP_TO_EDGE;
					default:
						throw new Error("wrap bad enum");
				}

				var magFilter = 0, minFilter = 0;

				switch (state.filter)
				{
					case NEAREST:
						magFilter = gl.NEAREST;
					default:
						magFilter = gl.LINEAR;
				}

				switch (state.mipfilter)
				{
					case MIPLINEAR:
						minFilter = state.filter == NEAREST ? gl.NEAREST_MIPMAP_LINEAR : gl.LINEAR_MIPMAP_LINEAR;
					case MIPNEAREST:
						minFilter = state.filter == NEAREST ? gl.NEAREST_MIPMAP_NEAREST : gl.LINEAR_MIPMAP_NEAREST;
					case MIPNONE:
						minFilter = state.filter == NEAREST ? gl.NEAREST : gl.LINEAR;
					default:
						throw new Error("mipfiter bad enum");
				}

				gl.texParameteri(__textureTarget, gl.TEXTURE_MIN_FILTER, minFilter);
				gl.texParameteri(__textureTarget, gl.TEXTURE_MAG_FILTER, magFilter);
				gl.texParameteri(__textureTarget, gl.TEXTURE_WRAP_S, wrapModeS);
				gl.texParameteri(__textureTarget, gl.TEXTURE_WRAP_T, wrapModeT);

				if (__samplerState == null)
				{
					__samplerState = state.clone();
				}

				__samplerState.copyFrom(state);

				return true;
			}
		}

		return false;
	}

	#if lime
	@:noCompletion private function __uploadFromImage(image:Image):Void
	{
		if (__context.isBGFX)
		{
			var bgfx = __context.bgfx;
			var format:Int;

			// TODO: find an alternative for this?
			if (this is openfl.display3D.textures.CubeTexture) return;

			if (image.buffer.bitsPerPixel == 1) format = BGFXTextureFormat.R8;
			else
				format = TextureBase.__textureFormat;

			var flags:Int64 = Int64.make(0, 0);
			if (__optimizeForRenderToTexture)
			{
				flags |= bgfx.TEXTURE_RT;
			}

			if (__textureID != null && flags != __textureFlags)
			{
				bgfx.destroyTexture(__textureID);
				__textureID = null;
			}

			__textureFlags = flags;
			__uploadTexture2D(0, image.buffer.width, image.buffer.height, format, format, image.buffer.data);
		}
		else if (__context.isOpenGL)
		{
			var gl = __context.gl;

			if (__textureTarget != gl.TEXTURE_2D)
			{
				return;
			}

			var internalFormat:Int;
			var format:Int;

			if (image.buffer.bitsPerPixel == 1)
			{
				internalFormat = gl.ALPHA;
				format = gl.ALPHA;
			}
			else
			{
				internalFormat = TextureBase.__textureInternalFormat;
				format = TextureBase.__textureFormat;
			}

			__context.__bindGLTexture2D(__textureID);

			#if (js && html5)
			if (image.type != DATA && !image.premultiplied)
			{
				gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
			}
			else if (!image.premultiplied && image.transparent)
			{
				gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
			}

			if (image.type == DATA)
			{
				__uploadTexture2D(__textureTarget, image.buffer.width, image.buffer.height, internalFormat, format, image.data);
			}
			else
			{
				gl.texImage2D(__textureTarget, 0, internalFormat, format, gl.UNSIGNED_BYTE, image.src);
			}
			#else
			__uploadTexture2D(__textureTarget, image.buffer.width, image.buffer.height, internalFormat, format, image.data);
			#end

			__context.__bindGLTexture2D(null);
		}
	}
	#end

	@:noCompletion private function __uploadTexture2D(target:Int, width:Int, height:Int, internalFormat:Int, format:Int, data:ArrayBufferView):Void
	{
		if (__context.isBGFX)
		{
			var bgfx = __context.bgfx;

			if (__memoryWidth == width
				&& __memoryHeight == height
				&& __memoryFormat == format
				&& __memoryInternalFormat == internalFormat
				&& __textureID != null)
			{
				bgfx.updateTexture2D(__textureID, 0, 0, 0, 0, width, height, bgfx.copy(data));
			}
			else
			{
				__textureID = bgfx.createTexture2D(width, height, false, 1, format, __textureFlags, data == null ? null : bgfx.copy(data));

				__memoryWidth = width;
				__memoryHeight = height;
				__memoryFormat = format;
				__memoryInternalFormat = internalFormat;
			}
		}
		else if (__context.isOpenGL)
		{
			var gl = __context.gl;

			if (__memoryWidth == width
				&& __memoryHeight == height
				&& __memoryFormat == format
				&& __memoryInternalFormat == internalFormat)
			{
				gl.texSubImage2D(target, 0, 0, 0, width, height, format, gl.UNSIGNED_BYTE, data);
			}
			else
			{
				gl.texImage2D(target, 0, internalFormat, width, height, 0, format, gl.UNSIGNED_BYTE, data);

				__memoryWidth = width;
				__memoryHeight = height;
				__memoryFormat = format;
				__memoryInternalFormat = internalFormat;
			}
		}
	}
}
