package openfl.display3D.textures;

#if !flash
import openfl.display._internal.SamplerState;
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
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(openfl.display3D.Context3D)
@:final class ASTCTexture extends TextureBase
{
	@:noCompletion
	private static var __astcCompressedTexturesSupported:Null<Bool>;

	@:noCompletion
	private function new(context:Context3D, data:ByteArray):Void
	{
		super(context);

		final extension:Null<Dynamic> = __context.gl.getExtension("KHR_texture_compression_astc_ldr");

		if (extension == null)
			throw new IllegalOperationError("ASTC texture compression is not supported on this device (missing GL extension: GL_KHR_texture_compression_astc_ldr).");

		var reader:ASTCReader = new ASTCReader(data);

		{
			final format:Null<Int> = Reflect.field(extension, 'COMPRESSED_RGBA_ASTC_${reader.blockX}x${reader.blockY}_KHR');

			if (format == null)
				throw new IllegalOperationError('ASTC format ${reader.blockX}x${reader.blockY} is not supported on this device (GL extension KHR_texture_compression_astc_ldr is present, but this block size is missing).');

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

	@:noCompletion private override function __setSamplerState(state:SamplerState):Bool
	{
		if (super.__setSamplerState(state))
		{
			var gl = __context.gl;

			if (Context3D.__glMaxTextureMaxAnisotropy != 0)
			{
				var aniso = switch (state.filter)
				{
					case ANISOTROPIC2X: 2;
					case ANISOTROPIC4X: 4;
					case ANISOTROPIC8X: 8;
					case ANISOTROPIC16X: 16;
					default: 1;
				}

				if (aniso > Context3D.__glMaxTextureMaxAnisotropy)
				{
					aniso = Context3D.__glMaxTextureMaxAnisotropy;
				}

				gl.texParameterf(gl.TEXTURE_2D, Context3D.__glTextureMaxAnisotropy, aniso);
			}

			return true;
		}

		return false;
	}
}
#end
