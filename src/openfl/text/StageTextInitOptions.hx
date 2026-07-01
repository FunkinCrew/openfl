package openfl.text;

#if sys
/**
	The StageTextInitOptions class defines the options available for initializing a StageText object.

	@see openfl.text.StageText
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class StageTextInitOptions
{
	/**
		Specifies whether the StageText object displays multiple lines of text.
	**/
	public var multiline:Bool;

	/**
		Creates a StageTextInitOptions object.
	**/
	public function new(multiline:Bool = false)
	{
		this.multiline = multiline;
	}
}
#end
