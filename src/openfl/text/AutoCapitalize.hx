package openfl.text;

#if sys
/**
	The AutoCapitalize class defines constants for the `autoCapitalize` property
	of the StageText class.

	@see `openfl.text.StageText.autoCapitalize`
**/
enum abstract AutoCapitalize(Null<Int>)
{
	/**
		Capitalize every character.
	**/
	public var ALL = 0;

	/**
		No automatic capitalization.
	**/
	public var NONE = 1;

	/**
		Capitalize the first word of every sentence.
	**/
	public var SENTENCE = 2;

	/**
		Capitalize every word.
	**/
	public var WORD = 3;

	@:from private static function fromString(value:String):AutoCapitalize
	{
		return switch (value)
		{
			case "all": ALL;
			case "none": NONE;
			case "sentence": SENTENCE;
			case "word": WORD;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : AutoCapitalize)
		{
			case AutoCapitalize.ALL: "all";
			case AutoCapitalize.NONE: "none";
			case AutoCapitalize.SENTENCE: "sentence";
			case AutoCapitalize.WORD: "word";
			default: null;
		}
	}
}
#end
