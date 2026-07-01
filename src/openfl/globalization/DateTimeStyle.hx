package openfl.globalization;

/**
	Enumerates constants that determine a locale-specific date and time
	formatting pattern. These constants are used when constructing a
	DateTimeFormatter object or when calling the
	`DateTimeFormatter.setDateTimeStyles()` method.

	The `CUSTOM` constant cannot be used in the DateTimeFormatter constructor or
	the `DateFormatter.setDateTimeStyles()` method. This constant is instead set
	as the `timeStyle` and `dateStyle` property as a side effect of calling the
	`DateTimeFormatter.setDateTimePattern()` method.
**/
enum abstract DateTimeStyle(Null<Int>)
{
	/**
		Specifies that a custom pattern string is used to specify the date or
		time style.
	**/
	public var CUSTOM = 0;

	/**
		Specifies the long style of a date or time.
	**/
	public var LONG = 1;

	/**
		Specifies the medium style of a date or time.
	**/
	public var MEDIUM = 2;

	/**
		Specifies that the date or time should not be included in the formatted string.
	**/
	public var NONE = 3;

	/**
		Specifies the short style of a date or time.
	**/
	public var SHORT = 4;

	@:noCompletion private inline static function fromInt(value:Null<Int>):DateTimeStyle
	{
		return cast value;
	}

	@:from private static function fromString(value:String):DateTimeStyle
	{
		return switch (value)
		{
			case "custom": CUSTOM;
			case "long": LONG;
			case "medium": MEDIUM;
			case "none": NONE;
			case "short": SHORT;
			default: null;
		}
	}

	@:noCompletion private inline function toInt():Null<Int>
	{
		return this;
	}

	@:to private function toString():String
	{
		return switch (cast this : DateTimeStyle)
		{
			case DateTimeStyle.CUSTOM: "custom";
			case DateTimeStyle.LONG: "long";
			case DateTimeStyle.MEDIUM: "medium";
			case DateTimeStyle.NONE: "none";
			case DateTimeStyle.SHORT: "short";
			default: null;
		}
	}
}
