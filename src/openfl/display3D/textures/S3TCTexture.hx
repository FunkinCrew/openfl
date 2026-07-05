package openfl.display3D.textures;

import lime.graphics.bgfx.BGFXTextureFormat;
import openfl.display3D.Context3D;
import openfl.display3D._internal.S3TCReader;
import openfl.errors.IllegalOperationError;
import openfl.utils.ByteArray;

using StringTools;

/**
	The S3TCTexture class represents a 2-dimensional texture using S3TC (DXT1, DXT3, DXT5) compression for use in a rendering context.

	S3TC compression provides high-quality textures with reduced memory usage, but it requires hardware support for the "EXT_texture_compression_s3tc" extension.

	S3TCTexture cannot be instantiated directly. Create instances by using Context3D
	`createS3TCTexture()` method.
**/
@:access(openfl.display3D.Context3D)
@:final class S3TCTexture extends TextureBase
{
	@:noCompletion private static var __s3tcCompressedTexturesSupported:Null<Bool>;

	@:noCompletion private function new(context:Context3D, data:ByteArray):Void
	{
		super(context);

		if (!context.isS3TCSupported()) throw new IllegalOperationError("S3TC texture compression is not supported on this device");

		var reader:S3TCReader = new S3TCReader(data);

		var format:Int;

		if (__context.isBGFX)
		{
			final bgfx = __context.bgfx;
			final caps = bgfx.getCaps();
			format = __getS3TCFormat(reader.fourCC);

			if ((caps.formats[format] & bgfx.CAPS_FORMAT_TEXTURE_2D) == 0)
				throw new IllegalOperationError('S3TC format ${reader.formatName} is not supported on this device.');
		}
		else
		{
			var extension:Dynamic = __context.gl.getExtension("EXT_texture_compression_s3tc");
			final glFormat:Null<Int> = Reflect.field(extension, 'COMPRESSED_RGBA_S3TC_${reader.formatName}_EXT');

			if (glFormat == null) throw new IllegalOperationError('S3TC format ${reader.formatName} is not supported on this device.');
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
			__textureID = bgfx.createTexture2D(__width, __height, false, 1, format, 0, bgfx.copy(reader.getCompressedData()));
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
			else
			{
				var gl = __context.gl;

				if (state.mipfilter != MIPNONE && !__samplerState.mipmapGenerated)
				{
					gl.generateMipmap(__textureTarget);
					__samplerState.mipmapGenerated = true;
				}

				if (__context.__maxTextureMaxAnisotropy != 0)
				{
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
			}

			return true;
		}

		return false;
	}

	@:noCompletion private static function __getS3TCFormat(fourCC:Int):BGFXTextureFormat
	{
		return switch (fourCC)
		{
			case S3TCReader.FOURCC_DXT1: BGFXTextureFormat.BC1;
			case S3TCReader.FOURCC_DXT3: BGFXTextureFormat.BC2;
			case S3TCReader.FOURCC_DXT5: BGFXTextureFormat.BC3;
			default: throw new IllegalOperationError('Unsupported S3TC FourCC: $fourCC');
		}
	}
}
