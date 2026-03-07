package openfl.display;

#if !flash
import openfl.display._internal.GraphicsDataType;
import openfl.display._internal.GraphicsFillType;
import openfl.geom.Matrix;

/**
	Defines a bitmap fill. The bitmap can be smoothed, repeated or tiled to
	fill the area; or manipulated using a transformation matrix.
	Use a GraphicsBitmapFill object with the `Graphics.drawGraphicsData()`
	method. Drawing a GraphicsBitmapFill object is the equivalent of calling
	the `Graphics.beginBitmapFill()` method.
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:final class GraphicsTilemapFill implements IGraphicsData implements IGraphicsFill
{
	/**
		The tilemap to fill.
	**/
	public var tilemap:Tilemap;

	@:noCompletion private var __graphicsDataType(default, null):GraphicsDataType;
	@:noCompletion private var __graphicsFillType(default, null):GraphicsFillType;

	/**
		Creates a new GraphicsBitmapFill object.

		@param tilemap A tilemap that contains tiles to render.
	**/
	public function new(tilemap:Tilemap = null)
	{
		this.tilemap = tilemap;

		this.__graphicsDataType = TILEMAP;
		this.__graphicsFillType = TILEMAP_FILL;
	}
}
// #else
// typedef GraphicsBitmapFill = Dynamic;
#end
