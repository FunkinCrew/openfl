
package openfl.media;
#if (cpp && windows)
	import haxe.io.UInt16Array;
	import lime.media.AudioBuffer;
	import lime.media.AudioSource;
	import openfl.media._internal.GLUtil;
	import cpp.Pointer;
	import haxe.io.Bytes;
	import haxe.io.BytesData;
	import lime.utils.Float32Array;
	import lime.utils.UInt16Array;
	import lime.utils.UInt8Array;
	import openfl.Lib;
	import openfl.display.Bitmap;
	import openfl.display.BitmapData;
	import openfl.display3D.Context3D;
	import openfl.display3D.IndexBuffer3D;
	import openfl.display3D.Program3D;
	import openfl.display3D.VertexBuffer3D;
	import openfl.display3D.textures.RectangleTexture;
	import openfl.events.Event;
	import openfl.geom.Rectangle;
	import openfl.media._internal.NativeVideoBackend;
#end

/**
 * NativeVideo is a hardware-accelerated or software-rendered video playback component for OpenFL.
 *
 * It supports decoding and rendering NV12 video frames using a native backend (Media Foundation on Windows).
 * This class allows rendering video as a `Bitmap`, supporting both GPU and software paths depending on context.
 *
 * **Note:** This is a **BETA API** and subject to change.
 *
 * @author Christopher Speciale
 */
@:access(openfl.media._internal.NativeVideoBackend)
class NativeVideo extends Bitmap
{
	/** Whether NativeVideo is supported on the current platform. */
	public static inline var isSupported:Bool = #if (cpp && windows) true #else false #end;

	#if (cpp && windows)
	@:noCompletion private var __isPlaying:Bool;
	@:noCompletion private var __isHardware:Bool;
	@:noCompletion private var __textureWidth:Int;
	@:noCompletion private var __textureHeight:Int;
	@:noCompletion private var __videoWidth:Int;
	@:noCompletion private var __videoHeight:Int;
	@:noCompletion private var __textureY:RectangleTexture;
	@:noCompletion private var __textureUV:RectangleTexture;
	@:noCompletion private var __videoTexture:RectangleTexture;
	@:noCompletion private var __context:Context3D;
	@:noCompletion private var __videoBuffer:Bytes;
	@:noCompletion private var __bitmapBuffer:Bytes;
	@:noCompletion private var __frameRect:Rectangle;
	@:noCompletion private var __positions:VertexBuffer3D;
	@:noCompletion private var __uvs:VertexBuffer3D;
	@:noCompletion private var __indices:IndexBuffer3D;
	@:noCompletion private var __program:Program3D;
	@:noCompletion private var __processFrames:Void->Void;
	@:noCompletion private var __audioSampleRate:Int;
	@:noCompletion private var __audioChannels:Int;
	@:noCompletion private var __audioSource:AudioSource;
	@:noCompletion private var __audioBuffers:Array<AudioBuffer>;
	@:noCompletion private var __sampleBuffer:Bytes;
	@:noCompletion private var __frameRate:Float;
	@:noCompletion private var __videoDuration:Int;

	/**
	 * Creates a new NativeVideo instance.
	 *
	 * @param width The texture width to use for rendering.
	 * @param height The texture height to use for rendering.
	 * @param smoothing Whether to apply smoothing to the output bitmap.
	 * @throws An error if the video backend cannot be initialized.
	 */
	public function new(width:Int, height:Int, smoothing:Bool = false)
	{
		if (!__videoInit())
		{
			throw "Could not initialize Native Video Backend";
		}

		__isPlaying = false;
		__isHardware = Lib.current.stage.window.context.type != "cairo";
		__processFrames = __isHardware ? __processGLFrames : __processSoftwareFrames;

		super(null, null, smoothing);

		__textureWidth = width;
		__textureHeight = height;
	}

	/**
	 * Loads a video from the specified path.
	 *
	 * @param path The file path to the video.
	 * @throws An error if the video cannot be loaded or is unsupported.
	 */
	public function load(path:String):Void
	{
		__videoWidth = __videoGetWidth(path);
		__videoHeight = __videoGetHeight(path);

		if (__videoWidth == -1 || __videoHeight == -1)
		{
			throw "Video not supported.";
		}

		if (__isHardware)
		{
			if (!__videoGLLoad(path))
			{
				throw "Video not supported.";
			}

			__context = Lib.current.stage.context3D;
			__videoTexture = __context.createRectangleTexture(__textureWidth, __textureHeight, BGRA, true);
			__textureY = __context.createRectangleTexture(__videoWidth, __videoHeight, null, false);
			__textureUV = __context.createRectangleTexture(Std.int(__videoWidth * 0.5), Std.int(__videoHeight * 0.5), null, false);

			@:privateAccess
			__textureY.__textureID = NativeVideoBackend.__getTextureIDY();
			@:privateAccess
			__textureUV.__textureID = NativeVideoBackend.__getTextureIDUV();

			@:privateAccess
			__textureY.__internalFormat = __textureY.__format = GLUtil.RED(__context);
			@:privateAccess
			__textureUV.__internalFormat = __textureUV.__format = GLUtil.RG(__context);

			__setupData();
			__createProgram();
			this.bitmapData = BitmapData.fromTexture(__videoTexture);
		}
		else {
			__setupBuffers();
			__frameRect = new Rectangle(0, 0, __videoWidth, __videoHeight);

			var bmd:BitmapData = new BitmapData(__videoWidth, __videoHeight, false, 0x0);
			this.bitmapData = bmd;

			this.width = __textureWidth;
			this.height = __textureHeight;

			if (!__videoSoftwareLoad(path, __videoBuffer.getData(), __videoBuffer.length))
			{
				throw "Video not supported.";
			}
		}

		__loadMetaData();

		var multiplier:Int = 8;
		var sampleCount:Int = 1024 * multiplier;
		var byteLength:Int = sampleCount * 2 * 2;
		__sampleBuffer = Bytes.alloc(byteLength);
	}

	/**
	 * Unloads the current video and releases resources.
	 */
	public function unload():Void
	{
		__unloadBuffers();
		__videoShutdown();

	}

	/**
	 * Starts video playback.
	 */
	public function play():Void
	{
		__isPlaying = true;
		__onAudioPlayback(null);

	}

	/**
	 * Stops video playback.
	 */
	public function stop():Void
	{
		__isPlaying = false;
	}

	@:noCompletion private function __onAudioPlayback(_):Void
	{
		if (!__isPlaying) return;

		var written:Int = __videoGetAudioSamples(__sampleBuffer, __sampleBuffer.length);

		if (written <= 0)
		{
			trace("No audio samples returned");
			return;
		}

		var audioBuf = new AudioBuffer();
		audioBuf.bitsPerSample = 16;
		audioBuf.channels = 2;
		audioBuf.sampleRate = __audioSampleRate;
		audioBuf.data = UInt8Array.fromBytes(__sampleBuffer);

		var s = Sound.fromAudioBuffer(audioBuf);
		var sc = s.play();

		sc.addEventListener(Event.SOUND_COMPLETE, __onAudioPlayback);

		trace(__videoGetAudioPosition(), __videoGetAudioPosition(), __videoDuration);
	}

	@:noCompletion private function __loadMetaData():Void
	{
		__audioSampleRate = __videoGetAudioSampleRate();
		__frameRate = __videoGetFrameRate();
		__audioChannels = __videoGetAudioChannelCount();
		__videoDuration = __videoGetDuration();
	}

	@:noCompletion override private function __enterFrame(deltaTime:Float):Void
	{
		super.__enterFrame(deltaTime);

		if (__isPlaying)
		{
			__processFrames();
		}
	}

	@:noCompletion private function __processGLFrames():Void
	{
		if (!__videoGLUpdateFrame())
		{
			stop();
			return;
		}

		__context.setRenderToTexture(__videoTexture, true);
		__context.setProgram(__program);
		__context.setTextureAt(0, __textureY);
		__context.setTextureAt(1, __textureUV);

		__context.setVertexBufferAt(0, __positions, 0, FLOAT_2); // aPosition
		__context.setVertexBufferAt(1, __uvs, 0, FLOAT_2);       // aTexCoord
		__context.drawTriangles(__indices);
		__context.setRenderToBackBuffer();

		@:privateAccess
		this.bitmapData.__texture = __videoTexture;
		this.bitmapData = this.bitmapData;
	}

	@:noCompletion private function __processSoftwareFrames():Void
	{
		if (!__videoSoftwareUpdateFrame())
		{
			stop();
			return;
		}

		nv12ToRGBA(__videoBuffer, __bitmapBuffer, __videoWidth, __videoHeight);
		this.bitmapData.setPixels(__frameRect, __bitmapBuffer);
	}

	@:noCompletion private function __unloadBuffers():Void
	{
		__bitmapBuffer = null;
		__videoBuffer = null;
	}

	@:noCompletion private function __setupBuffers():Void
	{
		var product:Int = __videoWidth * __videoHeight;

		var __bitmapBufferLength:Int = product * 4;
		__bitmapBuffer = Bytes.alloc(__bitmapBufferLength);

		var videoBufferLength:Int = Std.int(product * 1.5);
		__videoBuffer = Bytes.alloc(videoBufferLength);
	}

	@:noCompletion private function __setupData():Void
	{
		// Vertex positions (-1 to 1)
		var posData = new Float32Array([
			-1, -1,
			1, -1,
			-1,  1,
			1,  1
		]);
		__positions = __context.createVertexBuffer(4, 2);
		__positions.uploadFromTypedArray(posData, 0);

		// UVs (0 to 1)
		var uvData = new Float32Array([
			0, 0,
			1, 0,
			0, 1,
			1, 1
		]);
		__uvs = __context.createVertexBuffer(4, 2);
		__uvs.uploadFromTypedArray(uvData, 0);

		// Indices (2 triangles)
		__indices = __context.createIndexBuffer(6);
		__indices.uploadFromTypedArray(new UInt16Array([0, 1, 2, 2, 1, 3]), 0);
	}

	@:noCompletion private function __createProgram():Void
	{
		var vertexShader:String = "attribute vec2 aPosition;
		attribute vec2 aTexCoord;
		varying vec2 vTexCoord;

		void main() {
		vTexCoord = aTexCoord;
		gl_Position = vec4(aPosition, 0.0, 1.0);
	}";

		var fragmentShader:String = "precision mediump float;

		uniform sampler2D u_tex0;
		uniform sampler2D u_tex1;

		varying vec2 vTexCoord;

		void main() {
		float y = texture2D(u_tex0, vTexCoord).r;

		vec2 uv = texture2D(u_tex1, vTexCoord).rg;
		float u = uv.r - 0.5;
		float v = uv.g - 0.5;

		float r = y + 1.402 * v;
		float g = y - 0.344136 * u - 0.714136 * v;
		float b = y + 1.772 * u;

		gl_FragColor = vec4(r, g, b, 1.0);
	}";

		__program = __context.createProgram(GLSL);
		__program.uploadSources(vertexShader, fragmentShader);
	}

	@:noCompletion private static function __videoInit():Bool
	{
		return NativeVideoBackend.__videoInit();
	}

	@:noCompletion private static function __videoSoftwareLoad(path:String, buffer:BytesData, length:Int):Bool
	{
		return NativeVideoBackend.__videoSoftwareLoad(path, Pointer.ofArray(buffer), length);
	}

	@:noCompletion private static function __videoSoftwareUpdateFrame():Bool
	{
		return NativeVideoBackend.__videoSoftwareUpdateFrame();
	}

	@:noCompletion private static function __videoGLLoad(path:String):Bool
	{
		return NativeVideoBackend.__videoGLLoad(path);

	}

	@:noCompletion private static function __videoGLUpdateFrame():Bool
	{
		return NativeVideoBackend.__videoGLUpdateFrame();
	}

	@:noCompletion private static function __videoGetWidth(path:String):Int
	{
		return NativeVideoBackend.__videoGetWidth(path);
	}

	@:noCompletion private static function __videoGetHeight(path:String):Int
	{
		return NativeVideoBackend.__videoGetHeight(path);
	}

	@:noCompletion private static function __videoShutdown():Void
	{
		NativeVideoBackend.__videoShutdown();
	}

	@:noCompletion private static function __videoGetAudioSamples(buffer:Bytes, samples:Int):Int
	{
		return NativeVideoBackend.__videoGetAudioSamples(Pointer.ofArray(buffer.getData()), samples);
	}

	@:noCompletion private static function __videoGetAudioSampleRate():Int
	{
		return NativeVideoBackend.__videoGetAudioSampleRate();
	}

	@:noCompletion private static function __videoGetAudioBitsPerSample():Int
	{
		return NativeVideoBackend.__videoGetAudioBitsPerSample();
	}

	@:noCompletion private static function __videoGetFrameRate():Float
	{
		return NativeVideoBackend.__videoGetFrameRate();
	}

	@:noCompletion private static function __videoGetAudioChannelCount():Int
	{
		return NativeVideoBackend.__videoGetAudioChannelCount();
	}

	@:noCompletion private static function __videoGetDuration():Int
	{
		return NativeVideoBackend.__videoGetDuration();
	}

	@:noCompletion private static function __videoGetAudioPosition():Int
	{
		return NativeVideoBackend.__videoGetAudioPosition();
	}

	@:noCompletion private static function __videoGetVideoPosition():Int
	{
		return NativeVideoBackend.__videoGetVideoPosition();
	}

	@:noCompletion private static function nv12ToRGBA(nv12:Bytes, rgba:Bytes, width:Int, height:Int)
	{
		var frameSize = width * height;
		var uvOffset = frameSize + width * 2; // skip first UV row
		var maxUVRows = ((height - 4) >> 1);  // only read UV rows for 270 Y lines

		for (y in 0...height)
		{
			var yRow = y * width;
			var uvRowIndex = (y >> 1);
			if (uvRowIndex >= maxUVRows) continue; // prevent UV overflow

			var uvRow = uvOffset + uvRowIndex * width;

			for (x in 0...width)
			{
				var Y = nv12.get(yRow + x) & 0xFF;
				var U = nv12.get(uvRow + (x & ~1)) & 0xFF;
				var V = nv12.get(uvRow + (x & ~1) + 1) & 0xFF;

				var C = Y - 16;
				var D = U - 128;
				var E = V - 128;

				var R = (298 * C + 409 * E + 128) >> 8;
				var G = (298 * C - 100 * D - 208 * E + 128) >> 8;
				var B = (298 * C + 516 * D + 128) >> 8;

				var rgbaIndex = 4 * (y * width + x);
				rgba.set(rgbaIndex, clamp(B));
				rgba.set(rgbaIndex + 1, clamp(G));
				rgba.set(rgbaIndex + 2, clamp(R));
				rgba.set(rgbaIndex + 3, 255);
			}
		}
	}

	@:noCompletion private inline static function clamp(v:Int):Int
	{
		return v < 0 ? 0 : (v > 255 ? 255 : v);
	}

	#else
	public function new(Width:Int, height:Int, smoothing:Bool = false)
	{
		super();
		Lib.notImplemented();
	}
	#end
}