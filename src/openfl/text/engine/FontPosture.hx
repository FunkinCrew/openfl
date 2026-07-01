package openfl.text.engine;

#if sys
/**
	The FontPosture class is an enumeration of constant values used with
	`FontDescription.fontPosture` and `StageText.fontPostures` to set text to
	italic or normal.

	@see `openfl.text.StageText.fontPosture`
**/
enum abstract FontPosture(Null<Int>)
{
	/**
		Used to indicate italic font posture.
	**/
	public var ITALIC = 0;

	/**
		Used to indicate normal font posture.
	**/
	public var NORMAL = 1;

	@:from private static function fromString(value:String):FontPosture
	{
		return switch (value)
		{
			case "italic": ITALIC;
			case "normal": NORMAL;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : FontPosture)
		{
			case FontPosture.ITALIC: "italic";
			case FontPosture.NORMAL: "normal";
			default: null;
		}
	}
}
#end
