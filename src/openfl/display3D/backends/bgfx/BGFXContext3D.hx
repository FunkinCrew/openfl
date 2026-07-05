package openfl.display3D.backends.bgfx;

import haxe.Int64;
import lime.graphics.bgfx.BGFXProgram;
import lime.graphics.BGFXRenderContext;
import lime.graphics.bgfx.BGFXAttrib;
import lime.graphics.bgfx.BGFXAttribType;
import lime.graphics.bgfx.BGFXTexture;
import lime.graphics.bgfx.BGFXTextureFormat;
import lime.graphics.bgfx.BGFXFrameBuffer;
import lime.graphics.bgfx.BGFXTextureFormat;
import openfl.display3D._internal.Context3DState;
import openfl.display._internal.SamplerState;
import openfl.display3D.textures.CubeTexture;
import openfl.display3D.textures.MultiBufferTexture;
import openfl.display3D.textures.S3TCTexture;
import openfl.display3D.textures.RectangleTexture;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.textures.Texture;
import openfl.display3D.textures.ASTCTexture;
import openfl.display3D.textures.VideoTexture;
import openfl.display3D.Context3D;
import openfl.display.BitmapData;
import openfl.display.Stage;
import openfl.display.Stage3D;
import openfl.errors.Error;
import openfl.errors.IllegalOperationError;
import openfl.events.EventDispatcher;
import openfl.geom.Matrix3D;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.utils._internal.Float32Array;
import openfl.utils._internal.UInt16Array;
import openfl.utils._internal.UInt8Array;
import openfl.utils.AGALMiniAssembler;
import openfl.utils.ByteArray;
#if lime
import lime.graphics.bgfx.BGFX;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.RenderContext;
import lime.graphics.WebGL2RenderContext;
import lime.math.Rectangle as LimeRectangle;
import lime.math.Vector2;
#end

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(openfl.display3D._internal.Context3DState)
@:access(openfl.display3D.textures.ASTCTexture)
@:access(openfl.display3D.textures.CubeTexture)
@:access(openfl.display3D.textures.MultiBufferTexture)
@:access(openfl.display3D.textures.S3TCTexture)
@:access(openfl.display3D.textures.RectangleTexture)
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.display3D.textures.Texture)
@:access(openfl.display3D.textures.VideoTexture)
@:access(openfl.display3D.IndexBuffer3D)
@:access(openfl.display3D.Program3D)
@:access(openfl.display3D.VertexBuffer3D)
@:access(openfl.display.BitmapData)
@:access(openfl.display.Bitmap)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.display.Shader)
@:access(openfl.display.ShaderParameter)
@:access(openfl.display.Stage)
@:access(openfl.display.Stage3D)
@:access(openfl.geom.Point)
@:access(openfl.geom.Rectangle)
class BGFXContext3D implements openfl.display3D.IContext3D
{
	@:noCompletion private var parent:Context3D;

	public static var supportsVideoTexture(default, null):Bool = false;

	public var totalGPUMemory(get, never):Float;

	@:noCompletion private static var __driverInfo:String;
	@:noCompletion private static var __depthStencil:Int = -1;
	@:noCompletion private static var __maxViewportDims:Int = -1;
	@:noCompletion private static var __memoryCurrentAvailable:Float = -1;
	@:noCompletion private static var __memoryTotalAvailable:Float = -1;
	@:noCompletion private static var __supportedDepth:Null<BGFXTextureFormat>;

	@:noCompletion public var bgfx:#if lime BGFXRenderContext #else Dynamic #end;
	@:noCompletion public var gl:WebGL2RenderContext;

	@:noCompletion private var __maxTextureMaxAnisotropy:Int = 0;
	@:noCompletion private var __textureMaxAnisotropy:Int = 0;
	@:noCompletion private var __activeVertexBuffer:VertexBuffer3D;
	@:noCompletion private var __currentViewId:Int;
	@:noCompletion private var __nextViewId:Int = 1;
	@:noCompletion private var __pendingRTTClearTarget:TextureBase = null;
	@:noCompletion private var __pendingRTTClearFlags:Int = 0;
	@:noCompletion private var __pendingRTTClearRgba:Int = 0;
	@:noCompletion private var __pendingRTTClearDepth:Float = 1.0;
	@:noCompletion private var __pendingRTTClearStencil:Int = 0;
	@:noCompletion private var __backBufferAntiAlias:Int;
	@:noCompletion private var __backBufferTexture:RectangleTexture;
	@:noCompletion private var __backBufferWantsBestResolutionOnBrowserZoom:Bool;
	@:noCompletion private var __renderStage3DProgram:Program3D;
	@:noCompletion private var __frontBufferTexture:RectangleTexture;
	@:noCompletion private var __positionScale:Float32Array; // TODO: Better approach?
	@:noCompletion private var __quadIndexBufferCount:Int;
	@:noCompletion private var __stage3D:Stage3D;

	@:noCompletion private function new(parent:Context3D, stage:Stage, contextState:Context3DState = null, stage3D:Stage3D = null)
	{
		this.parent = parent;
		parent.__backend = this;

		parent.__stage = stage;
		__stage3D = stage3D;
		parent.__context = stage.window.context;
		parent.__contextState = (contextState != null) ? contextState : new Context3DState();
		parent.__state = new Context3DState();

		parent.driverInfo = "BGFX (Direct blitting)";
		parent.profile = STANDARD;

		bgfx = parent.__context.bgfx;
		gl = null;

		#if lime
		parent.__vertexConstants = new Float32Array(4 * 128);
		parent.__fragmentConstants = new Float32Array(4 * 128);
		__positionScale = new Float32Array([1.0, 1.0, 1.0, 1.0]);
		#end

		parent.__programs = new Map<String, Program3D>();

		if (__maxViewportDims == -1)
		{
			// dunno if this is correct...
			// __maxViewportDims = bgfx.getCaps().limits.maxTextureSize;
			__maxViewportDims = 16384;
		}

		parent.maxBackBufferWidth = __maxViewportDims;
		parent.maxBackBufferHeight = __maxViewportDims;

		if (__memoryTotalAvailable == -1)
		{
			var stats = bgfx.getStats();
			__memoryTotalAvailable = stats.gpuMemoryMax;
			__memoryCurrentAvailable = stats.gpuMemoryMax - stats.gpuMemoryUsed;
		}

		if (__driverInfo == null)
		{
			// Placeholder
			var vendors = [
				0x0000 => "None.",
				0x0001 => "Software.",
				0x1002 => "Advanced Micro Devices, Inc.",
				0x106b => "Apple (R)",
				0x8086 => "Intel (R).",
				0x10de => "NVidia (R)",
				0x1414 => "Microsoft (R)",
				0x13b5 => "ARM (R)."
			];
			var caps = bgfx.getCaps();
			var vendor = vendors[caps.vendorId];
			var renderer = caps.rendererType;

			__driverInfo = "BGFX Renderer Vendor=" + vendor + " Backend Renderer=" + renderer;
		}

		parent.driverInfo = __driverInfo;

		VertexBuffer3D.__registerDefaultLayouts(parent);
		parent.__quadIndexBufferElements = Math.floor(0xFFFF / 4);
		__quadIndexBufferCount = parent.__quadIndexBufferElements * 6;

		var data = new UInt16Array(__quadIndexBufferCount);

		var index:UInt = 0;
		var vertex:UInt = 0;

		for (i in 0...parent.__quadIndexBufferElements)
		{
			data[index] = vertex;
			data[index + 1] = vertex + 1;
			data[index + 2] = vertex + 2;
			data[index + 3] = vertex + 2;
			data[index + 4] = vertex + 1;
			data[index + 5] = vertex + 3;

			index += 6;
			vertex += 4;
		}

		parent.__quadIndexBuffer = createIndexBuffer(__quadIndexBufferCount);
		parent.__quadIndexBuffer.uploadFromTypedArray(data);

		__setViewId(0);
	}

	public function clear(red:Float = 0, green:Float = 0, blue:Float = 0, alpha:Float = 1, depth:Float = 1, stencil:UInt = 0,
			mask:UInt = Context3DClearMask.ALL):Void
	{
		__clear(false, red, green, blue, alpha, depth, stencil, mask);
	}

	@:noCompletion private function __clear(useScissor:Bool, red:Float = 0, green:Float = 0, blue:Float = 0, alpha:Float = 1, depth:Float = 1,
			stencil:UInt = 0, mask:UInt = Context3DClearMask.ALL)
	{
		var flags = 0;
		if (mask & Context3DClearMask.COLOR != 0) flags |= bgfx.CLEAR_COLOR;
		if (mask & Context3DClearMask.DEPTH != 0) flags |= bgfx.CLEAR_DEPTH;
		if (mask & Context3DClearMask.STENCIL != 0) flags |= bgfx.CLEAR_STENCIL;

		var rgba = (Std.int(red * 255) << 24) | (Std.int(green * 255) << 16) | (Std.int(blue * 255) << 8) | Std.int(alpha * 255);

		bgfx.setViewClear(__currentViewId, flags, rgba, depth, stencil);

		if (flags != 0 && parent.__state.renderToTexture != null)
		{
			__pendingRTTClearTarget = parent.__state.renderToTexture;
			__pendingRTTClearFlags = flags;
			__pendingRTTClearRgba = rgba;
			__pendingRTTClearDepth = depth;
			__pendingRTTClearStencil = stencil;
		}

		if (mask & Context3DClearMask.COLOR != 0 && parent.__state.renderToTexture == null)
		{
			if (parent.__stage.context3D == parent && parent.__stage.__renderer != null && !parent.__stage.__renderer.__cleared)
				parent.__stage.__renderer.__cleared = true;
			parent.__cleared = true;
		}
	}

	@:noCompletion private function __setViewId(id:Int = 0)
	{
		__currentViewId = id;
		bgfx.setViewMode(id, SEQUENTIAL);
	}

	// need to make this get the number from bgfx directly instead of hardcodin it
	@:noCompletion private static inline var __maxViews:Int = 1024;

	@:noCompletion private inline function __getFreeViewID():Int
	{
		if (__nextViewId >= __maxViews - 1) return __maxViews - 1;
		return __nextViewId++;
	}

	public function configureBackBuffer(width:Int, height:Int, antiAlias:Int, enableDepthAndStencil:Bool = true, wantsBestResolution:Bool = false,
			wantsBestResolutionOnBrowserZoom:Bool = false):Void
	{
		#if !openfl_dpi_aware
		if (wantsBestResolution)
		{
			width = Std.int(width * parent.__stage.window.scale);
			height = Std.int(height * parent.__stage.window.scale);
		}
		#end

		__backBufferAntiAlias = antiAlias;
		parent.__state.backBufferEnableDepthAndStencil = enableDepthAndStencil;
		parent.__backBufferWantsBestResolution = wantsBestResolution;
		__backBufferWantsBestResolutionOnBrowserZoom = wantsBestResolutionOnBrowserZoom;

		if (__stage3D == null)
		{
			if (__backBufferTexture == null || parent.backBufferWidth != width || parent.backBufferHeight != height)
			{
				parent.backBufferWidth = width;
				parent.backBufferHeight = height;

				// if (__backBufferTexture != null) __backBufferTexture.dispose();

				// __backBufferTexture = createRectangleTexture(width, height, BGRA, true);

				// __state.__primaryBGFXFramebuffer = __backBufferTexture.__getFramebuffer(enableDepthAndStencil, antiAlias, 0);

				// bgfx.setViewFrameBuffer(__currentViewId, __state.__primaryBGFXFramebuffer);
				bgfx.setViewRect(__currentViewId, 0, 0, width, height);
			}
		}
		else
		{
			if (__backBufferTexture == null || parent.backBufferWidth != width || parent.backBufferHeight != height)
			{
				if (__backBufferTexture != null) __backBufferTexture.dispose();
				if (__frontBufferTexture != null) __frontBufferTexture.dispose();

				__backBufferTexture = createRectangleTexture(width, height, BGRA, true);
				__frontBufferTexture = createRectangleTexture(width, height, BGRA, true);

				if (__stage3D.__vertexBuffer == null)
				{
					__stage3D.__vertexBuffer = createVertexBuffer(4, 5);
				}

				#if openfl_dpi_aware
				var scaledWidth = width;
				var scaledHeight = height;
				#else
				var scaledWidth = wantsBestResolution ? width : Std.int(width * parent.__stage.window.scale);
				var scaledHeight = wantsBestResolution ? height : Std.int(height * parent.__stage.window.scale);
				#end
				var vertexData:Array<Float> = [
					scaledWidth,
					scaledHeight,
					0.0,
					1.0,
					1.0,
					0.0,
					scaledHeight,
					0.0,
					0.0,
					1.0,
					scaledWidth,
					0.0,
					0.0,
					1.0,
					0.0,
					0.0,
					0.0,
					0.0,
					0.0,
					0.0
				];

				__stage3D.__vertexBuffer.uploadFromArray(vertexData, 0, 20);

				if (__stage3D.__indexBuffer == null)
				{
					__stage3D.__indexBuffer = createIndexBuffer(6);

					var indexData:Array<UInt> = [0, 1, 2, 2, 1, 3];

					__stage3D.__indexBuffer.uploadFromArray(indexData, 0, 6);
				}
			}

			parent.backBufferWidth = width;
			parent.backBufferHeight = height;

			__backBufferAntiAlias = antiAlias;
			parent.__state.backBufferEnableDepthAndStencil = enableDepthAndStencil;
			parent.__backBufferWantsBestResolution = wantsBestResolution;
			__backBufferWantsBestResolutionOnBrowserZoom = wantsBestResolutionOnBrowserZoom;
			parent.__state.__primaryBGFXFramebuffer = __backBufferTexture.__getFramebuffer(enableDepthAndStencil, antiAlias, 0);
			__frontBufferTexture.__getFramebuffer(enableDepthAndStencil, antiAlias, 0);

			bgfx.setViewFrameBuffer(__currentViewId, parent.__state.__primaryBGFXFramebuffer);
			bgfx.setViewRect(__currentViewId, 0, 0, width, height);
		}
	}

	@:noCompletion private var __glDepthStencilFormat(get, never):Int;

	@:noCompletion private inline function get___glDepthStencilFormat():Int
		return 0;

	@:noCompletion private var __bgfxDepthFormat(get, never):Int;

	@:noCompletion private inline function get___bgfxDepthFormat():Int
		return __getSupportedDepth();

	@:noCompletion private static function __getSupportedDepth():BGFXTextureFormat
	{
		if (__supportedDepth != null) return __supportedDepth;

		var formats = [D24S8, D32F, D24, D16];
		for (format in formats)
			if (BGFX.isTextureValid(0, false, 1, format, BGFX.TEXTURE_RT_WRITE_ONLY)) return __supportedDepth = format;

		return D24S8;
	}

	public function createCubeTexture(size:Int, format:Context3DTextureFormat, optimizeForRenderToTexture:Bool, streamingLevels:Int = 0):CubeTexture
	{
		return new CubeTexture(parent, size, format, optimizeForRenderToTexture, streamingLevels);
	}

	public function createIndexBuffer(numIndices:Int, bufferUsage:Context3DBufferUsage = STATIC_DRAW):IndexBuffer3D
	{
		return new IndexBuffer3D(parent, numIndices, bufferUsage);
	}

	public function createProgram(format:Context3DProgramFormat = AGAL):Program3D
	{
		return new Program3D(parent, format);
	}

	public function createRectangleTexture(width:Int, height:Int, format:Context3DTextureFormat, optimizeForRenderToTexture:Bool):RectangleTexture
	{
		return new RectangleTexture(parent, width, height, format, optimizeForRenderToTexture);
	}

	public function createTexture(width:Int, height:Int, format:Context3DTextureFormat, optimizeForRenderToTexture:Bool, streamingLevels:Int = 0):Texture
	{
		return new Texture(parent, width, height, format, optimizeForRenderToTexture, streamingLevels);
	}

	public function isASTCSupported():Bool
	{
		if (ASTCTexture.__astcCompressedTexturesSupported == null)
		{
			// Use 4x4 as an example since there's no general ASTC format
			var astcFormat = bgfx.getCaps().formats[ASTC4x4];

			// There's also CAPS_FORMAT_TEXTURE_2D_EMULATED but i don't know if it would still retain the benifits of ASTC
			ASTCTexture.__astcCompressedTexturesSupported = (astcFormat & bgfx.CAPS_FORMAT_TEXTURE_2D) != 0;
		}

		return ASTCTexture.__astcCompressedTexturesSupported == true;
	}

	public function createASTCTexture(data:ByteArray):ASTCTexture
	{
		return new ASTCTexture(parent, data);
	}

	public function isS3TCSupported():Bool
	{
		if (S3TCTexture.__s3tcCompressedTexturesSupported == null)
		{
			// BC1 stands in for the whole S3TC family; BC2/BC3 are validated per-texture
			var bc1Format = bgfx.getCaps().formats[BC1];

			S3TCTexture.__s3tcCompressedTexturesSupported = (bc1Format & bgfx.CAPS_FORMAT_TEXTURE_2D) != 0;
		}

		return S3TCTexture.__s3tcCompressedTexturesSupported == true;
	}

	public function createS3TCTexture(data:ByteArray):S3TCTexture
	{
		return new S3TCTexture(parent, data);
	}

	public function createMultiBufferTexture(width:Int, height:Int, formats:Array<Context3DTextureFormat>):MultiBufferTexture
	{
		return new MultiBufferTexture(parent, width, height, formats);
	}

	public function createVertexBuffer(numVertices:Int, data32PerVertex:Int, bufferUsage:Context3DBufferUsage = STATIC_DRAW):VertexBuffer3D
	{
		return new VertexBuffer3D(parent, numVertices, data32PerVertex, bufferUsage);
	}

	public function createVideoTexture():VideoTexture
	{
		// 	return new VideoTexture(parent);
		throw new Error("Video textures are not supported on this backend (yet)");
	}

	public function dispose(recreate:Bool = true):Void
	{
		// TODO: Dispose all related buffers

		bgfx = null;
		__dispose();
	}

	public function drawToBitmapData(destination:BitmapData, srcRect:Rectangle = null, destPoint:Point = null):Void
	{
		#if lime
		// don wanna do ts :(((((
		// TODO: doesn't seem to be used so it's low priority.
		// if (destination == null) return;

		// var sourceRect = srcRect != null ? srcRect.__toLimeRectangle() : new LimeRectangle(0, 0, backBufferWidth, backBufferHeight);
		// var destVector = destPoint != null ? destPoint.__toLimeVector2() : new Vector2();

		// if (__stage.context3D == this)
		// {
		// 	if (__stage.window != null)
		// 	{
		// 		if (__stage3D != null)
		// 		{
		// 			destVector.setTo(Std.int(-__stage3D.x), Std.int(-__stage3D.y));
		// 		}

		// 		var image = __stage.window.readPixels();
		// 		destination.image.copyPixels(image, sourceRect, destVector);
		// 	}
		// }
		// else if (__backBufferTexture != null)
		// {
		// 	#if openfl_bgfx_experimental_blitting
		// 	// TODO blit the back buffer into a new texture instead of copying it to an image buffer
		// 	// Instead of copying it to an image buffer
		// 	#else
		// 	#end
		// 	var cacheRenderToTexture = __state.renderToTexture;
		// 	setRenderToBackBuffer();

		// 	// __flushGLFramebuffer();
		// 	// __flushViewport();

		// 	// TODO: Read less pixels if srcRect is smaller

		// 	var data = new UInt8Array(backBufferWidth * backBufferHeight * 4);
		// 	gl.readPixels(0, 0, backBufferWidth, backBufferHeight, __backBufferTexture.__format, gl.UNSIGNED_BYTE, data);

		// 	var image = new Image(new ImageBuffer(data, backBufferWidth, backBufferHeight, 32, BGRA32));
		// 	destination.image.copyPixels(image, sourceRect, destVector);

		// 	if (cacheRenderToTexture != null)
		// 	{
		// 		setRenderToTexture(cacheRenderToTexture, __state.renderToTextureDepthStencil, __state.renderToTextureAntiAlias,
		// 			__state.renderToTextureSurfaceSelector);
		// 	}
		// }
		#end
	}

	public function drawTriangles(indexBuffer:IndexBuffer3D, firstIndex:Int = 0, numTriangles:Int = -1):Void
	{
		if (parent.__state.program == null || parent.__state.program.__shaderProgram == null || __activeVertexBuffer == null) return;

		if (parent.__state.renderToTexture == null)
		{
			if (parent.__stage.context3D == parent && parent.__stage.__renderer != null && !parent.__stage.__renderer.__cleared)
				parent.__stage.__renderer.__clear();
			if (!parent.__cleared) clear(0, 0, 0, 0, 1, 0, Context3DClearMask.COLOR);
		}

		var count = (numTriangles == -1) ? indexBuffer.__numIndices : (numTriangles * 3);

		__activeVertexBuffer.__buildLayoutQueue();
		__activeVertexBuffer.__updateLayout(null);

		switch (indexBuffer.__idbh)
		{
			case Static(ib):
				bgfx.setIndexBufferIndices(ib, firstIndex, count);
			case Dynamic(ib):
				bgfx.setDynamicIndexBufferIndices(ib, firstIndex, count);
		}

		__flush();

		bgfx.setState(__buildState(), 0);

		bgfx.submit(__currentViewId, parent.__state.program.__shaderProgram, 0, bgfx.DISCARD_STATE | bgfx.DISCARD_INDEX_BUFFER);
		__activeVertexBuffer = null;
	}

	private function __buildState():Int64
	{
		var state:Int64 = Int64.make(0, 0);

		if (parent.__state.colorMaskRed) state |= bgfx.STATE_WRITE_R;
		if (parent.__state.colorMaskGreen) state |= bgfx.STATE_WRITE_G;
		if (parent.__state.colorMaskBlue) state |= bgfx.STATE_WRITE_B;
		if (parent.__state.colorMaskAlpha) state |= bgfx.STATE_WRITE_A;

		if (parent.__state.backBufferEnableDepthAndStencil)
		{
			if (parent.__state.depthMask) state |= bgfx.STATE_WRITE_Z;

			switch (parent.__state.depthCompareMode)
			{
				case ALWAYS:
					state |= bgfx.STATE_DEPTH_TEST_ALWAYS;
				case EQUAL:
					state |= bgfx.STATE_DEPTH_TEST_EQUAL;
				case GREATER:
					state |= bgfx.STATE_DEPTH_TEST_GREATER;
				case GREATER_EQUAL:
					state |= bgfx.STATE_DEPTH_TEST_GEQUAL;
				case LESS:
					state |= bgfx.STATE_DEPTH_TEST_LESS;
				case LESS_EQUAL:
					state |= bgfx.STATE_DEPTH_TEST_LEQUAL;
				case NEVER:
					state |= bgfx.STATE_DEPTH_TEST_NEVER;
				case NOT_EQUAL:
					state |= bgfx.STATE_DEPTH_TEST_NOTEQUAL;
			}
		}

		if (parent.__state.culling != NONE)
		{
			var flipped = parent.__state.renderToTexture == null;
			switch (parent.__state.culling)
			{
				case BACK:
					state |= flipped ? bgfx.STATE_CULL_CCW : bgfx.STATE_CULL_CW;
				case FRONT:
					state |= flipped ? bgfx.STATE_CULL_CW : bgfx.STATE_CULL_CCW;
				case FRONT_AND_BACK, NONE:
					state |= 0; // :(
			}
		}

		inline function contextBlendToBGFX(blend:Context3DBlendFactor):Int64
		{
			return switch (blend)
			{
				case DESTINATION_ALPHA:
					bgfx.STATE_BLEND_DST_ALPHA;
				case DESTINATION_COLOR:
					bgfx.STATE_BLEND_DST_COLOR;
				case ONE:
					bgfx.STATE_BLEND_ONE;
				case ONE_MINUS_DESTINATION_ALPHA:
					bgfx.STATE_BLEND_INV_DST_ALPHA;
				case ONE_MINUS_DESTINATION_COLOR:
					bgfx.STATE_BLEND_INV_DST_COLOR;
				case ONE_MINUS_SOURCE_ALPHA:
					bgfx.STATE_BLEND_INV_SRC_ALPHA;
				case ONE_MINUS_SOURCE_COLOR:
					bgfx.STATE_BLEND_INV_SRC_COLOR;
				case SOURCE_ALPHA:
					bgfx.STATE_BLEND_SRC_ALPHA;
				case SOURCE_COLOR:
					bgfx.STATE_BLEND_SRC_COLOR;
				case ZERO:
					bgfx.STATE_BLEND_ZERO;
				default: 0;
			}
		}
		state |= bgfx.blendFuncSeparate(contextBlendToBGFX(parent.__state.blendSourceRGBFactor), contextBlendToBGFX(parent.__state.blendDestinationRGBFactor),
			contextBlendToBGFX(parent.__state.blendSourceAlphaFactor), contextBlendToBGFX(parent.__state.blendDestinationAlphaFactor));

		return state;
	}

	public function present():Void
	{
		// setRenderToBackBuffer();

		if (__stage3D != null && __backBufferTexture != null)
		{
			if (!parent.__cleared)
			{
				// Make sure texture is initialized
				// TODO: Throw error if error reporting is enabled?
				clear(0, 0, 0, 0, 1, 0, Context3DClearMask.COLOR);
			}

			// 	var cacheBuffer = __backBufferTexture;
			// 	__backBufferTexture = __frontBufferTexture;
			// 	__frontBufferTexture = cacheBuffer;

			// 	__state.__primaryBGFXFramebuffer = __backBufferTexture.__getFramebuffer(__state.backBufferEnableDepthAndStencil, __backBufferAntiAlias, 0);
			parent.__cleared = false;
		}

		if (parent.__state.renderToTexture == null)
		{
			bgfx.frame(0);

			setTextures = [];
			parent.__frameId++;

			if (parent.__buffersReset.length > 0)
			{
				for (reset in parent.__buffersReset)
					reset();
				parent.__buffersReset = [];
			}

			__currentViewId = 0;
			__nextViewId = 1;

			__pendingRTTClearTarget = null;
		}

		parent.__present = true;
	}

	public function setBlendFactors(sourceFactor:Context3DBlendFactor, destinationFactor:Context3DBlendFactor):Void
	{
		setBlendFactorsSeparate(sourceFactor, destinationFactor, sourceFactor, destinationFactor);
	}

	@:dox(hide) @:noCompletion private function setBlendFactorsSeparate(sourceRGBFactor:Context3DBlendFactor, destinationRGBFactor:Context3DBlendFactor,
			sourceAlphaFactor:Context3DBlendFactor, destinationAlphaFactor:Context3DBlendFactor):Void
	{
		parent.__state.blendSourceRGBFactor = sourceRGBFactor;
		parent.__state.blendDestinationRGBFactor = destinationRGBFactor;
		parent.__state.blendSourceAlphaFactor = sourceAlphaFactor;
		parent.__state.blendDestinationAlphaFactor = destinationAlphaFactor;
	}

	public function setColorMask(red:Bool, green:Bool, blue:Bool, alpha:Bool):Void
	{
		parent.__state.colorMaskRed = red;
		parent.__state.colorMaskGreen = green;
		parent.__state.colorMaskBlue = blue;
		parent.__state.colorMaskAlpha = alpha;
	}

	public function setCulling(triangleFaceToCull:Context3DTriangleFace):Void
	{
		parent.__state.culling = triangleFaceToCull;
	}

	public function setDepthTest(depthMask:Bool, passCompareMode:Context3DCompareMode):Void
	{
		parent.__state.depthMask = depthMask;
		parent.__state.depthCompareMode = passCompareMode;
	}

	public function setProgram(program:Program3D):Void
	{
		parent.__state.program = program;
		parent.__state.shader = null; // TODO: Merge this logic

		if (program != null)
		{
			for (i in 0...program.__samplerStates.length)
			{
				if (parent.__state.samplerStates[i] == null)
				{
					parent.__state.samplerStates[i] = program.__samplerStates[i].clone();
				}
				else
				{
					parent.__state.samplerStates[i].copyFrom(program.__samplerStates[i]);
				}
			}
		}
	}

	public function setProgramConstantsFromByteArray(programType:Context3DProgramType, firstRegister:Int, numRegisters:Int, data:ByteArray,
			byteArrayOffset:UInt):Void
	{
		#if lime
		if (numRegisters == 0 || parent.__state.program == null) return;

		if (parent.__state.program != null && parent.__state.program.__format == GLSL)
		{
			// TODO
		}
		else
		{
			// TODO: Cleanup?

			if (numRegisters == -1)
			{
				numRegisters = ((data.length >> 2) - byteArrayOffset);
			}

			var isVertex = (programType == VERTEX);
			var dest = isVertex ? parent.__vertexConstants : parent.__fragmentConstants;

			var floatData = Float32Array.fromBytes(data, 0);
			var outOffset = firstRegister * 4;
			var inOffset = Std.int(byteArrayOffset / 4);

			for (i in 0...(numRegisters * 4))
			{
				dest[outOffset + i] = floatData[inOffset + i];
			}

			if (parent.__state.program != null)
			{
				parent.__state.program.__markDirty(isVertex, firstRegister, numRegisters);
			}
		}
		#end
	}

	public function setProgramConstantsFromMatrix(programType:Context3DProgramType, firstRegister:Int, matrix:Matrix3D, transposedMatrix:Bool = false):Void
	{
		#if lime
		if (parent.__state.program != null && parent.__state.program.__format == GLSL)
		{
			__flushProgram();

			// TODO: Cache value, prevent need to copy
			var data = new Float32Array(16);
			for (i in 0...16)
			{
				data[i] = matrix.rawData[i];
			}

			gl.uniformMatrix4fv(cast firstRegister, transposedMatrix, data);
		}
		else
		{
			var isVertex = (programType == VERTEX);
			var dest = isVertex ? parent.__vertexConstants : parent.__fragmentConstants;
			var source = matrix.rawData;
			var i = firstRegister * 4;

			if (transposedMatrix)
			{
				dest[i++] = source[0];
				dest[i++] = source[4];
				dest[i++] = source[8];
				dest[i++] = source[12];

				dest[i++] = source[1];
				dest[i++] = source[5];
				dest[i++] = source[9];
				dest[i++] = source[13];

				dest[i++] = source[2];
				dest[i++] = source[6];
				dest[i++] = source[10];
				dest[i++] = source[14];

				dest[i++] = source[3];
				dest[i++] = source[7];
				dest[i++] = source[11];
				dest[i++] = source[15];
			}
			else
			{
				dest[i++] = source[0];
				dest[i++] = source[1];
				dest[i++] = source[2];
				dest[i++] = source[3];

				dest[i++] = source[4];
				dest[i++] = source[5];
				dest[i++] = source[6];
				dest[i++] = source[7];

				dest[i++] = source[8];
				dest[i++] = source[9];
				dest[i++] = source[10];
				dest[i++] = source[11];

				dest[i++] = source[12];
				dest[i++] = source[13];
				dest[i++] = source[14];
				dest[i++] = source[15];
			}

			if (parent.__state.program != null)
			{
				parent.__state.program.__markDirty(isVertex, firstRegister, 4);
			}
		}
		#end
	}

	public function setProgramConstantsFromVector(programType:Context3DProgramType, firstRegister:Int, data:Vector<Float>, numRegisters:Int = -1):Void
	{
		if (numRegisters == 0) return;

		if (parent.__state.program != null && parent.__state.program.__format == GLSL) {}
		else
		{
			if (numRegisters == -1)
			{
				numRegisters = (data.length >> 2);
			}

			var isVertex = (programType == VERTEX);
			var dest = isVertex ? parent.__vertexConstants : parent.__fragmentConstants;
			var source = data;

			var sourceIndex = 0;
			var destIndex = firstRegister * 4;

			for (i in 0...numRegisters)
			{
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
			}

			if (parent.__state.program != null)
			{
				parent.__state.program.__markDirty(isVertex, firstRegister, numRegisters);
			}
		}
	}

	public function setProgramConstantsFromArray(programType:Context3DProgramType, firstRegister:Int, data:Array<Float>, numRegisters:Int = -1):Void
	{
		if (numRegisters == 0) return;

		if (parent.__state.program != null && parent.__state.program.__format == GLSL) {}
		else
		{
			if (numRegisters == -1)
			{
				numRegisters = (data.length >> 2);
			}

			var isVertex = (programType == VERTEX);
			var dest = isVertex ? parent.__vertexConstants : parent.__fragmentConstants;
			var source = data;

			var sourceIndex = 0;
			var destIndex = firstRegister * 4;

			for (i in 0...numRegisters)
			{
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
				dest[destIndex++] = source[sourceIndex++];
			}

			if (parent.__state.program != null)
			{
				parent.__state.program.__markDirty(isVertex, firstRegister, numRegisters);
			}
		}
	}

	public function setRenderToBackBuffer():Void
	{
		parent.__state.renderToTexture = null;

		__setViewId(__getFreeViewID());
		bgfx.setViewFrameBuffer(__currentViewId, null);
		bgfx.setViewClear(__currentViewId, 0, 0, 1.0, 0);
	}

	public function setRenderToTexture(texture:TextureBase, enableDepthAndStencil:Bool = false, antiAlias:Int = 0, surfaceSelector:Int = 0):Void
	{
		parent.__state.renderToTexture = texture;
		parent.__state.renderToTextureDepthStencil = enableDepthAndStencil;
		parent.__state.renderToTextureAntiAlias = antiAlias;
		parent.__state.renderToTextureSurfaceSelector = surfaceSelector;

		__setViewId(__getFreeViewID());
		bgfx.setViewFrameBuffer(__currentViewId, texture.__getFramebuffer(enableDepthAndStencil, antiAlias, surfaceSelector));
		bgfx.setViewClear(__currentViewId, 0, 0, 1.0, 0);

		if (__pendingRTTClearTarget != null && texture == __pendingRTTClearTarget)
		{
			bgfx.setViewClear(__currentViewId, __pendingRTTClearFlags, __pendingRTTClearRgba, __pendingRTTClearDepth, __pendingRTTClearStencil);
			__pendingRTTClearTarget = null;
		}
	}

	public function setSamplerStateAt(sampler:Int, wrap:Context3DWrapMode, filter:Context3DTextureFilter, mipfilter:Context3DMipFilter):Void
	{
		// if (sampler < 0 || sampler > Context3D.MAX_SAMPLERS) {

		// 	throw new Error ("sampler out of range");

		// }

		if (parent.__state.samplerStates[sampler] == null)
		{
			parent.__state.samplerStates[sampler] = new SamplerState();
		}

		var state = parent.__state.samplerStates[sampler];
		state.wrap = wrap;
		state.filter = filter;
		state.mipfilter = mipfilter;
	}

	public function setScissorRectangle(rectangle:Rectangle):Void
	{
		if (rectangle != null)
		{
			parent.__state.scissorEnabled = true;
			parent.__state.scissorRectangle.copyFrom(rectangle);
		}
		else
		{
			parent.__state.scissorEnabled = false;
		}
	}

	public function setStencilActions(triangleFace:Context3DTriangleFace = FRONT_AND_BACK, compareMode:Context3DCompareMode = ALWAYS,
			actionOnBothPass:Context3DStencilAction = KEEP, actionOnDepthFail:Context3DStencilAction = KEEP,
			actionOnDepthPassStencilFail:Context3DStencilAction = KEEP):Void
	{
		parent.__state.stencilTriangleFace = triangleFace;
		parent.__state.stencilCompareMode = compareMode;
		parent.__state.stencilPass = actionOnBothPass;
		parent.__state.stencilDepthFail = actionOnDepthFail;
		parent.__state.stencilFail = actionOnDepthPassStencilFail;
	}

	public function setStencilReferenceValue(referenceValue:UInt, readMask:UInt = 0xFF, writeMask:UInt = 0xFF):Void
	{
		parent.__state.stencilReferenceValue = referenceValue;
		parent.__state.stencilReadMask = readMask;
		parent.__state.stencilWriteMask = writeMask;
	}

	public function setTextureAt(sampler:Int, texture:TextureBase):Void
	{
		parent.__state.textures[sampler] = texture;
	}

	public function setVertexBufferAt(index:Int, buffer:VertexBuffer3D, bufferOffset:Int = 0, format:Context3DVertexBufferFormat = FLOAT_4):Void
	{
		if (buffer == null || (__activeVertexBuffer != null && __activeVertexBuffer != buffer)) return;

		__activeVertexBuffer = buffer;

		switch (format)
		{
			case BYTES_4:
				buffer.__queueLayout(index, {
					type: UINT8,
					num: 4,
					asInt: false,
					normalized: true
				}, bufferOffset);

			case FLOAT_4:
				buffer.__queueLayout(index, {
					type: FLOAT,
					num: 4,
					asInt: false,
					normalized: false
				}, bufferOffset);

			case FLOAT_3:
				buffer.__queueLayout(index, {
					type: FLOAT,
					num: 3,
					asInt: false,
					normalized: false
				}, bufferOffset);

			case FLOAT_2:
				buffer.__queueLayout(index, {
					type: FLOAT,
					num: 2,
					asInt: false,
					normalized: false
				}, bufferOffset);

			case FLOAT_1:
				buffer.__queueLayout(index, {
					type: FLOAT,
					num: 1,
					asInt: false,
					normalized: false
				}, bufferOffset);

			default:
				throw new IllegalOperationError();
		}
	}

	@:noCompletion private function __bindGLArrayBuffer(buffer:Dynamic):Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __bindGLElementArrayBuffer(buffer:Dynamic):Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __bindGLFramebuffer(framebuffer:Dynamic):Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __bindGLTexture2D(texture:Dynamic):Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __bindGLTextureCubeMap(texture:Dynamic):Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __dispose():Void
	{
		parent.driverInfo += " (Disposed)";

		if (__stage3D != null)
		{
			__stage3D.__indexBuffer = null;
			__stage3D.__vertexBuffer = null;
			__stage3D.context3D = null;
			__stage3D = null;
		}

		__backBufferTexture = null;
		parent.__context = null;
		__renderStage3DProgram = null;
		parent.__fragmentConstants = null;
		__frontBufferTexture = null;
		__positionScale = null;
		parent.__present = false;
		parent.__quadIndexBuffer = null;
		parent.__stage = null;
		parent.__vertexConstants = null;
	}

	@:noCompletion private function __drawTriangles(firstIndex:Int = 0, count:Int):Void
	{
		if (parent.__state.program == null || parent.__state.program.__shaderProgram == null || __activeVertexBuffer == null) return;

		if (parent.__state.renderToTexture == null)
		{
			if (parent.__stage.context3D == parent && parent.__stage.__renderer != null && !parent.__stage.__renderer.__cleared)
				parent.__stage.__renderer.__clear();
			if (!parent.__cleared) clear(0, 0, 0, 0, 1, 0, Context3DClearMask.COLOR);
		}

		__activeVertexBuffer.__buildLayoutQueue();
		__activeVertexBuffer.__updateLayout(count);

		__flush();

		bgfx.setState(__buildState(), 0);

		bgfx.submit(__currentViewId, parent.__state.program.__shaderProgram, 0, bgfx.DISCARD_INDEX_BUFFER);
		__activeVertexBuffer = null;
	}

	@:noCompletion private function __flush():Void
	{
		if (__pendingRTTClearTarget != null && parent.__state.renderToTexture == __pendingRTTClearTarget) __pendingRTTClearTarget = null;

		__flushViewport();
		__flushScissor();
		__flushStencil();
		__flushTextures();
	}

	@:noCompletion private function __flushGLBlend():Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private inline function __flushGLColor():Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __flushGLCulling():Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __flushGLDepth():Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __flushGLFramebuffer():Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __flushProgram():Void
	{
		// var shader = __state.shader;
		// var program = __state.program;

		// if (program != null && program.__format == AGAL)
		// {
		// 	__positionScale[1] = (__stage.context3D == this && __state.renderToTexture == null) ? 1.0 : -1.0;
		// 	program.__setPositionScale(__positionScale);
		// }
	}

	@:noCompletion private function __flushScissor():Void
	{
		if (!parent.__state.scissorEnabled) return;

		var scissorX = Std.int(parent.__state.scissorRectangle.x);
		var scissorY = Std.int(parent.__state.scissorRectangle.y);
		var scissorWidth = Std.int(parent.__state.scissorRectangle.width);
		var scissorHeight = Std.int(parent.__state.scissorRectangle.height);

		#if !openfl_dpi_aware
		if (parent.__backBufferWantsBestResolution)
		{
			scissorX = Std.int(parent.__state.scissorRectangle.x * parent.__stage.window.scale);
			scissorY = Std.int(parent.__state.scissorRectangle.y * parent.__stage.window.scale);
			scissorWidth = Std.int(parent.__state.scissorRectangle.width * parent.__stage.window.scale);
			scissorHeight = Std.int(parent.__state.scissorRectangle.height * parent.__stage.window.scale);
		}
		#end

		bgfx.setScissor(scissorX, scissorY, scissorWidth, scissorHeight);
	}

	@:noCompletion private function __flushStencil():Void
	{
		// NOTE: OpenFL used glStencilMask(0xFF/0) on GL
		// BGFX does not expose any stencil mask functionality
		// Must make sure this doesn't cause any trouble

		if (parent.__state.stencilCompareMode == NEVER)
		{
			bgfx.setStencil(bgfx.STENCIL_NONE, bgfx.STENCIL_NONE);
			return;
		}

		var stencil:Int = bgfx.STENCIL_NONE;

		stencil |= __getStencilCompareMode(parent.__state.stencilCompareMode);
		stencil |= bgfx.stencilFuncRef(parent.__state.stencilReferenceValue);
		stencil |= bgfx.stencilFuncRmask(parent.__state.stencilReadMask);

		stencil |= __getBGFXStencilOpFailS(parent.__state.stencilFail);
		stencil |= __getBGFXStencilOpFailZ(parent.__state.stencilDepthFail);
		stencil |= __getBGFXStencilOpPassZ(parent.__state.stencilPass);

		switch (parent.__state.stencilTriangleFace)
		{
			case BACK:
				bgfx.setStencil(bgfx.STENCIL_NONE, stencil);
			case FRONT:
				bgfx.setStencil(stencil, bgfx.STENCIL_NONE);
			case FRONT_AND_BACK:
				bgfx.setStencil(stencil, stencil);
			default:
				bgfx.setStencil(bgfx.STENCIL_NONE, bgfx.STENCIL_NONE);
		}
	}

	@:noCompletion
	private var setTextures:Array<TextureBase> = [];

	@:noCompletion private function __flushTextures():Void
	{
		for (u in parent.__state.program.__bgfxSamplers)
		{
			var texture = parent.__state.textures[u.samplerID];
			if (texture == null || setTextures[u.samplerID] == texture) continue;

			setTextures[u.samplerID] = texture;
			texture.__setSamplerState(parent.__state.samplerStates[u.samplerID]);
			bgfx.setTexture(u.samplerID, u.uniform, texture.__textureID, texture.__samplerStateFlags);
		}
	}

	@:noCompletion private function __flushViewport():Void
	{
		// TODO: Cache

		if (parent.__state.renderToTexture == null)
		{
			if (parent.__stage.context3D == parent)
			{
				var scaledBackBufferWidth = parent.backBufferWidth;
				var scaledBackBufferHeight = parent.backBufferHeight;
				#if !openfl_dpi_aware
				if (__stage3D == null && !parent.__backBufferWantsBestResolution)
				{
					scaledBackBufferWidth = Std.int(parent.backBufferWidth * parent.__stage.window.scale);
					scaledBackBufferHeight = Std.int(parent.backBufferHeight * parent.__stage.window.scale);
				}
				#end
				var x = __stage3D == null ? 0 : Std.int(__stage3D.x);
				var y = Std.int((parent.__stage.window.height * parent.__stage.window.scale) - scaledBackBufferHeight - (__stage3D == null ? 0 : __stage3D.y));
				bgfx.setViewRect(__currentViewId, x, y, scaledBackBufferWidth, scaledBackBufferHeight);
			}
			else
			{
				bgfx.setViewRect(__currentViewId, 0, 0, parent.backBufferWidth, parent.backBufferHeight);
			}
		}
		else
		{
			var width = 0, height = 0;

			// TODO: Avoid use of Std.is
			if ((parent.__state.renderToTexture is Texture))
			{
				var texture2D:Texture = cast parent.__state.renderToTexture;
				width = texture2D.__width;
				height = texture2D.__height;
			}
			else if ((parent.__state.renderToTexture is RectangleTexture))
			{
				var rectTexture:RectangleTexture = cast parent.__state.renderToTexture;
				width = rectTexture.__width;
				height = rectTexture.__height;
			}
			else if ((parent.__state.renderToTexture is CubeTexture))
			{
				var cubeTexture:CubeTexture = cast parent.__state.renderToTexture;
				width = cubeTexture.__size;
				height = cubeTexture.__size;
			}

			bgfx.setViewRect(__currentViewId, 0, 0, width, height);
		}
	}

	@:noCompletion private function __getGLBlend(blendFactor:Context3DBlendFactor):Int
	{
		// bgfx blends are int64 so can't have a global function for these stuff :/

		return 0;
	}

	@:noCompletion private function __getGLCompareMode(mode:Context3DCompareMode):Int
	{
		// bgfx depth tests are int64 so can't have a global function for these stuff :/

		return 0;
	}

	@:noCompletion private function __getGLStencilAction(action:Context3DStencilAction):Int
	{
		// bgfx needs multiple methods for different types of stencil results

		return 0;
	}

	@:noCompletion private function __getBGFXStencilOpFailS(action:Context3DStencilAction):Int
	{
		return switch (action)
		{
			case DECREMENT_SATURATE: bgfx.STENCIL_OP_FAIL_S_DECRSAT;
			case DECREMENT_WRAP: bgfx.STENCIL_OP_FAIL_S_DECR;
			case INCREMENT_SATURATE: bgfx.STENCIL_OP_FAIL_S_INCRSAT;
			case INCREMENT_WRAP: bgfx.STENCIL_OP_FAIL_S_INCR;
			case INVERT: bgfx.STENCIL_OP_FAIL_S_INVERT;
			case KEEP: bgfx.STENCIL_OP_FAIL_S_KEEP;
			case SET: bgfx.STENCIL_OP_FAIL_S_REPLACE;
			case ZERO: bgfx.STENCIL_OP_FAIL_S_ZERO;
			default: bgfx.STENCIL_OP_FAIL_S_KEEP;
		}
	}

	@:noCompletion private function __getBGFXStencilOpFailZ(action:Context3DStencilAction):Int
	{
		return switch (action)
		{
			case DECREMENT_SATURATE: bgfx.STENCIL_OP_FAIL_Z_DECRSAT;
			case DECREMENT_WRAP: bgfx.STENCIL_OP_FAIL_Z_DECR;
			case INCREMENT_SATURATE: bgfx.STENCIL_OP_FAIL_Z_INCRSAT;
			case INCREMENT_WRAP: bgfx.STENCIL_OP_FAIL_Z_INCR;
			case INVERT: bgfx.STENCIL_OP_FAIL_Z_INVERT;
			case KEEP: bgfx.STENCIL_OP_FAIL_Z_KEEP;
			case SET: bgfx.STENCIL_OP_FAIL_Z_REPLACE;
			case ZERO: bgfx.STENCIL_OP_FAIL_Z_ZERO;
			default: bgfx.STENCIL_OP_FAIL_Z_KEEP;
		}
	}

	@:noCompletion private function __getBGFXStencilOpPassZ(action:Context3DStencilAction):Int
	{
		return switch (action)
		{
			case DECREMENT_SATURATE: bgfx.STENCIL_OP_PASS_Z_DECRSAT;
			case DECREMENT_WRAP: bgfx.STENCIL_OP_PASS_Z_DECR;
			case INCREMENT_SATURATE: bgfx.STENCIL_OP_PASS_Z_INCRSAT;
			case INCREMENT_WRAP: bgfx.STENCIL_OP_PASS_Z_INCR;
			case INVERT: bgfx.STENCIL_OP_PASS_Z_INVERT;
			case KEEP: bgfx.STENCIL_OP_PASS_Z_KEEP;
			case SET: bgfx.STENCIL_OP_PASS_Z_REPLACE;
			case ZERO: bgfx.STENCIL_OP_PASS_Z_ZERO;
			default: bgfx.STENCIL_OP_PASS_Z_KEEP;
		}
	}

	@:noCompletion private function __getStencilCompareMode(cmp:Context3DCompareMode):Int
	{
		return switch (cmp)
		{
			case ALWAYS:
				bgfx.STENCIL_TEST_ALWAYS;
			case EQUAL:
				bgfx.STENCIL_TEST_EQUAL;
			case GREATER:
				bgfx.STENCIL_TEST_GREATER;
			case GREATER_EQUAL:
				bgfx.STENCIL_TEST_GEQUAL;
			case LESS:
				bgfx.STENCIL_TEST_LESS;
			case LESS_EQUAL:
				bgfx.STENCIL_TEST_LEQUAL;
			case NEVER:
				bgfx.STENCIL_TEST_NEVER;
			case NOT_EQUAL:
				bgfx.STENCIL_TEST_NOTEQUAL;
		}
	}

	@:noCompletion private function __getGLTriangleFace(face:Context3DTriangleFace):Int
	{
		// bgfx culling is int64 so can't have a global function for these stuff :/
		return 0;
	}

	@:noCompletion private function __renderStage3D(stage3D:Stage3D):Void
	{
		// Assume this is the primary Context3D

		var context = stage3D.context3D;

		if (context != null
			&& context != parent
			&& context.__backend.__frontBufferTexture != null
			&& stage3D.visible
			&& parent.backBufferHeight > 0
			&& parent.backBufferWidth > 0)
		{
			// if (!__stage.__renderer.__cleared) __stage.__renderer.__clear ();

			if (__renderStage3DProgram == null)
			{
				var vertexAssembler = new AGALMiniAssembler();
				vertexAssembler.assemble(Context3DProgramType.VERTEX, "m44 op, va0, vc0\n" + "mov v0, va1");

				var fragmentAssembler = new AGALMiniAssembler();
				fragmentAssembler.assemble(Context3DProgramType.FRAGMENT, "tex ft1, v0, fs0 <2d,nearest,nomip>\n" + "mov oc, ft1");

				__renderStage3DProgram = createProgram();
				__renderStage3DProgram.upload(vertexAssembler.agalcode, fragmentAssembler.agalcode);
			}

			setProgram(__renderStage3DProgram);

			setBlendFactors(ONE, ZERO);
			setColorMask(true, true, true, true);
			setCulling(NONE);
			setDepthTest(false, ALWAYS);
			setStencilActions();
			setStencilReferenceValue(0, 0, 0);
			setScissorRectangle(null);

			setTextureAt(0, context.__backend.__frontBufferTexture);
			setVertexBufferAt(0, stage3D.__vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			setVertexBufferAt(1, stage3D.__vertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, stage3D.__renderTransform, true);
			drawTriangles(stage3D.__indexBuffer);

			parent.__present = true;
		}
	}

	@:noCompletion private function __setGLBlend(enable:Bool):Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __setGLBlendEquation(value:Int):Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	@:noCompletion private function __setGLScissorTest(enable:Bool):Void
	{
		// stub
		openfl.Lib.notImplemented();
	}

	// Get & Set Methods

	@:noCompletion private function get_totalGPUMemory():Float
	{
		var stats = bgfx.getStats();

		if (stats.gpuMemoryUsed > 0)
		{
			__memoryCurrentAvailable = stats.gpuMemoryMax - stats.gpuMemoryUsed;

			return stats.gpuMemoryUsed * 1024;
		}
		return 0;
	}
}
