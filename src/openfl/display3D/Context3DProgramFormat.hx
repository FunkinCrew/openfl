package openfl.display3D;

/**
	Defines the values to use for specifying a Program3D source format.
**/
enum abstract Context3DProgramFormat(Null<Int>)
{
	/**
		The program will use the AGAL (Adobe Graphics Assembly Language) format
	**/
	public var AGAL = 0;

	/**
		The program will use the GLSL (GL Shader Language) format
	**/
	public var GLSL = 1;

	@:from private static function fromString(value:String):Context3DProgramFormat
	{
		return switch (value)
		{
			case "agal": AGAL;
			case "glsl": GLSL;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : Context3DProgramFormat)
		{
			case Context3DProgramFormat.AGAL: "agal";
			case Context3DProgramFormat.GLSL: "glsl";
			default: null;
		}
	}
}
