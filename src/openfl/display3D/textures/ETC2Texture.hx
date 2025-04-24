package openfl.display3D.textures;

#if !flash
import haxe.io.Bytes;
import haxe.Timer;
import openfl.utils._internal.ArrayBufferView;
import openfl.utils._internal.UInt8Array;
import openfl.display._internal.SamplerState;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.utils.ByteArray;

/**
	The Texture class represents a 2-dimensional texture uploaded to a rendering context.

	Defines a 2D texture for use during rendering.

	Texture cannot be instantiated directly. Create instances by using Context3D
	`createTexture()` method.
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(openfl.display3D.Context3D)
@:access(openfl.display.Stage)
@:access(openfl.events.Event)
@:final class ETC2Texture extends TextureBase
{
	@:noCompletion private static var __lowMemoryMode:Bool = false;
	private static inline final GL_COMPRESSED_RGBA8_ETC2_EAC = 0x9278;

	@:noCompletion private function new(context:Context3D, data:ByteArray)
	{
		super(context);

		data.position = 0x24;
		__width = data.readUnsignedInt();
		__height = data.readUnsignedInt();

		__optimizeForRenderToTexture = false;
		__streamingLevels = 0;

		var format = GL_COMPRESSED_RGBA8_ETC2_EAC;
		__format = format;
		__internalFormat = format;

		var gl = __context.gl;

		__textureTarget = gl.TEXTURE_2D;

		__uploadETC2TextureFromByteArray(data);
	}

	@:noCompletion public function __uploadETC2TextureFromByteArray(data:ByteArray):Void
	{
		var context = __context;
		var gl = context.gl;

		__context.__bindGLTexture2D(__textureID);

		data.position = 0x3C;
		var bytesOfKeyValueData = data.readUnsignedInt();
		var imageSizeOffset = 64 + bytesOfKeyValueData;
		data.position = imageSizeOffset;
		var imageSize = data.readUnsignedInt();

		var bytes:Bytes = cast data;
		var textureBytes = new UInt8Array(#if js @:privateAccess bytes.b.buffer #else bytes #end, 68, imageSize);
		gl.compressedTexImage2D(__textureTarget, 0, __internalFormat, __width, __height, 0, textureBytes);
		gl.texParameteri(__textureTarget, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(__textureTarget, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

		__context.__bindGLTexture2D(null);
	}
}
#end
