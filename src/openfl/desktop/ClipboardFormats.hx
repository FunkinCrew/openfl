package openfl.desktop;

#if !flash
/**
	The ClipboardFormats class defines constants for the names of the standard
	data formats used with the Clipboard class. Flash Player 10 only supports
	TEXT_FORMAT, RICH_TEXT_FORMAT, and HTML_FORMAT.
**/
enum abstract ClipboardFormats(Null<Int>)
{
	/**
		HTML data.

		_OpenFL target support:_ Not currently supported, except when targeting AIR.
	**/
	public var HTML_FORMAT = 0;

	/**
		Rich Text Format data.

		_OpenFL target support:_ Not currently supported, except when targeting AIR.
	**/
	public var RICH_TEXT_FORMAT = 1;

	/**
		String data.
	**/
	public var TEXT_FORMAT = 2;

	@:from private static function fromString(value:String):ClipboardFormats
	{
		return switch (value)
		{
			case "air:html": HTML_FORMAT;
			case "air:rtf": RICH_TEXT_FORMAT;
			case "air:text": TEXT_FORMAT;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : ClipboardFormats)
		{
			case ClipboardFormats.HTML_FORMAT: "air:html";
			case ClipboardFormats.RICH_TEXT_FORMAT: "air:rtf";
			case ClipboardFormats.TEXT_FORMAT: "air:text";
			default: null;
		}
	}
}
#else
typedef ClipboardFormats = flash.desktop.ClipboardFormats;
#end
