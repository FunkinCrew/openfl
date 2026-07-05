package openfl.display3D.textures;

import lime.graphics.bgfx.BGFXTextureFormat;
import openfl.utils._internal.ArrayBufferView;
import openfl.display3D.Context3D;
import openfl.display3D._internal.ASTCReader;
import openfl.errors.IllegalOperationError;
import openfl.utils.ByteArray;

using StringTools;

/**
	The ASTCTexture class represents a 2-dimensional texture using ASTC (Adaptive Scalable Texture Compression) for use in a rendering context.

	ASTC compression provides high-quality textures with reduced memory usage, but it requires hardware support for the "KHR_texture_compression_astc_ldr" extension.

	ASTCTexture cannot be instantiated directly. Create instances by using Context3D
	`createASTCTexture()` method.
**/
@:access(openfl.display3D.Context3D)
@:final class ASTCTexture extends TextureBase
{
	@:noCompletion private static var __astcCompressedTexturesSupported:Null<Bool>;

	@:noCompletion private function new(context:Context3D, data:ByteArray):Void
	{
		super(context);

		if (!context.isASTCSupported()) throw new IllegalOperationError("ASTC texture compression is not supported on this device");

		var reader:ASTCReader = new ASTCReader(data);

		var format:Int = -1;

		if (__context.isBGFX)
		{
			final bgfx = __context.bgfx;
			final caps = bgfx.getCaps();
			format = __getASTCFormat(reader.blockX, reader.blockY);

			if ((caps.formats[format] & bgfx.CAPS_FORMAT_TEXTURE_2D) == 0)
				throw new IllegalOperationError('ASTC format ${reader.blockX}x${reader.blockY} is not supported on this device.');
		}
		else if (__context.isOpenGL)
		{
			var extension:Dynamic = __context.gl.getExtension("KHR_texture_compression_astc_ldr");
			final glFormat:Null<Int> = Reflect.field(extension, 'COMPRESSED_RGBA_ASTC_${reader.blockX}x${reader.blockY}_KHR');

			if (glFormat == null) throw new IllegalOperationError('ASTC format ${reader.blockX}x${reader.blockY} is not supported on this device');
			format = glFormat;
		}

		__width = reader.width;
		__height = reader.height;
		__format = format;
		__internalFormat = format;
		__premultiplyAlpha = true;

		if (__context.isBGFX)
		{
			final bgfx = __context.bgfx;
			__textureID = bgfx.createTexture2D(__width, __height, false, 1, __internalFormat, 0, bgfx.copy(reader.getCompressedData()));
		}
		else
		{
			__textureTarget = __context.gl.TEXTURE_2D;
			__context.__bindGLTexture2D(__textureID);
			__context.gl.compressedTexImage2D(__textureTarget, 0, __internalFormat, __width, __height, 0, reader.getCompressedData());
			__context.__bindGLTexture2D(null);
		}

		reader.dispose();
		reader = null;
	}

	@:noCompletion private override function __setSamplerState(state:openfl.display._internal.SamplerState):Bool
	{
		if (super.__setSamplerState(state))
		{
			if (__context.isBGFX)
			{
				var bgfx = __context.bgfx;
				// bgfx has no per-texture anisotropic filtering
				// it's defined globally by the reset flags
				switch (state.filter)
				{
					case ANISOTROPIC2X, ANISOTROPIC4X, ANISOTROPIC8X, ANISOTROPIC16X:
						__samplerStateFlags |= bgfx.SAMPLER_MAG_ANISOTROPIC;
						__samplerStateFlags |= bgfx.SAMPLER_MIN_ANISOTROPIC;
					default: // nothing
				}
			}
			else if (__context.__maxTextureMaxAnisotropy != 0)
			{
				var gl = __context.gl;
				var aniso = switch (state.filter)
				{
					case ANISOTROPIC2X: 2;
					case ANISOTROPIC4X: 4;
					case ANISOTROPIC8X: 8;
					case ANISOTROPIC16X: 16;
					default: 1;
				}

				if (aniso > __context.__maxTextureMaxAnisotropy)
				{
					aniso = __context.__maxTextureMaxAnisotropy;
				}

				gl.texParameterf(gl.TEXTURE_2D, __context.__textureMaxAnisotropy, aniso);
			}

			return true;
		}

		return false;
	}

	@:noCompletion private static function __getASTCFormat(blockX:Int, blockY:Int):BGFXTextureFormat
	{
		return switch ([blockX, blockY])
		{
			case [4, 4]: BGFXTextureFormat.ASTC4x4;
			case [5, 4]: BGFXTextureFormat.ASTC5x4;
			case [5, 5]: BGFXTextureFormat.ASTC5x5;
			case [6, 5]: BGFXTextureFormat.ASTC6x5;
			case [6, 6]: BGFXTextureFormat.ASTC6x6;
			case [8, 5]: BGFXTextureFormat.ASTC8x5;
			case [8, 6]: BGFXTextureFormat.ASTC8x6;
			case [8, 8]: BGFXTextureFormat.ASTC8x8;
			case [10, 5]: BGFXTextureFormat.ASTC10x5;
			case [10, 6]: BGFXTextureFormat.ASTC10x6;
			case [10, 8]: BGFXTextureFormat.ASTC10x8;
			case [10, 10]: BGFXTextureFormat.ASTC10x10;
			case [12, 10]: BGFXTextureFormat.ASTC12x10;
			case [12, 12]: BGFXTextureFormat.ASTC12x12;
			default:
				throw new IllegalOperationError('Unavailable ASTC block size: ${blockX}x${blockY}');
		}
	}

	@:noCompletion private override function __uploadTexture2D(target:Int, width:Int, height:Int, internalFormat:Int, format:Int, data:ArrayBufferView):Void
	{
		var reader:ASTCReader = new ASTCReader(ByteArray.fromArrayBuffer(data.buffer));
		var _format:Int = -1;

		if (__context.isBGFX)
		{
			final bgfx = __context.bgfx;
			final caps = bgfx.getCaps();
			_format = __getASTCFormat(reader.blockX, reader.blockY);

			if ((caps.formats[_format] & bgfx.CAPS_FORMAT_TEXTURE_2D) == 0)
				throw new IllegalOperationError('ASTC format ${reader.blockX}x${reader.blockY} is not supported on this device.');
		}

		super.__uploadTexture2D(target, width, height, _format, _format, data);
	}

	@:noCompletion private override function __getFramebuffer(enableDepthAndStencil:Bool, antiAlias:Int, surfaceSelector:Int):Dynamic
	{
		return null;
	}

	@:noCompletion private override function __uploadFromImage(image:lime.graphics.Image):Void
	{
		return;
	}
}
