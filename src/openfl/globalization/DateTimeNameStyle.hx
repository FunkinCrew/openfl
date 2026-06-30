package openfl.globalization;

#if !flash
/**
	The DateTimeNameStyle class enumerates constants that control the length of
	the month names and weekday names that are used when formatting dates. Use
	these constants for the `nameStyle` parameter of the DateTimeFormatter
	`getMonthNames()` and `getWeekDayNames()` methods.

	The `LONG_ABBREVIATION` and `SHORT_ABBREVIATION` may be the same or
	different depending on the operating system and browser settings.
**/
#if (haxe_ver >= 4.0) enum #else @:enum #end abstract DateTimeNameStyle(Null<Int>)
{
	/**
		Specifies the full form or full name style for month names and weekday
		names. Examples: Tuesday, November.
	**/
	public var FULL = 0;

	/**
		Specifies the long abbreviation style for month names and weekday names.
		Examples: Tues for Tuesday, Nov for November.
	**/
	public var LONG_ABBREVIATION = 1;

	/**
		Specifies the short abbreviation style for month names and weekday names.
		Examples: T for Tuesday, N for November.
	**/
	public var SHORT_ABBREVIATION = 2;

	@:noCompletion private inline static function fromInt(value:Null<Int>):DateTimeNameStyle
	{
		return cast value;
	}

	@:from private static function fromString(value:String):DateTimeNameStyle
	{
		return switch (value)
		{
			case "full": FULL;
			case "longAbbreviation": LONG_ABBREVIATION;
			case "shortAbbreviation": SHORT_ABBREVIATION;
			default: null;
		}
	}

	@:noCompletion private inline function toInt():Null<Int>
	{
		return this;
	}

	@:to private function toString():String
	{
		return switch (cast this : DateTimeNameStyle)
		{
			case DateTimeNameStyle.FULL: "full";
			case DateTimeNameStyle.LONG_ABBREVIATION: "longAbbreviation";
			case DateTimeNameStyle.SHORT_ABBREVIATION: "shortAbbreviation";
			default: null;
		}
	}
}
#else
typedef DateTimeNameStyle = flash.globalization.DateTimeNameStyle;
#end
