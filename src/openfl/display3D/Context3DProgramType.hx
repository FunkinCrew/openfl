package openfl.display3D;

#if !flash
/**
	Defines the values to use for specifying whether a shader program is a fragment
	or a vertex program.
**/
#if (haxe_ver >= 4.0) enum #else @:enum #end abstract Context3DProgramType(Null<Int>)
{
	/**
		A fragment (or pixel) program.
	**/
	public var FRAGMENT = 0;

	/**
		A vertex program.
	**/
	public var VERTEX = 1;

	@:from private static function fromString(value:String):Context3DProgramType
	{
		return switch (value)
		{
			case "fragment": FRAGMENT;
			case "vertex": VERTEX;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : Context3DProgramType)
		{
			case Context3DProgramType.FRAGMENT: "fragment";
			case Context3DProgramType.VERTEX: "vertex";
			default: null;
		}
	}
}
#else
typedef Context3DProgramType = flash.display3D.Context3DProgramType;
#end
