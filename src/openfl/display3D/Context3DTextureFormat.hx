package openfl.display3D;

/**
	Defines the values to use for specifying a texture format.
**/
enum abstract Context3DTextureFormat(Null<Int>)
{
	/**
		32-bit RGB format.
	**/
	public var RGB = 0;

	/**
		32-bit BGRA format.
	**/
	public var BGRA = 1;

	/**
		32-bit RGBA format.
	**/
	public var RGBA = 2;

	/**
		8-bit single-channel red format.
	**/
	public var R = 6;

	@:from private static function fromString(value:String):Context3DTextureFormat
	{
		return switch (value)
		{
			case "rgb": RGB;
			case "bgra": BGRA;
			case "rgba": RGBA;
			case "r": R;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : Context3DTextureFormat)
		{
			case Context3DTextureFormat.RGB: "rgb";
			case Context3DTextureFormat.BGRA: "bgra";
			case Context3DTextureFormat.RGBA: "rgba";
			case Context3DTextureFormat.R: "r";
			default: null;
		}
	}
}
