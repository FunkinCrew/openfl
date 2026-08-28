package openfl.display3D;

/**
	Defines the values to use for specifying a texture format.
**/
enum abstract Context3DTextureFormat(Null<Int>)
{
	/**
		32 bit
	**/
	public var BGRA = 1;

	/**
		8 bit, single color (RED) channel format.
	**/
	public var R = 6;

	@:from private static function fromString(value:String):Context3DTextureFormat
	{
		return switch (value)
		{
			case "bgra": BGRA;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : Context3DTextureFormat)
		{
			case Context3DTextureFormat.BGRA: "bgra";
			default: null;
		}
	}
}
