package openfl.display3D;

#if !flash
/**
	Defines the values to use for sampler wrap mode
**/
enum abstract Context3DWrapMode(Null<Int>)
{
	/**
		Clamp texture coordinates outside the 0..1 range.

		The function is x = max(min(x,0),1)
	**/
	public var CLAMP = 0;

	/**
		Clamp in U axis but Repeat in V axis.
	**/
	public var CLAMP_U_REPEAT_V = 1;

	/**
		Repeat (tile) texture coordinates outside the 0..1 range.

		The function is x = x<0?1.0-frac(abs(x)):frac(x)
	**/
	public var REPEAT = 2;

	/**
		Repeat in U axis but Clamp in V axis.
	**/
	public var REPEAT_U_CLAMP_V = 3;

	@:from private static function fromString(value:String):Context3DWrapMode
	{
		return switch (value)
		{
			case "clamp": CLAMP;
			case "clamp_u_repeat_v": CLAMP_U_REPEAT_V;
			case "repeat": REPEAT;
			case "repeat_u_clamp_v": REPEAT_U_CLAMP_V;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : Context3DWrapMode)
		{
			case Context3DWrapMode.CLAMP: "clamp";
			case Context3DWrapMode.CLAMP_U_REPEAT_V: "clamp_u_repeat_v";
			case Context3DWrapMode.REPEAT: "repeat";
			case Context3DWrapMode.REPEAT_U_CLAMP_V: "repeat_u_clamp_v";
			default: null;
		}
	}
}
#else
typedef Context3DWrapMode = flash.display3D.Context3DWrapMode;
#end
