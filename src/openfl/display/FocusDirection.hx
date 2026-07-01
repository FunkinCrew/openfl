package openfl.display;

#if sys
/**
	The FocusDirection class enumerates values to be used for the `direction`
	parameter of the `assignFocus()` method of a Stage object and for the
	`direction` property of a FocusEvent object.
**/
enum abstract FocusDirection(Null<Int>)
{
	/**
		Indicates that focus should be given to the object at the end of the
		reading order.
	**/
	public var BOTTOM = 0;

	/**
		Indicates that focus object within the interactive object should not
		change.
	**/
	public var NONE = 1;

	/**
		Indicates that focus should be given to the object at the beginning of
		the reading order.
	**/
	public var TOP = 2;

	@:from private static function fromString(value:String):FocusDirection
	{
		return switch (value)
		{
			case "bottom": BOTTOM;
			case "none": NONE;
			case "top": TOP;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : FocusDirection)
		{
			case FocusDirection.BOTTOM: "bottom";
			case FocusDirection.NONE: "none";
			case FocusDirection.TOP: "top";
			default: null;
		}
	}
}
#end
