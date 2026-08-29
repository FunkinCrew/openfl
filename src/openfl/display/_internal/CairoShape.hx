package openfl.display._internal;

import lime.graphics.cairo.CairoFilter;
import lime.graphics.cairo.CairoPattern;
import lime.math.Matrix3;
import openfl.display.CairoRenderer;
import openfl.display.DisplayObject;
import openfl.geom.Matrix;

@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
@:access(openfl.geom.Matrix)
@SuppressWarnings("checkstyle:FieldDocComment")
class CairoShape
{
	#if lime_cairo
	@:noCompletion private static var sourceTransform:Matrix3 = new Matrix3();
	#end

	public static function render(shape:DisplayObject, renderer:CairoRenderer):Void
	{
		#if lime_cairo
		if (!shape.__renderable) return;

		var alpha = renderer.__getAlpha(shape.__worldAlpha);
		if (alpha <= 0) return;

		var graphics = shape.__graphics;

		if (graphics != null)
		{
			CairoGraphics.render(graphics, renderer);

			var width = graphics.__width;
			var height = graphics.__height;
			var cairo = renderer.cairo;

			if (cairo != null && graphics.__visible && width >= 1 && height >= 1)
			{
				var transform = graphics.__worldTransform;

				renderer.__setBlendMode(shape.__worldBlendMode);
				renderer.__pushMaskObject(shape);

				var renderTransform = Matrix.__pool.get();
				renderTransform.scale(1 / graphics.__bitmapScaleX, 1 / graphics.__bitmapScaleY);
				renderTransform.concat(transform);

				renderer.applyMatrix(renderTransform, cairo);

				cairo.setSourceSurface(graphics.__cairo.target, 0, 0);

				if (alpha >= 1)
				{
					cairo.paint();
				}
				else
				{
					cairo.paintWithAlpha(alpha);
				}

				Matrix.__pool.release(renderTransform);

				renderer.__popMaskObject(shape);
			}
		}
		#end
	}

	public static inline function renderDrawable(shape:Shape, renderer:CairoRenderer):Void
	{
		CairoDisplayObject.renderDrawable(shape, renderer);
	}

	public static inline function renderDrawableMask(shape:Shape, renderer:CairoRenderer):Void
	{
		CairoDisplayObject.renderDrawableMask(shape, renderer);
	}
}
