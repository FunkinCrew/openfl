package openfl.utils;

#if lime
import lime.graphics.opengl.GL;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.ImageType;
import lime.graphics.PixelFormat;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.Graphics;
import openfl.display.IBitmapDrawable;
import openfl.display.OpenGLRenderer;
import openfl.display.Stage;
import openfl.display.Sprite;
import openfl.display.Shader;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DTextureFormat;
import openfl.filters.BitmapFilter;
import openfl.geom.ColorTransform;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import openfl.geom.Matrix;
import openfl.utils._internal.UInt8Array;
import openfl.Lib;

#if flixel
import flixel.math.FlxRect;
import flixel.FlxG;
#end

final class BitmapDataUtil {
	public static var maxTextureSize(get, never):Int;
	inline static function get_maxTextureSize() return cast GL.getParameter(GL.MAX_TEXTURE_SIZE);

	public static var stage(get, never):Stage;
	inline static function get_stage():Stage return #if flixel FlxG.stage #else Lib.current.stage #end;

	public static var context3D(get, never):Context3D;
	inline static function get_context3D():Context3D return stage.context3D;

	public static var gfxBitmap:Bitmap;
	public static var gfxSprite:Sprite;
	public static var gfxRenderer:OpenGLRenderer;

	public static function prepareGfxSprite() @:privateAccess {
		if (gfxSprite == null) {
			(gfxSprite = new Sprite()).addChild(gfxBitmap = new Bitmap());
			gfxSprite.__cacheBitmapMatrix = new Matrix();
			gfxSprite.__cacheBitmapColorTransform = new ColorTransform();
		}
		else {
			gfxSprite.__cacheBitmapMatrix.identity();
			gfxSprite.__cacheBitmapColorTransform.__identity();
		}
	}

	public static function prepareGfxRenderer() @:privateAccess {
		prepareGfxSprite();

		if (gfxRenderer == null) {
			if ((gfxRenderer = cast gfxSprite.__cacheBitmapRenderer) == null || gfxRenderer.__type != OPENGL) {
				gfxSprite.__cacheBitmapRenderer = cast gfxRenderer = new OpenGLRenderer(context3D);
			}
			gfxRenderer.__worldTransform = new Matrix();
			gfxRenderer.__worldColorTransform = new ColorTransform();
			gfxRenderer.__allowSmoothing = (gfxRenderer.__stage = stage).__renderer.__allowSmoothing;
		}
		else {
			gfxRenderer.__worldTransform.identity();
			gfxRenderer.__worldColorTransform.__identity();
			gfxRenderer.__worldAlpha = 1;
			gfxRenderer.__overrideBlendMode = gfxRenderer.__blendMode = null;

			gfxRenderer.__clearShader();
			//gfxRenderer.__copyShader(cast stage.__gfxRenderer);
		}
	}

	public static function copyFrom(dst:BitmapData, src:BitmapData, ?alpha:Float, ?matrix:Matrix, smoothing = false) @:privateAccess {
		if (dst.image != null && src.image != null && alpha == null && matrix == null) {
			dst.copyPixels(src, dst.rect, gfxSprite.__tempPoint = gfxSprite.__tempPoint ?? new Point());
		}
		else {
			prepareGfxRenderer();

			final context = gfxRenderer.__context3D;
			final cacheRTT = context.__state.renderToTexture,
				cacheRTTDepthStencil = context.__state.renderToTextureDepthStencil,
				cacheRTTAntiAlias = context.__state.renderToTextureAntiAlias,
				cacheRTTSurfaceSelector = context.__state.renderToTextureSurfaceSelector;

			gfxRenderer.__setRenderTarget(dst);
			if (alpha != null) gfxRenderer.__worldAlpha = alpha;
			if (matrix != null) gfxRenderer.__worldTransform.concat(matrix);
			gfxRenderer.__renderFilterPass(src, gfxRenderer.__defaultDisplayShader, smoothing, false);

			if (cacheRTT != null) context.setRenderToTexture(cacheRTT, cacheRTTDepthStencil, cacheRTTAntiAlias, cacheRTTSurfaceSelector);
			else context.setRenderToBackBuffer();
		}
	}

	public inline static function prepareCacheBitmapData(bitmap:BitmapData, width:Int, height:Int):BitmapData {
		if (bitmap == null) return BitmapData.fromContext(context3D, width, height);
		bitmap.resize(width, height);
		return bitmap;
	}

	public static function applyShaders(bitmap:BitmapData, shaders:Array<Shader>) @:privateAccess {
		prepareGfxRenderer();

		final context = gfxRenderer.__context3D;
		final cacheRTT = context.__state.renderToTexture,
			cacheRTTDepthStencil = context.__state.renderToTextureDepthStencil,
			cacheRTTAntiAlias = context.__state.renderToTextureAntiAlias,
			cacheRTTSurfaceSelector = context.__state.renderToTextureSurfaceSelector;

		bitmap.getTexture(context);

		var bitmap2 = gfxSprite.__cacheBitmapData2 = prepareCacheBitmapData(gfxSprite.__cacheBitmapData2, bitmap.width, bitmap.height);
		var cacheBitmap:BitmapData;
		for (shader in shaders) {
			gfxRenderer.__setRenderTarget(bitmap2);

			bitmap2.__fillRect(bitmap2.rect, 0, true);
			gfxRenderer.__renderFilterPass(cacheBitmap = bitmap, shader, false, false);

			bitmap = bitmap2;
			bitmap2 = cacheBitmap;
		}

		if (bitmap == gfxSprite.__cacheBitmapData2) {
			gfxRenderer.__setRenderTarget(bitmap2);
			gfxRenderer.__renderFilterPass(bitmap, gfxRenderer.__defaultDisplayShader, false, false);
		}

		if (cacheRTT != null) context.setRenderToTexture(cacheRTT, cacheRTTDepthStencil, cacheRTTAntiAlias, cacheRTTSurfaceSelector);
		else context.setRenderToBackBuffer();
	}

	public static function applyFilters(bitmap:BitmapData, filters:Array<BitmapFilter>, resizeBitmap = false, ?rect:#if flixel FlxRect #else Rectangle #end) @:privateAccess {
		if (filters == null || filters.length == 0) return;
		prepareGfxRenderer();

		var width = bitmap.width, height = bitmap.height;
		if (resizeBitmap) {
			final flashRect = Rectangle.__pool.get(), cacheFilters = gfxSprite.__filters;
			gfxSprite.__filters = filters;
			gfxBitmap.bitmapData = bitmap;
			gfxSprite.__getFilterBounds(flashRect, gfxSprite.__cacheBitmapMatrix);
			gfxSprite.__filters = cacheFilters;

			if (rect != null) {
				#if flixel
				rect.copyFromFlash(flashRect);
				#else
				rect.copyFrom(flashRect);
				#end
			}
			bitmap.resize(width = Math.floor(flashRect.width), height = Math.floor(flashRect.height));
			Rectangle.__pool.release(flashRect);
		}
		else if (rect != null)
			rect.set(0, 0, width, height);

		var bitmap2 = gfxSprite.__cacheBitmapData2 = prepareCacheBitmapData(gfxSprite.__cacheBitmapData2, width, height);
		var bitmap3 = gfxSprite.__cacheBitmapData3, cacheBitmap:BitmapData;

		if (bitmap.__texture != null && gfxRenderer != null) {
			final context = gfxRenderer.__context3D;
			final cacheRTT = context.__state.renderToTexture,
				cacheRTTDepthStencil = context.__state.renderToTextureDepthStencil,
				cacheRTTAntiAlias = context.__state.renderToTextureAntiAlias,
				cacheRTTSurfaceSelector = context.__state.renderToTextureSurfaceSelector;

			for (filter in filters) {
				if (filter.__preserveObject) {
					gfxRenderer.__setRenderTarget(bitmap3 = prepareCacheBitmapData(bitmap3, width, height));
					gfxRenderer.__renderFilterPass(bitmap, gfxRenderer.__defaultDisplayShader, false, false);
				}

				for (i in 0...filter.__numShaderPasses) {
					final shader = filter.__initShader(gfxRenderer, i, filter.__preserveObject ? bitmap3 : null);
					gfxRenderer.__setBlendMode(filter.__shaderBlendMode);
					gfxRenderer.__setRenderTarget(bitmap2);

					bitmap2.__fillRect(bitmap2.rect, 0, true);
					gfxRenderer.__renderFilterPass(cacheBitmap = bitmap, shader, filter.__smooth, false);

					bitmap = bitmap2;
					bitmap2 = cacheBitmap;
				}

				gfxRenderer.__setBlendMode(NORMAL);
			}

			if (bitmap == gfxSprite.__cacheBitmapData2) {
				gfxRenderer.__setRenderTarget(bitmap2);
				gfxRenderer.__renderFilterPass(bitmap, gfxRenderer.__defaultDisplayShader, false, false);
			}

			if (cacheRTT != null) context.setRenderToTexture(cacheRTT, cacheRTTDepthStencil, cacheRTTAntiAlias, cacheRTTSurfaceSelector);
			else context.setRenderToBackBuffer();
		}

		gfxSprite.__cacheBitmapData3 = bitmap3;
	}

	public static function draw(dst:BitmapData, src:IBitmapDrawable, ?matrix:Matrix, smoothing = false, onlyGraphics = false) @:privateAccess {
		prepareGfxRenderer();

		final context = gfxRenderer.__context3D;
		final cacheRTT = context.__state.renderToTexture,
			cacheRTTDepthStencil = context.__state.renderToTextureDepthStencil,
			cacheRTTAntiAlias = context.__state.renderToTextureAntiAlias,
			cacheRTTSurfaceSelector = context.__state.renderToTextureSurfaceSelector;

		inline function _preDraw() {
			dst.__textureContext = context.__context;
			context.setRenderToTexture(dst.getTexture(context), true);
			context.setColorMask(true, true, true, true);
			context.setCulling(NONE);
			context.setStencilActions();
			context.setStencilReferenceValue(0, 0, 0);
			context.setScissorRectangle(null);

			gfxRenderer.__blendMode = null;
			gfxRenderer.__setBlendMode(NORMAL);
			gfxRenderer.__setRenderTarget(dst);
			gfxRenderer.__allowSmoothing = smoothing;
			gfxRenderer.__pixelRatio = #if openfl_disable_hdpi 1 #else stage.window.scale #end;

			gfxRenderer.__worldTransform.copyFrom(src.__renderTransform);
			gfxRenderer.__worldTransform.invert();
			if (matrix != null) gfxRenderer.__worldTransform.concat(matrix);

			gfxSprite.__cacheBitmapColorTransform.__copyFrom(src.__worldColorTransform);
			gfxSprite.__mask = src.__mask; gfxSprite.__scrollRect = src.__scrollRect;

			src.__worldColorTransform.__identity();
			src.__worldAlpha = 1; src.__mask = null; src.__scrollRect = null;
		}

		inline function _postDraw() {
			context.present();
			src.__worldColorTransform.__copyFrom(gfxSprite.__cacheBitmapColorTransform);
			src.__mask = gfxSprite.__mask; src.__scrollRect = gfxSprite.__scrollRect;
			gfxSprite.__mask = null; gfxSprite.__scrollRect = null;
		}

		if (src is DisplayObject) {
			final displayObject:DisplayObject = cast src;
			gfxSprite.__visible = displayObject.__visible;
			displayObject.__visible = true;

			src.__update(false, true);
			if (src.__renderable) {
				_preDraw();
				if (onlyGraphics && displayObject.__graphics != null) {
					#if (openfl >= "9.5.0")
					displayObject.__graphics.__bitmapScaleX = displayObject.__graphics.__bitmapScaleY = 1;
					#else
					displayObject.__graphics.__bitmapScale = 1;
					#end
					openfl.display._internal.Context3DShape.render(displayObject, gfxRenderer);
				}
				else gfxRenderer.__renderDrawable(src);
				_postDraw();
			}

			displayObject.__visible = gfxSprite.__visible;
			gfxSprite.__visible = true;
		}
		else if (!onlyGraphics) {
			src.__update(false, true);
			if (src.__renderable) {
				_preDraw();
				gfxRenderer.__renderDrawable(src);
				_postDraw();
			}
		}

		if (cacheRTT != null) context.setRenderToTexture(cacheRTT, cacheRTTDepthStencil, cacheRTTAntiAlias, cacheRTTSurfaceSelector);
		else context.setRenderToBackBuffer();
	}
}
#end