package openfl.display;

import openfl.display._internal.GraphicsDataType;
import openfl.display._internal.GraphicsFillType;

/**
	Indicates the end of a graphics fill. Use a GraphicsEndFill object with the
	`Graphics.drawGraphicsData()` method.

	Drawing a GraphicsEndFill object is the equivalent of calling the
	`Graphics.endFill()` method.

	@see [Using graphics data classes](https://books.openfl.org/openfl-developers-guide/using-the-drawing-api/advanced-use-of-the-drawing-api/using-graphics-data-classes.html)
**/
@:final class GraphicsEndFill implements IGraphicsData implements IGraphicsFill
{
	@:noCompletion private var __graphicsDataType(default, null):GraphicsDataType;
	@:noCompletion private var __graphicsFillType(default, null):GraphicsFillType;

	/**
		Creates an object to use with the `Graphics.drawGraphicsData()`
		method to end the fill, explicitly.
	**/
	public function new()
	{
		this.__graphicsDataType = END;
		this.__graphicsFillType = END_FILL;
	}
}
