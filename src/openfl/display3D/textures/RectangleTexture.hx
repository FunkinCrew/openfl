package openfl.display3D.textures;

import haxe.Int64;
import lime.utils.ArrayBufferView;
import lime.utils.UInt8Array;
import openfl.display.BitmapData;
import openfl.display._internal.SamplerState;
import openfl.utils.ByteArray;

/**
	The Rectangle Texture class represents a 2-dimensional texture uploaded to a rendering
	context.

	Defines a 2D texture for use during rendering.

	Texture cannot be instantiated directly. Create instances by using Context3D
	`createRectangleTexture()` method.
**/
@:access(openfl.display3D.Context3D)
@:access(openfl.display.Stage)
@:final class RectangleTexture extends TextureBase
{
	@:noCompletion private function new(context:Context3D, width:Int, height:Int, format:String, optimizeForRenderToTexture:Bool)
	{
		super(context, format);

		__width = width;
		__height = height;
		__optimizeForRenderToTexture = optimizeForRenderToTexture;

		if (!__context.isBGFX) __textureTarget = __context.gl.TEXTURE_2D;

		uploadFromTypedArray(null);

		if (optimizeForRenderToTexture) __getFramebuffer(true, 0, 0);
	}

	/**
		Uploads a texture from a BitmapData object.

		@param	source	a bitmap.
		@throws	TypeError	Null Pointer Error: when `source` is `null`.
		@throws	ArgumentError	Invalid BitmapData Error: when `source` does not contain a
		valid texture. The maximum allowed size in any dimension is 4096 or the size of the
		backbuffer, whichever is greater.
		@throws	Error	3768: The Stage3D API may not be used during background execution.
	**/
	public function uploadFromBitmapData(source:BitmapData):Void
	{
		if (source == null) return;

		var image = __getImage(source);

		if (image == null) return;

		#if (js && html5)
		if (!__context.isBGFX && image.buffer != null && image.buffer.data == null && image.buffer.src != null)
		{
			var gl = __context.gl;

			__context.__bindGLTexture2D(__textureID);
			gl.texImage2D(__textureTarget, 0, __internalFormat, __format, gl.UNSIGNED_BYTE, image.buffer.src);
			__context.__bindGLTexture2D(null);
			return;
		}
		#end

		uploadFromTypedArray(image.data);
	}

	/**
		Uploads a texture from a ByteArray.

		@param	data	a byte array that is contains enough bytes in the textures internal
		format to fill the texture. rgba textures are read as bytes per texel component (1
		or 4). float textures are read as floats per texel component (1 or 4). The
		ByteArray object must use the little endian format.
		@param	byteArrayOffset	the position in the byte array object at which to start
		reading the texture data.
		@throws	TypeError	Null Pointer Error: when `data` is `null`.
		@throws	RangeError	Bad Input Size: if the number of bytes available from
		`byteArrayOffset` to the end of data byte array is less than the amount of data
		required for a texture, or if `byteArrayOffset` is greater than or equal to the
		length of data.
		@throws	Error	3768: The Stage3D API may not be used during background execution.
	**/
	public function uploadFromByteArray(data:ByteArray, byteArrayOffset:UInt):Void
	{
		#if (js && !display)
		if (byteArrayOffset == 0)
		{
			uploadFromTypedArray(@:privateAccess (data : ByteArrayData).b);
			return;
		}
		#end

		uploadFromTypedArray(new UInt8Array(data.toArrayBuffer(), byteArrayOffset));
	}

	/**
		Uploads a texture from an ArrayBufferView.

		@param	data	a typed array that contains enough bytes in the textures internal
		format to fill the texture. rgba textures are read as bytes per texel component (1
		or 4). float textures are read as floats per texel component (1 or 4).
	**/
	public function uploadFromTypedArray(data:ArrayBufferView):Void
	{
		if (__context.isBGFX)
		{
			var bgfx = __context.bgfx;
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
			__uploadTexture2D(0, __width, __height, __format, __format, data);
		}
		else if (__context.isOpenGL)
		{
			var gl = __context.gl;
			__context.__bindGLTexture2D(__textureID);
			__uploadTexture2D(__textureTarget, __width, __height, __internalFormat, __format, data);
			__context.__bindGLTexture2D(null);
		}
	}

	@:noCompletion private override function __setSamplerState(state:SamplerState):Bool
	{
		if (super.__setSamplerState(state))
		{
			if (__context.isBGFX)
			{
				// TODO: mip generation?
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

				return true;
			}
			else if (__context.isOpenGL)
			{
				var gl = __context.gl;

				if (state.mipfilter != MIPNONE && !__samplerState.mipmapGenerated)
				{
					gl.generateMipmap(gl.TEXTURE_2D);
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
}
