package openfl.display._internal;

import openfl.display.CanvasRenderer;
import openfl.display.DisplayObject;
import openfl.geom.Matrix;

@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
@:access(openfl.geom.Matrix)
@SuppressWarnings("checkstyle:FieldDocComment")
class CanvasShape
{
	public static inline function render(shape:DisplayObject, renderer:CanvasRenderer):Void
	{
		#if (js && html5)
		if (!shape.__renderable) return;

		var alpha = renderer.__getAlpha(shape.__worldAlpha);
		if (alpha <= 0) return;

		var graphics = shape.__graphics;

		if (graphics != null)
		{
			CanvasGraphics.render(graphics, renderer);

			var width = graphics.__width;
			var height = graphics.__height;
			var canvas = graphics.__canvas;

			if (canvas != null && graphics.__visible && width > 0 && height > 0)
			{
				var transform = graphics.__worldTransform;
				var context = renderer.context;
				var scrollRect = shape.__scrollRect;

				// TODO: Render for scroll rect?

				if (scrollRect == null || (scrollRect.width > 0 && scrollRect.height > 0))
				{
					renderer.__setBlendMode(shape.__worldBlendMode);
					renderer.__pushMaskObject(shape);

					context.globalAlpha = alpha;

					var renderTransform = Matrix.__pool.get();
					renderTransform.scale(1 / graphics.__bitmapScaleX, 1 / graphics.__bitmapScaleY);
					renderTransform.concat(transform);

					renderer.setTransform(renderTransform, context);

					context.drawImage(canvas, 0, 0, width, height);

					Matrix.__pool.release(renderTransform);

					renderer.__popMaskObject(shape);
				}
			}
		}
		#end
	}
}
