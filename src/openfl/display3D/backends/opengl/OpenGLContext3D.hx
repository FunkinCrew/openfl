package openfl.display3D.backends.opengl;

import openfl.display3D._internal.Context3DState;
import openfl.display3D._internal.GLBuffer;
import openfl.display3D._internal.GLFramebuffer;
import openfl.display3D._internal.GLTexture;
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
import openfl.display.Context3DRenderer;
#if lime
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.BGFXRenderContext;
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
class OpenGLContext3D implements openfl.display3D.IContext3D
{
	@:noCompletion private var parent:Context3D;

	public static var supportsVideoTexture(default, null):Bool = #if (js && html5) true #else false #end;

	public var totalGPUMemory(get, never):Float;

	@:noCompletion private static var __driverInfo:String;
	@:noCompletion private static var __depthStencil:Int = -1;

	@:noCompletion private var __glDepthStencilFormat(get, never):Int;

	@:noCompletion private inline function get___glDepthStencilFormat():Int
		return __depthStencil;

	@:noCompletion private var __bgfxDepthFormat(get, never):Int;

	@:noCompletion private inline function get___bgfxDepthFormat():Int
		return 0;

	// Instance (not static) so a backend-agnostic texture can read them through the facade
	// as IContext3D members; bgfx exposes the same fields as no-op zeros.
	@:noCompletion private var __maxTextureMaxAnisotropy:Int = -1;
	@:noCompletion private var __textureMaxAnisotropy:Int = -1;

	@:noCompletion private static var __maxViewportDims:Int = -1;
	@:noCompletion private static var __memoryCurrentAvailable:Int = -1;
	@:noCompletion private static var __memoryTotalAvailable:Int = -1;

	@:noCompletion public var gl:WebGL2RenderContext;
	@:noCompletion public var bgfx:#if lime BGFXRenderContext #else Dynamic #end;

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

		#if (js && html5)
		gl = parent.__context.webgl2;
		#elseif desktop
		gl = parent.__context.gl;
		#elseif mobile
		gl = parent.__context.gles3;
		#end

		parent.__contextState = (contextState != null) ? contextState : new Context3DState();
		parent.__state = new Context3DState();

		parent.driverInfo = "OpenGL (Direct blitting)";
		parent.profile = STANDARD;

		#if lime
		parent.__vertexConstants = new Float32Array(4 * 128);
		parent.__fragmentConstants = new Float32Array(4 * 128);
		__positionScale = new Float32Array([1.0, 1.0, 1.0, 1.0]);
		#end
		parent.__programs = new Map<String, Program3D>();

		if (__maxViewportDims == -1)
		{
			#if (js && html5)
			__maxViewportDims = gl.getParameter(gl.MAX_VIEWPORT_DIMS);
			#else
			__maxViewportDims = 16384;
			#end
		}

		parent.maxBackBufferWidth = __maxViewportDims;
		parent.maxBackBufferHeight = __maxViewportDims;

		if (__maxTextureMaxAnisotropy == -1)
		{
			var extension:Dynamic = gl.getExtension("EXT_texture_filter_anisotropic");

			#if (js && html5)
			if (extension == null
				|| !Reflect.hasField(extension, "MAX_TEXTURE_MAX_ANISOTROPY_EXT")) extension = gl.getExtension("MOZ_EXT_texture_filter_anisotropic");
			if (extension == null
				|| !Reflect.hasField(extension, "MAX_TEXTURE_MAX_ANISOTROPY_EXT")) extension = gl.getExtension("WEBKIT_EXT_texture_filter_anisotropic");
			#end

			if (extension != null)
			{
				__textureMaxAnisotropy = extension.TEXTURE_MAX_ANISOTROPY_EXT;
				__maxTextureMaxAnisotropy = gl.getParameter(extension.MAX_TEXTURE_MAX_ANISOTROPY_EXT);
			}
			else
			{
				__textureMaxAnisotropy = 0;
				__maxTextureMaxAnisotropy = 0;
			}
		}

		#if lime
		if (__depthStencil == -1)
		{
			#if (js && html5)
			__depthStencil = gl.DEPTH_STENCIL;
			#else
			if (parent.__context.type == OPENGLES && Std.parseFloat(parent.__context.version) >= 3)
			{
				__depthStencil = parent.__context.gles3.DEPTH24_STENCIL8;
			}
			else
			{
				var extension = gl.getExtension("OES_packed_depth_stencil");
				if (extension != null)
				{
					__depthStencil = extension.DEPTH24_STENCIL8_OES;
				}
				else
				{
					extension = gl.getExtension("EXT_packed_depth_stencil");
					if (extension != null)
					{
						__depthStencil = extension.DEPTH24_STENCIL8_EXT;
					}
					else
					{
						__depthStencil = 0;
					}
				}
			}
			#end
		}

		if (__memoryTotalAvailable == -1)
		{
			var extension = gl.getExtension("NVX_gpu_memory_info");
			if (extension != null)
			{
				__memoryTotalAvailable = extension.GPU_MEMORY_INFO_DEDICATED_VIDMEM_NVX;
				__memoryCurrentAvailable = extension.GPU_MEMORY_INFO_CURRENT_AVAILABLE_VIDMEM_NVX;
			}
		}
		#end

		if (__driverInfo == null)
		{
			var vendor = gl.getParameter(gl.VENDOR);
			var version = gl.getParameter(gl.VERSION);
			var renderer = gl.getParameter(gl.RENDERER);
			var glslVersion = gl.getParameter(gl.SHADING_LANGUAGE_VERSION);

			__driverInfo = "OpenGL Vendor=" + vendor + " Version=" + version + " Renderer=" + renderer + " GLSL=" + glslVersion;
		}

		parent.driverInfo = __driverInfo;

		parent.__quadIndexBufferElements = Math.floor(0xFFFF / 4);
		__quadIndexBufferCount = parent.__quadIndexBufferElements * 6;

		#if lime
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
		#end
	}

	public function clear(red:Float = 0, green:Float = 0, blue:Float = 0, alpha:Float = 1, depth:Float = 1, stencil:UInt = 0,
			mask:UInt = Context3DClearMask.ALL):Void
	{
		__clear(false, red, green, blue, alpha, depth, stencil, mask);
	}

	@:noCompletion private function __clear(useScissor:Bool, red:Float = 0, green:Float = 0, blue:Float = 0, alpha:Float = 1, depth:Float = 1,
			stencil:UInt = 0, mask:UInt = Context3DClearMask.ALL)
	{
		__flushGLFramebuffer();
		__flushViewport();

		var clearMask = 0;

		if (mask & Context3DClearMask.COLOR != 0)
		{
			if (parent.__state.renderToTexture == null)
			{
				if (parent.__stage.context3D == parent && !parent.__stage.__renderer.__cleared) parent.__stage.__renderer.__cleared = true;
				parent.__cleared = true;
			}

			clearMask |= gl.COLOR_BUFFER_BIT;

			if (#if openfl_disable_context_cache true #else parent.__contextState.colorMaskRed != true
				|| parent.__contextState.colorMaskGreen != true
				|| parent.__contextState.colorMaskBlue != true
				|| parent.__contextState.colorMaskAlpha != true #end)
			{
				gl.colorMask(true, true, true, true);
				parent.__contextState.colorMaskRed = true;
				parent.__contextState.colorMaskGreen = true;
				parent.__contextState.colorMaskBlue = true;
				parent.__contextState.colorMaskAlpha = true;
			}

			gl.clearColor(red, green, blue, alpha);
		}

		if (mask & Context3DClearMask.DEPTH != 0)
		{
			clearMask |= gl.DEPTH_BUFFER_BIT;

			if (#if openfl_disable_context_cache true #else parent.__contextState.depthMask != true #end)
			{
				gl.depthMask(true);
				parent.__contextState.depthMask = true;
			}

			gl.clearDepth(depth);
		}

		if (mask & Context3DClearMask.STENCIL != 0)
		{
			clearMask |= gl.STENCIL_BUFFER_BIT;

			if (#if openfl_disable_context_cache true #else parent.__contextState.stencilWriteMask != 0xFF #end)
			{
				gl.stencilMask(0xFF);
				parent.__contextState.stencilWriteMask = 0xFF;
			}

			gl.clearStencil(stencil);
			parent.__contextState.stencilWriteMask = 0xFF;
		}

		if (clearMask == 0) return;

		if (useScissor)
		{
			__flushScissor();
		}
		else
		{
			__setGLScissorTest(false);
		}

		gl.clear(clearMask);
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

		if (__stage3D == null)
		{
			parent.backBufferWidth = width;
			parent.backBufferHeight = height;

			__backBufferAntiAlias = antiAlias;
			parent.__state.backBufferEnableDepthAndStencil = enableDepthAndStencil;
			parent.__backBufferWantsBestResolution = wantsBestResolution;
			__backBufferWantsBestResolutionOnBrowserZoom = wantsBestResolutionOnBrowserZoom;
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
			parent.__state.__primaryGLFramebuffer = __backBufferTexture.__getFramebuffer(enableDepthAndStencil, antiAlias, 0);
			__frontBufferTexture.__getFramebuffer(enableDepthAndStencil, antiAlias, 0);
		}
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
			ASTCTexture.__astcCompressedTexturesSupported = gl.getSupportedExtensions().contains("KHR_texture_compression_astc_ldr");
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
			S3TCTexture.__s3tcCompressedTexturesSupported = gl.getSupportedExtensions().contains("EXT_texture_compression_s3tc");
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
		#if (js && html5)
		return new VideoTexture(this);
		#else
		throw new Error("Video textures are not supported on this platform");
		return null;
		#end
	}

	public function dispose(recreate:Bool = true):Void
	{
		// TODO: Dispose all related buffers

		gl = null;
		__dispose();
	}

	public function drawToBitmapData(destination:BitmapData, srcRect:Rectangle = null, destPoint:Point = null):Void
	{
		#if lime
		if (destination == null) return;

		var sourceRect = srcRect != null ? srcRect.__toLimeRectangle() : new LimeRectangle(0, 0, parent.backBufferWidth, parent.backBufferHeight);
		var destVector = destPoint != null ? destPoint.__toLimeVector2() : new Vector2();

		if (parent.__stage.context3D == parent)
		{
			if (parent.__stage.window != null)
			{
				if (__stage3D != null)
				{
					destVector.setTo(Std.int(-__stage3D.x), Std.int(-__stage3D.y));
				}

				var image = parent.__stage.window.readPixels();
				destination.image.copyPixels(image, sourceRect, destVector);
			}
		}
		else if (__backBufferTexture != null)
		{
			var cacheRenderToTexture = parent.__state.renderToTexture;
			setRenderToBackBuffer();

			__flushGLFramebuffer();
			__flushViewport();

			// TODO: Read less pixels if srcRect is smaller

			var data = new UInt8Array(parent.backBufferWidth * parent.backBufferHeight * 4);
			gl.readPixels(0, 0, parent.backBufferWidth, parent.backBufferHeight, __backBufferTexture.__format, gl.UNSIGNED_BYTE, data);

			var image = new Image(new ImageBuffer(data, parent.backBufferWidth, parent.backBufferHeight, 32, BGRA32));
			destination.image.copyPixels(image, sourceRect, destVector);

			if (cacheRenderToTexture != null)
			{
				setRenderToTexture(cacheRenderToTexture, parent.__state.renderToTextureDepthStencil, parent.__state.renderToTextureAntiAlias,
					parent.__state.renderToTextureSurfaceSelector);
			}
		}
		#end
	}

	public function drawTriangles(indexBuffer:IndexBuffer3D, firstIndex:Int = 0, numTriangles:Int = -1):Void
	{
		#if !openfl_disable_display_render
		if (parent.__state.renderToTexture == null)
		{
			// TODO: Make sure state is correct for this?
			if (parent.__stage.context3D == parent && !parent.__stage.__renderer.__cleared)
			{
				parent.__stage.__renderer.__clear();
			}
			else if (!parent.__cleared)
			{
				// TODO: Throw error if error reporting is enabled?
				clear(0, 0, 0, 0, 1, 0, Context3DClearMask.COLOR);
			}
		}

		__flush();
		#end

		if (parent.__state.program != null)
		{
			parent.__state.program.__flush();
		}

		var count = (numTriangles == -1) ? indexBuffer.__numIndices : (numTriangles * 3);

		__bindGLElementArrayBuffer(indexBuffer.__id);

		if (Context3DRenderer.__coherentBlendsSupported)
		{
			gl.enable(0x9285); // BLEND_ADVANCED_COHERENT_KHR
		}
		else if (parent.__usingComplexBlend)
		{
			gl.blendBarrier();
		}

		gl.drawElements(gl.TRIANGLES, count, gl.UNSIGNED_SHORT, firstIndex * 2);

		if (Context3DRenderer.__coherentBlendsSupported)
		{
			gl.disable(0x9285); // BLEND_ADVANCED_COHERENT_KHR
		}
	}

	public function present():Void
	{
		setRenderToBackBuffer();

		if (__stage3D != null && __backBufferTexture != null)
		{
			if (!parent.__cleared)
			{
				// Make sure texture is initialized
				// TODO: Throw error if error reporting is enabled?
				clear(0, 0, 0, 0, 1, 0, Context3DClearMask.COLOR);
			}

			var cacheBuffer = __backBufferTexture;
			__backBufferTexture = __frontBufferTexture;
			__frontBufferTexture = cacheBuffer;

			parent.__state.__primaryGLFramebuffer = __backBufferTexture.__getFramebuffer(parent.__state.backBufferEnableDepthAndStencil,
				__backBufferAntiAlias, 0);
			parent.__cleared = false;
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

		// TODO: Better way to handle this?
		__setGLBlendEquation(gl.FUNC_ADD);
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
	}

	public function setRenderToTexture(texture:TextureBase, enableDepthAndStencil:Bool = false, antiAlias:Int = 0, surfaceSelector:Int = 0):Void
	{
		parent.__state.renderToTexture = texture;
		parent.__state.renderToTextureDepthStencil = enableDepthAndStencil;
		parent.__state.renderToTextureAntiAlias = antiAlias;
		parent.__state.renderToTextureSurfaceSelector = surfaceSelector;
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
		// if (sampler < 0 || sampler > Context3D.MAX_SAMPLERS) {

		// 	throw new Error ("sampler out of range");

		// }

		parent.__state.textures[sampler] = texture;
	}

	public function setVertexBufferAt(index:Int, buffer:VertexBuffer3D, bufferOffset:Int = 0, format:Context3DVertexBufferFormat = FLOAT_4):Void
	{
		if (index < 0) return;

		if (buffer == null)
		{
			gl.disableVertexAttribArray(index);
			__bindGLArrayBuffer(null);
			return;
		}

		__bindGLArrayBuffer(buffer.__id);
		gl.enableVertexAttribArray(index);

		var byteOffset = bufferOffset * 4;

		switch (format)
		{
			case BYTES_4:
				gl.vertexAttribPointer(index, 4, gl.UNSIGNED_BYTE, true, buffer.__stride, byteOffset);

			case FLOAT_4:
				gl.vertexAttribPointer(index, 4, gl.FLOAT, false, buffer.__stride, byteOffset);

			case FLOAT_3:
				gl.vertexAttribPointer(index, 3, gl.FLOAT, false, buffer.__stride, byteOffset);

			case FLOAT_2:
				gl.vertexAttribPointer(index, 2, gl.FLOAT, false, buffer.__stride, byteOffset);

			case FLOAT_1:
				gl.vertexAttribPointer(index, 1, gl.FLOAT, false, buffer.__stride, byteOffset);

			default:
				throw new IllegalOperationError();
		}
	}

	@:noCompletion private function __bindGLArrayBuffer(buffer:GLBuffer):Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.__currentGLArrayBuffer != buffer #end)
		{
			gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
			parent.__contextState.__currentGLArrayBuffer = buffer;
		}
	}

	@:noCompletion private function __bindGLElementArrayBuffer(buffer:GLBuffer):Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.__currentGLElementArrayBuffer != buffer #end)
		{
			gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer);
			parent.__contextState.__currentGLElementArrayBuffer = buffer;
		}
	}

	@:noCompletion private function __bindGLFramebuffer(framebuffer:GLFramebuffer):Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.__currentGLFramebuffer != framebuffer #end)
		{
			gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
			parent.__contextState.__currentGLFramebuffer = framebuffer;
		}
	}

	@:noCompletion private function __bindGLTexture2D(texture:GLTexture):Void
	{
		// TODO: Need to consider activeTexture ID

		// if (#if openfl_disable_context_cache true #else __contextState.__currentGLTexture2D != texture #end) {

		gl.bindTexture(gl.TEXTURE_2D, texture);
		parent.__contextState.__currentGLTexture2D = texture;

		// }
	}

	@:noCompletion private function __bindGLTextureCubeMap(texture:GLTexture):Void
	{
		// TODO: Need to consider activeTexture ID

		// if (#if openfl_disable_context_cache true #else __contextState.__currentGLTextureCubeMap != texture #end) {

		gl.bindTexture(gl.TEXTURE_CUBE_MAP, texture);
		parent.__contextState.__currentGLTextureCubeMap = texture;

		// }
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
		#if !openfl_disable_display_render
		if (parent.__state.renderToTexture == null)
		{
			// TODO: Make sure state is correct for this?
			if (parent.__stage.context3D == parent && !parent.__stage.__renderer.__cleared)
			{
				parent.__stage.__renderer.__clear();
			}
			else if (!parent.__cleared)
			{
				// TODO: Throw error if error reporting is enabled?
				clear(0, 0, 0, 0, 1, 0, Context3DClearMask.COLOR);
			}
		}

		__flush();
		#end

		if (parent.__state.program != null)
		{
			parent.__state.program.__flush();
		}

		if (Context3DRenderer.__coherentBlendsSupported)
		{
			gl.enable(0x9285); // BLEND_ADVANCED_COHERENT_KHR
		}
		else if (parent.__usingComplexBlend)
		{
			gl.blendBarrier();
		}

		gl.drawArrays(gl.TRIANGLES, firstIndex, count);

		if (Context3DRenderer.__coherentBlendsSupported)
		{
			gl.disable(0x9285); // BLEND_ADVANCED_COHERENT_KHR
		}
	}

	@:noCompletion private function __flush():Void
	{
		__flushProgram();
		__flushGLFramebuffer();
		__flushViewport();

		__flushGLBlend();
		__flushGLColor();
		__flushGLCulling();
		__flushGLDepth();
		__flushScissor();
		__flushStencil();
		__flushTextures();
	}

	@:noCompletion private function __flushGLBlend():Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.blendDestinationRGBFactor != parent.__state.blendDestinationRGBFactor
			|| parent.__contextState.blendSourceRGBFactor != parent.__state.blendSourceRGBFactor
			|| parent.__contextState.blendDestinationAlphaFactor != parent.__state.blendDestinationAlphaFactor
			|| parent.__contextState.blendSourceAlphaFactor != parent.__state.blendSourceAlphaFactor #end)
		{
			__setGLBlend(true);

			if (parent.__state.blendDestinationRGBFactor == parent.__state.blendDestinationAlphaFactor
				&& parent.__state.blendSourceRGBFactor == parent.__state.blendSourceAlphaFactor)
			{
				gl.blendFunc(__getGLBlend(parent.__state.blendSourceRGBFactor), __getGLBlend(parent.__state.blendDestinationRGBFactor));
			}
			else
			{
				gl.blendFuncSeparate(__getGLBlend(parent.__state.blendSourceRGBFactor), __getGLBlend(parent.__state.blendDestinationRGBFactor),
					__getGLBlend(parent.__state.blendSourceAlphaFactor), __getGLBlend(parent.__state.blendDestinationAlphaFactor));
			}

			parent.__contextState.blendDestinationRGBFactor = parent.__state.blendDestinationRGBFactor;
			parent.__contextState.blendSourceRGBFactor = parent.__state.blendSourceRGBFactor;
			parent.__contextState.blendDestinationAlphaFactor = parent.__state.blendDestinationAlphaFactor;
			parent.__contextState.blendSourceAlphaFactor = parent.__state.blendSourceAlphaFactor;
		}
	}

	@:noCompletion private inline function __flushGLColor():Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.colorMaskRed != parent.__state.colorMaskRed
			|| parent.__contextState.colorMaskGreen != parent.__state.colorMaskGreen
			|| parent.__contextState.colorMaskBlue != parent.__state.colorMaskBlue
			|| parent.__contextState.colorMaskAlpha != parent.__state.colorMaskAlpha #end)
		{
			gl.colorMask(parent.__state.colorMaskRed, parent.__state.colorMaskGreen, parent.__state.colorMaskBlue, parent.__state.colorMaskAlpha);
			parent.__contextState.colorMaskRed = parent.__state.colorMaskRed;
			parent.__contextState.colorMaskGreen = parent.__state.colorMaskGreen;
			parent.__contextState.colorMaskBlue = parent.__state.colorMaskBlue;
			parent.__contextState.colorMaskAlpha = parent.__state.colorMaskAlpha;
		}
	}

	@:noCompletion private function __flushGLCulling():Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.culling != parent.__state.culling #end)
		{
			if (parent.__state.culling == NONE)
			{
				__setGLCullFace(false);
			}
			else
			{
				__setGLCullFace(true);

				switch (parent.__state.culling)
				{
					case NONE: // skip
					case BACK:
						gl.cullFace(gl.BACK);
					case FRONT:
						gl.cullFace(gl.FRONT);
					case FRONT_AND_BACK:
						gl.cullFace(gl.FRONT_AND_BACK);
					default:
						throw new IllegalOperationError();
				}
			}

			parent.__contextState.culling = parent.__state.culling;
		}
	}

	@:noCompletion private function __flushGLDepth():Void
	{
		var depthMask = (parent.__state.depthMask
			&& (parent.__state.renderToTexture != null ? parent.__state.renderToTextureDepthStencil : parent.__state.backBufferEnableDepthAndStencil));

		if (#if openfl_disable_context_cache true #else parent.__contextState.depthMask != depthMask #end)
		{
			gl.depthMask(depthMask);
			parent.__contextState.depthMask = depthMask;
		}

		if (#if openfl_disable_context_cache true #else parent.__contextState.depthCompareMode != parent.__state.depthCompareMode #end)
		{
			switch (parent.__state.depthCompareMode)
			{
				case ALWAYS:
					gl.depthFunc(gl.ALWAYS);
				case EQUAL:
					gl.depthFunc(gl.EQUAL);
				case GREATER:
					gl.depthFunc(gl.GREATER);
				case GREATER_EQUAL:
					gl.depthFunc(gl.GEQUAL);
				case LESS:
					gl.depthFunc(gl.LESS);
				case LESS_EQUAL:
					gl.depthFunc(gl.LEQUAL);
				case NEVER:
					gl.depthFunc(gl.NEVER);
				case NOT_EQUAL:
					gl.depthFunc(gl.NOTEQUAL);
				default:
					throw new IllegalOperationError();
			}

			parent.__contextState.depthCompareMode = parent.__state.depthCompareMode;
		}
	}

	@:noCompletion private function __flushGLFramebuffer():Void
	{
		if (parent.__state.renderToTexture != null)
		{
			if (#if openfl_disable_context_cache true #else parent.__contextState.renderToTexture != parent.__state.renderToTexture
				|| parent.__contextState.renderToTextureSurfaceSelector != parent.__state.renderToTextureSurfaceSelector #end)
			{
				var framebuffer = parent.__state.renderToTexture.__getFramebuffer(parent.__state.renderToTextureDepthStencil,
					parent.__state.renderToTextureAntiAlias, parent.__state.renderToTextureSurfaceSelector);
				__bindGLFramebuffer(framebuffer);

				parent.__contextState.renderToTexture = parent.__state.renderToTexture;
				parent.__contextState.renderToTextureAntiAlias = parent.__state.renderToTextureAntiAlias;
				parent.__contextState.renderToTextureDepthStencil = parent.__state.renderToTextureDepthStencil;
				parent.__contextState.renderToTextureSurfaceSelector = parent.__state.renderToTextureSurfaceSelector;
			}

			__setGLDepthTest(parent.__state.renderToTextureDepthStencil);
			__setGLStencilTest(parent.__state.renderToTextureDepthStencil);

			__setGLFrontFace(true);
		}
		else
		{
			if (parent.__stage == null && parent.backBufferWidth == 0 && parent.backBufferHeight == 0)
			{
				throw new Error("Context3D backbuffer has not been configured");
			}

			if (#if openfl_disable_context_cache true #else parent.__contextState.renderToTexture != null
				|| parent.__contextState.__currentGLFramebuffer != parent.__state.__primaryGLFramebuffer
				|| parent.__contextState.backBufferEnableDepthAndStencil != parent.__state.backBufferEnableDepthAndStencil #end
			)
			{
				__bindGLFramebuffer(parent.__state.__primaryGLFramebuffer);

				parent.__contextState.renderToTexture = null;
				parent.__contextState.backBufferEnableDepthAndStencil = parent.__state.backBufferEnableDepthAndStencil;
			}

			__setGLDepthTest(parent.__state.backBufferEnableDepthAndStencil);
			__setGLStencilTest(parent.__state.backBufferEnableDepthAndStencil);

			__setGLFrontFace(parent.__stage.context3D != parent);
		}
	}

	@:noCompletion private function __flushProgram():Void
	{
		var shader = parent.__state.shader;
		var program = parent.__state.program;

		if (#if openfl_disable_context_cache true #else parent.__contextState.shader != shader #end)
		{
			// TODO: Merge this logic

			if (parent.__contextState.shader != null)
			{
				parent.__contextState.shader.__disable();
			}

			if (shader != null)
			{
				shader.__enable();
			}

			parent.__contextState.shader = shader;
		}

		if (#if openfl_disable_context_cache true #else parent.__contextState.program != program #end)
		{
			if (parent.__contextState.program != null)
			{
				parent.__contextState.program.__disable();
			}

			if (program != null)
			{
				program.__enable();
			}

			parent.__contextState.program = program;
		}

		if (program != null && program.__format == AGAL)
		{
			__positionScale[1] = (parent.__stage.context3D == parent && parent.__state.renderToTexture == null) ? 1.0 : -1.0;
			program.__setPositionScale(__positionScale);
		}
	}

	@:noCompletion private function __flushScissor():Void
	{
		if (!parent.__state.scissorEnabled)
		{
			if (#if openfl_disable_context_cache true #else parent.__contextState.scissorEnabled != parent.__state.scissorEnabled #end)
			{
				__setGLScissorTest(false);
				parent.__contextState.scissorEnabled = false;
			}
		}
		else
		{
			__setGLScissorTest(true);
			parent.__contextState.scissorEnabled = true;

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

			if (parent.__state.renderToTexture == null && __stage3D == null)
			{
				var contextHeight = Std.int(parent.__stage.window.height * parent.__stage.window.scale);
				scissorY = contextHeight - scissorHeight - scissorY;
			}

			if (#if openfl_disable_context_cache true #else parent.__contextState.scissorRectangle.x != scissorX
				|| parent.__contextState.scissorRectangle.y != scissorY
				|| parent.__contextState.scissorRectangle.width != scissorWidth
				|| parent.__contextState.scissorRectangle.height != scissorHeight #end)
			{
				gl.scissor(scissorX, scissorY, scissorWidth, scissorHeight);
				parent.__contextState.scissorRectangle.setTo(scissorX, scissorY, scissorWidth, scissorHeight);
			}
		}
	}

	@:noCompletion private function __flushStencil():Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.stencilTriangleFace != parent.__state.stencilTriangleFace
			|| parent.__contextState.stencilPass != parent.__state.stencilPass
			|| parent.__contextState.stencilDepthFail != parent.__state.stencilDepthFail
			|| parent.__contextState.stencilFail != parent.__state.stencilFail #end)
		{
			gl.stencilOpSeparate(__getGLTriangleFace(parent.__state.stencilTriangleFace), __getGLStencilAction(parent.__state.stencilFail),
				__getGLStencilAction(parent.__state.stencilDepthFail), __getGLStencilAction(parent.__state.stencilPass));
			parent.__contextState.stencilTriangleFace = parent.__state.stencilTriangleFace;
			parent.__contextState.stencilPass = parent.__state.stencilPass;
			parent.__contextState.stencilDepthFail = parent.__state.stencilDepthFail;
			parent.__contextState.stencilFail = parent.__state.stencilFail;
		}

		if (#if openfl_disable_context_cache true #else parent.__contextState.stencilWriteMask != parent.__state.stencilWriteMask #end)
		{
			gl.stencilMask(parent.__state.stencilWriteMask);
			parent.__contextState.stencilWriteMask = parent.__state.stencilWriteMask;
		}

		if (#if openfl_disable_context_cache true #else parent.__contextState.stencilCompareMode != parent.__state.stencilCompareMode
			|| parent.__contextState.stencilReferenceValue != parent.__state.stencilReferenceValue
			|| parent.__contextState.stencilReadMask != parent.__state.stencilReadMask #end
		)
		{
			gl.stencilFunc(__getGLCompareMode(parent.__state.stencilCompareMode), parent.__state.stencilReferenceValue, parent.__state.stencilReadMask);
			parent.__contextState.stencilCompareMode = parent.__state.stencilCompareMode;
			parent.__contextState.stencilReferenceValue = parent.__state.stencilReferenceValue;
			parent.__contextState.stencilReadMask = parent.__state.stencilReadMask;
		}
	}

	@:noCompletion private function __flushTextures():Void
	{
		var sampler = 0;
		var texture:TextureBase;
		var samplerState:SamplerState;

		for (i in 0...parent.__state.textures.length)
		{
			texture = parent.__state.textures[i];
			samplerState = parent.__state.samplerStates[i];
			if (samplerState == null)
			{
				parent.__state.samplerStates[i] = new SamplerState();
				samplerState = parent.__state.samplerStates[i];
			}

			gl.activeTexture(gl.TEXTURE0 + sampler);

			if (texture != null)
			{
				// if (#if openfl_disable_context_cache true #else texture != __contextState.textures[i] #end) {

				// TODO: Cleaner approach?
				if (texture.__textureTarget == gl.TEXTURE_2D)
				{
					__bindGLTexture2D(texture.__getTexture());
				}
				else
				{
					__bindGLTextureCubeMap(texture.__getTexture());
				}

				#if lime
				if (parent.__context.type == OPENGL)
				{
					// TODO: Cache?
					gl.enable(gl.TEXTURE_2D);
				}
				#end

				parent.__contextState.textures[i] = texture;

				// }

				texture.__setSamplerState(samplerState);
			}
			else
			{
				__bindGLTexture2D(null);
			}

			if (parent.__state.program != null && parent.__state.program.__format == AGAL && samplerState.textureAlpha)
			{
				gl.activeTexture(gl.TEXTURE0 + sampler + 4);

				__bindGLTexture2D(null);
				if (parent.__state.program.__agalAlphaSamplerEnabled[sampler] != null)
				{
					gl.uniform1i(parent.__state.program.__agalAlphaSamplerEnabled[sampler].location, 0);
				}
			}

			sampler++;
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
				gl.viewport(x, y, scaledBackBufferWidth, scaledBackBufferHeight);
			}
			else
			{
				gl.viewport(0, 0, parent.backBufferWidth, parent.backBufferHeight);
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

			gl.viewport(0, 0, width, height);
		}
	}

	@:noCompletion private function __getGLBlend(blendFactor:Context3DBlendFactor):Int
	{
		switch (blendFactor)
		{
			case DESTINATION_ALPHA:
				return gl.DST_ALPHA;
			case DESTINATION_COLOR:
				return gl.DST_COLOR;
			case ONE:
				return gl.ONE;
			case ONE_MINUS_DESTINATION_ALPHA:
				return gl.ONE_MINUS_DST_ALPHA;
			case ONE_MINUS_DESTINATION_COLOR:
				return gl.ONE_MINUS_DST_COLOR;
			case ONE_MINUS_SOURCE_ALPHA:
				return gl.ONE_MINUS_SRC_ALPHA;
			case ONE_MINUS_SOURCE_COLOR:
				return gl.ONE_MINUS_SRC_COLOR;
			case SOURCE_ALPHA:
				return gl.SRC_ALPHA;
			case SOURCE_COLOR:
				return gl.SRC_COLOR;
			case ZERO:
				return gl.ZERO;
			default:
				throw new IllegalOperationError();
		}

		return 0;
	}

	@:noCompletion private function __getGLCompareMode(mode:Context3DCompareMode):Int
	{
		return switch (mode)
		{
			case ALWAYS: gl.ALWAYS;
			case EQUAL: gl.EQUAL;
			case GREATER: gl.GREATER;
			case GREATER_EQUAL: gl.GEQUAL;
			case LESS: gl.LESS;
			case LESS_EQUAL: gl.LEQUAL; // TODO : wrong value
			case NEVER: gl.NEVER;
			case NOT_EQUAL: gl.NOTEQUAL;
			default: gl.EQUAL;
		}
	}

	@:noCompletion private function __getGLStencilAction(action:Context3DStencilAction):Int
	{
		return switch (action)
		{
			case DECREMENT_SATURATE: gl.DECR;
			case DECREMENT_WRAP: gl.DECR_WRAP;
			case INCREMENT_SATURATE: gl.INCR;
			case INCREMENT_WRAP: gl.INCR_WRAP;
			case INVERT: gl.INVERT;
			case KEEP: gl.KEEP;
			case SET: gl.REPLACE;
			case ZERO: gl.ZERO;
			default: gl.KEEP;
		}
	}

	@:noCompletion private function __getGLTriangleFace(face:Context3DTriangleFace):Int
	{
		return switch (face)
		{
			case FRONT: gl.FRONT;
			case BACK: gl.BACK;
			case FRONT_AND_BACK: gl.FRONT_AND_BACK;
			case NONE: gl.NONE;
			default: gl.FRONT_AND_BACK;
		}
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
		if (#if openfl_disable_context_cache true #else parent.__contextState.__enableGLBlend != enable #end)
		{
			if (enable)
			{
				gl.enable(gl.BLEND);
			}
			else
			{
				gl.disable(gl.BLEND);
			}
			parent.__contextState.__enableGLBlend = enable;
		}
	}

	@:noCompletion private function __setGLBlendEquation(value:Int):Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.__glBlendEquation != value #end)
		{
			gl.blendEquation(value);
			parent.__contextState.__glBlendEquation = value;
		}
	}

	@:noCompletion private function __setGLCullFace(enable:Bool):Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.__enableGLCullFace != enable #end)
		{
			if (enable)
			{
				gl.enable(gl.CULL_FACE);
			}
			else
			{
				gl.disable(gl.CULL_FACE);
			}
			parent.__contextState.__enableGLCullFace = enable;
		}
	}

	@:noCompletion private function __setGLDepthTest(enable:Bool):Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.__enableGLDepthTest != enable #end)
		{
			if (enable)
			{
				gl.enable(gl.DEPTH_TEST);
			}
			else
			{
				gl.disable(gl.DEPTH_TEST);
			}
			parent.__contextState.__enableGLDepthTest = enable;
		}
	}

	@:noCompletion private function __setGLFrontFace(counterClockWise:Bool):Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.__frontFaceGLCCW != counterClockWise #end)
		{
			gl.frontFace(counterClockWise ? gl.CCW : gl.CW);
			parent.__contextState.__frontFaceGLCCW = counterClockWise;
		}
	}

	@:noCompletion private function __setGLScissorTest(enable:Bool):Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.__enableGLScissorTest != enable #end)
		{
			if (enable)
			{
				gl.enable(gl.SCISSOR_TEST);
			}
			else
			{
				gl.disable(gl.SCISSOR_TEST);
			}
			parent.__contextState.__enableGLScissorTest = enable;
		}
	}

	@:noCompletion private function __setGLStencilTest(enable:Bool):Void
	{
		if (#if openfl_disable_context_cache true #else parent.__contextState.__enableGLStencilTest != enable #end)
		{
			if (enable)
			{
				gl.enable(gl.STENCIL_TEST);
			}
			else
			{
				gl.disable(gl.STENCIL_TEST);
			}
			parent.__contextState.__enableGLStencilTest = enable;
		}
	}

	@:noCompletion private inline function __glBlendBarrier():Void
	{
		gl.blendBarrier();
	}

	// Get & Set Methods

	@:noCompletion private function get_totalGPUMemory():Float
	{
		if (__memoryCurrentAvailable != -1)
		{
			// TODO: Return amount used by this application only
			var current = gl.getParameter(__memoryCurrentAvailable);
			var total = gl.getParameter(__memoryTotalAvailable);

			if (total > 0)
			{
				return (total - current) * 1024;
			}
		}
		return 0;
	}
}
