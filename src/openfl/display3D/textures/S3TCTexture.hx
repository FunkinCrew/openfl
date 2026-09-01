package openfl.display3D.textures;

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

		final extension:Null<Dynamic> = __context.gl.getExtension("EXT_texture_compression_s3tc");

		if (extension == null)
		{
			throw new IllegalOperationError("S3TC texture compression is not supported on this device (missing GL extension: EXT_texture_compression_s3tc).");
		}

		var reader:S3TCReader = new S3TCReader(data);

		{
			final format:Null<Int> = Reflect.field(extension, 'COMPRESSED_RGBA_S3TC_${reader.formatName}_EXT');

			if (format == null)
			{
				throw new IllegalOperationError('S3TC format ${reader.formatName} is not supported on this device.');
			}

			__textureTarget = __context.gl.TEXTURE_2D;
			__width = reader.width;
			__height = reader.height;
			__format = format;
			__internalFormat = format;
			__premultiplyAlpha = true;

			{
				__context.__bindGLTexture2D(__textureID);

				__context.gl.compressedTexImage2D(__textureTarget, 0, __internalFormat, __width, __height, 0, reader.getCompressedData());

				__context.__bindGLTexture2D(null);
			}

			reader.dispose();
		}

		reader = null;
	}

	@:noCompletion private override function __setSamplerState(state:openfl.display._internal.SamplerState):Bool
	{
		if (super.__setSamplerState(state))
		{
			var gl = __context.gl;

			if (state.mipfilter != MIPNONE && !__samplerState.mipmapGenerated)
			{
				gl.generateMipmap(__textureTarget);
				__samplerState.mipmapGenerated = true;
			}

			if (Context3D.__glMaxTextureMaxAnisotropy != 0)
			{
				var aniso:Int = -1;

				if (state != null && state.filter != null)
				{
					switch (state.filter)
					{
						case ANISOTROPIC2X:
							aniso = 2;
						case ANISOTROPIC4X:
							aniso = 4;
						case ANISOTROPIC8X:
							aniso = 8;
						case ANISOTROPIC16X:
							aniso = 16;
						default:
							aniso = 1;
					}
				}

				if (aniso > Context3D.__glMaxTextureMaxAnisotropy) aniso = Context3D.__glMaxTextureMaxAnisotropy;

				gl.texParameterf(gl.TEXTURE_2D, Context3D.__glTextureMaxAnisotropy, aniso);
			}

			return true;
		}

		return false;
	}
}
