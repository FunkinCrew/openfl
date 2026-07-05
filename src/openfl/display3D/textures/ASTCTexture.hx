package openfl.display3D.textures;

#if !flash
#if bgfx
import lime.graphics.bgfx.BGFXTextureFormat;
#end
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
#if bgfx
@:access(openfl.display3D.backends.bgfx.Context3D)
#elseif opengl
@:access(openfl.display3D.backends.opengl.Context3D)
#end
@:final class ASTCTexture extends TextureBase
{
	@:noCompletion
	private static var __astcCompressedTexturesSupported:Null<Bool>;

	@:noCompletion
	private function new(context:Context3D, data:ByteArray):Void
	{
		super(context);

		if (!context.isASTCSupported()) throw new IllegalOperationError("ASTC texture compression is not supported on this device");

		var reader:ASTCReader = new ASTCReader(data);

		#if opengl
		final format:Null<Int> = Reflect.field(extension, 'COMPRESSED_RGBA_ASTC_${reader.blockX}x${reader.blockY}_KHR');

		if (format == null) throw new IllegalOperationError('ASTC format ${reader.blockX}x${reader.blockY} is not supported on this device');
		#elseif bgfx
		final bgfx = __context.bgfx;
		final caps = bgfx.getCaps();
		final format:BGFXTextureFormat = __getASTCFormat(reader.blockX, reader.blockY);

		if ((caps.formats[format] & bgfx.CAPS_FORMAT_TEXTURE_2D) == 0)
			throw new IllegalOperationError('ASTC format ${reader.blockX}x${reader.blockY} is not supported on this device.');
		#end

		__width = reader.width;
		__height = reader.height;
		__format = format;
		__internalFormat = format;
		__premultiplyAlpha = true;

		#if opengl
		__textureTarget = __context.gl.TEXTURE_2D;
		__context.__bindGLTexture2D(__textureID);
		__context.gl.compressedTexImage2D(__textureTarget, 0, __internalFormat, __width, __height, 0, reader.getCompressedData());
		__context.__bindGLTexture2D(null);
		#elseif bgfx
		__textureID = bgfx.createTexture2D(__width, __height, false, 1, format, 0, bgfx.copy(reader.getCompressedData()));
		#end

		reader.dispose();
		reader = null;
	}

	@:noCompletion
	private override function __setSamplerState(state:openfl.display._internal.SamplerState):Bool
	{
		if (super.__setSamplerState(state))
		{
			#if opengl
			if (Context3D.__maxTextureMaxAnisotropy != 0)
			{
				var aniso = switch (state.filter)
				{
					case ANISOTROPIC2X: 2;
					case ANISOTROPIC4X: 4;
					case ANISOTROPIC8X: 8;
					case ANISOTROPIC16X: 16;
					default: 1;
				}

				if (aniso > Context3D.__maxTextureMaxAnisotropy)
				{
					aniso = Context3D.__maxTextureMaxAnisotropy;
				}

				gl.texParameterf(gl.TEXTURE_2D, Context3D.__textureMaxAnisotropy, aniso);
			}
			#else
			var bgfx = __context.bgfx;
			// bgfx has no per-texture anisotropic filtering
			// it's defined globally by the reset flags
			var aniso = switch (state.filter)
			{
				case ANISOTROPIC2X, ANISOTROPIC4X, ANISOTROPIC8X, ANISOTROPIC16X:
					__samplerStateFlags |= bgfx.SAMPLER_MAG_ANISOTROPIC;
					__samplerStateFlags |= bgfx.SAMPLER_MIN_ANISOTROPIC;
				default: 0; // nothing
			}
			#end

			return true;
		}

		return false;
	}

	#if bgfx
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
	#end
}
#end
