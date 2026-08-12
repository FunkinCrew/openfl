package openfl.display3D.textures;

import openfl.display3D._internal.GLFramebuffer;
import openfl.display3D._internal.GLTexture;
import openfl.utils._internal.Log;

@:access(openfl.display3D.Context3D)
@:access(openfl.display.Stage)
class MultiBufferTexture extends TextureBase
{
	public var buffers:Array<GLFramebuffer> = [];
	public var textures:Array<GLTexture> = [];
	public var scales:Array<Float> = [];

	public function new(context:Context3D, width:Int, height:Int, formats:Array<Context3DTextureFormat>, ?scales:Array<Float>)
	{
		super(context);

		this.scales = scales ?? [1.0, 1.0];

		var gl = context.gl;
		// delete the default initial texture made by the texture base as we won't use be using it
		gl.deleteTexture(__textureID);

		__width = width;
		__height = height;
		__optimizeForRenderToTexture = true;
		__textureTarget = context.gl.TEXTURE_2D;

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

	private override function __getGLFramebuffer(enableDepthAndStencil:Bool, antiAlias:Int, surfaceSelector:Int):GLFramebuffer
	{
		var gl = __context.gl;
		var addedBuffers = __glFramebuffer == null;

		var framebuffer = super.__getGLFramebuffer(enableDepthAndStencil, antiAlias, surfaceSelector);

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

			if (__context.__enableErrorChecking)
			{
				var code = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
				if (code != gl.FRAMEBUFFER_COMPLETE)
				{
					Log.warn('Error: MultiBufferTexture.__getGLFramebuffer status:${code} width:${__width} height:${__height}');
				}
			}
		}

		return framebuffer;
	}

	public override function dispose():Void
	{
		var gl = __context.gl;

		for (i in 1...textures.length)
		{
			gl.deleteTexture(textures[i]);
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

	private function context3DFormatToGLFormat(f:Context3DTextureFormat):Int
	{
		var gl = __context.gl;

		switch (f)
		{
			case BGRA:
				if (TextureBase.__supportsBGRA)
				{
					var bgraExtension:Dynamic = null;
					bgraExtension = gl.getExtension("EXT_bgra");
					if (bgraExtension == null) bgraExtension = gl.getExtension("EXT_texture_format_BGRA8888");
					if (bgraExtension == null) bgraExtension = gl.getExtension("APPLE_texture_format_BGRA8888");

					return bgraExtension.BGRA_EXT;
				}
				else
				{
					return gl.RGBA;
				}

			case R:
				return gl.RED;

			default:
				return gl.RGBA;
		}
	}

	private function context3DFormatToInternalGLFormat(f:Context3DTextureFormat, baseGLFormat:Int):Int
	{
		var gl = __context.gl;

		switch (f)
		{
			case BGRA:
				#if (lime && !ios)
				return (__context.__context.type == OPENGLES) ? baseGLFormat : gl.RGBA;
				#else
				return gl.RGBA;
				#end

			case R:
				return gl.R8;

			default:
				return baseGLFormat;
		}
	}
}
