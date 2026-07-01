package openfl.display3D;

#if !flash
/**
	Defines the values to use for specifying 3D buffer comparisons in the
	`setDepthTest()` and `setStencilAction()` methods of a Context3D instance.
**/
#if (haxe_ver >= 4.0) enum #else @:enum #end abstract Context3DCompareMode(Null<Int>)
{
	/**
		The comparison always evaluates as true.
	**/
	public var ALWAYS = 0;

	/**
		Equal (==).
	**/
	public var EQUAL = 1;

	/**
		Greater than (>).
	**/
	public var GREATER = 2;

	/**
		Greater than or equal (>=).
	**/
	public var GREATER_EQUAL = 3;

	/**
		Less than (<).
	**/
	public var LESS = 4;

	/**
		Less than or equal (<=).
	**/
	public var LESS_EQUAL = 5;

	/**
		The comparison never evaluates as true.
	**/
	public var NEVER = 6;

	/**
		Not equal (!=).
	**/
	public var NOT_EQUAL = 7;

	@:from private static function fromString(value:String):Context3DCompareMode
	{
		return switch (value)
		{
			case "always": ALWAYS;
			case "equal": EQUAL;
			case "greater": GREATER;
			case "greaterEqual": GREATER_EQUAL;
			case "less": LESS;
			case "lessEqual": LESS_EQUAL;
			case "never": NEVER;
			case "notEqual": NOT_EQUAL;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : Context3DCompareMode)
		{
			case Context3DCompareMode.ALWAYS: "always";
			case Context3DCompareMode.EQUAL: "equal";
			case Context3DCompareMode.GREATER: "greater";
			case Context3DCompareMode.GREATER_EQUAL: "greaterEqual";
			case Context3DCompareMode.LESS: "less";
			case Context3DCompareMode.LESS_EQUAL: "lessEqual";
			case Context3DCompareMode.NEVER: "never";
			case Context3DCompareMode.NOT_EQUAL: "notEqual";
			default: null;
		}
	}
}
#else
typedef Context3DCompareMode = flash.display3D.Context3DCompareMode;
#end
