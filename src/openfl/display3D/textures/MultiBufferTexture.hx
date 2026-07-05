package openfl.display3D.textures;

import lime.graphics.bgfx.BGFXTexture;
import lime.graphics.bgfx.BGFXTextureFormat;
import lime.graphics.opengl.GLFramebuffer;
import lime.utils.Log;
import openfl.display.OpenGLRenderer;

@:access(openfl.display3D.Context3D)
@:access(openfl.display.Stage)
class MultiBufferTexture extends TextureBase
{
	@SuppressWarnings("checkstyle:Dynamic") public var buffers:Array<Dynamic> = [];
	@SuppressWarnings("checkstyle:Dynamic") public var textures:Array<Dynamic> = [];
	public var scales:Array<Float> = [];

	public function new(context:Context3D, width:Int, height:Int, formats:Array<Context3DTextureFormat>, ?scales:Array<Float>)
	{
		super(context);

		this.scales = scales ?? [1.0, 1.0];

		__width = width;
		__height = height;
		__optimizeForRenderToTexture = true;

		if (context.isBGFX)
		{
			var bgfx = context.bgfx;

			if (__textureID != null)
			{
				bgfx.destroyTexture(__textureID);
				__textureID = null;
			}

			__textureFlags = bgfx.TEXTURE_RT;

			for (i => format in formats)
			{
				final bgfxFormat = context3DFormatToBGFXFormat(format);
				final texture = bgfx.createTexture2D(__width, __height, false, 1, bgfxFormat, bgfx.TEXTURE_RT, null);

				textures.push(texture);

				if (i == 0)
				{
					__textureID = texture;
					__format = bgfxFormat;
					__internalFormat = bgfxFormat;
				}
			}
		}
		else
		{
			var gl = context.gl;
			// delete the default initial texture made by the texture base as we won't use be using it
			gl.deleteTexture(__textureID);

			__textureTarget = gl.TEXTURE_2D;

			for (i => format in formats)
			{
				final texture = gl.createTexture();
				final mainFormat = context3DFormatToGLFormat(format);
				final internalFormat = context3DFormatToInternalGLFormat(format, mainFormat);

				context.__bindGLTexture2D(texture);
				gl.texImage2D(__textureTarget, 0, internalFormat, __width, __height, 0, mainFormat, gl.UNSIGNED_BYTE, null);
				context.__bindGLTexture2D(null);

				textures.push(texture);
				if (i == 0)
				{
					__textureID = texture;
					__format = mainFormat;
					__internalFormat = internalFormat;
				}
			}
		}
	}

	@SuppressWarnings("checkstyle:Dynamic")
	@:noCompletion private override function __getFramebuffer(enableDepthAndStencil:Bool, antiAlias:Int, surfaceSelector:Int):GLFramebuffer
	{
		if (__context.isBGFX)
		{
			var bgfx = __context.bgfx;

			if (__framebuffer == null)
			{
				var attachments:Array<BGFXTexture> = [];

				for (texture in textures)
				{
					attachments.push(texture);
				}

				if (enableDepthAndStencil) attachments.push(bgfx.createTexture2D(__width, __height, false, 1, __context.__bgfxDepthFormat,
					bgfx.TEXTURE_RT_WRITE_ONLY));

				__framebuffer = bgfx.createFrameBufferFromTextures(attachments, true);

				for (i in 0...textures.length)
				{
					textures[i] = bgfx.getTexture(__framebuffer, i);
				}

				__textureID = textures[0];
			}

			return __framebuffer;
		}

		var gl = __context.gl;
		var addedBuffers = __framebuffer == null;

		var framebuffer = super.__getFramebuffer(enableDepthAndStencil, antiAlias, surfaceSelector);

		if (addedBuffers)
		{
			__context.__bindGLFramebuffer(framebuffer);

			var drawBuffers:Array<Int> = [gl.COLOR_ATTACHMENT0];

			for (i in 1...textures.length)
			{
				var attachment = gl.COLOR_ATTACHMENT0 + i;
				gl.framebufferTexture2D(gl.FRAMEBUFFER, attachment, gl.TEXTURE_2D, textures[i], 0);
				drawBuffers.push(attachment);
			}

			gl.drawBuffers(drawBuffers);

			if (__context.enableErrorChecking)
			{
				var code = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
				if (code != gl.FRAMEBUFFER_COMPLETE)
				{
					Log.warn('Error: MultiBufferTexture.__getFramebuffer status:${code} width:${__width} height:${__height}');
				}
			}
		}

		return framebuffer;
	}

	public override function dispose():Void
	{
		if (__context.isBGFX)
		{
			var bgfx = __context.bgfx;

			if (__framebuffer == null)
			{
				for (i in 1...textures.length)
				{
					if (textures[i] != null) bgfx.destroyTexture(textures[i]);
				}
			}
		}
		else
		{
			var gl = __context.gl;

			for (i in 1...textures.length)
			{
				gl.deleteTexture(textures[i]);
			}
		}

		textures = [];

		super.dispose();
	}

	public function withAttachment(i:Int, fun:Void->Void):Void
	{
		var previousTexture = __textureID;

		__textureID = textures[i];

		fun();

		__textureID = previousTexture;
	}

	@:noCompletion private function context3DFormatToBGFXFormat(f:Context3DTextureFormat):BGFXTextureFormat
	{
		return switch (f)
		{
			case RGB: BGFXTextureFormat.RGB8;
			case BGRA: TextureBase.__supportsBGRA == true ? BGFXTextureFormat.BGRA8 : BGFXTextureFormat.RGBA8;
			case RGBA: BGFXTextureFormat.RGBA8;
			case R: BGFXTextureFormat.R8;
		}
	}

	@:noCompletion private function context3DFormatToGLFormat(f:Context3DTextureFormat):Int
	{
		var gl = __context.gl;

		switch (f)
		{
			case RGB:
				return gl.RGB;
			case BGRA:
				if (OpenGLRenderer.__bgraExtension != null)
				{
					return OpenGLRenderer.__bgraExtension.BGRA_EXT;
				}
				else
				{
					return gl.RGBA;
				}
			case RGBA:
				return gl.RGBA;
			case R:
				return gl.RED;
		}
	}

	@:noCompletion private function context3DFormatToInternalGLFormat(f:Context3DTextureFormat, baseGLFormat:Int):Int
	{
		var gl = __context.gl;

		switch (f)
		{
			case RGB:
				return gl.RGB;
			case BGRA:
				return OpenGLRenderer.__bgraAsInternalFormat ? baseGLFormat : gl.RGBA;
			case RGBA:
				return gl.RGBA;
			case R:
				return gl.R8;
		}
	}
}
