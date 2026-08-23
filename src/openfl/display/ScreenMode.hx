package openfl.display;

#if sys
import lime.system.DisplayMode;

/**
	The ScreenMode object provides information about the width, height and refresh rate of a Screen.
**/
class ScreenMode
{
	/**
		The screen height of the ScreenMode in pixels.
	**/
	public var height(get, null):Int;

	/**
		The screen refresh rate of the ScreenMode in hertz.
	**/
	public var refreshRate(get, null):Int;

	/**
		The screen width of the ScreenMode in pixels.
	 */
	public var width(get, null):Int;

	@:noCompletion private function get_height():Int
	{
		return _displayMode.height;
	}

	@:noCompletion private function get_refreshRate():Int
	{
		return _displayMode.refreshRate;
	}

	@:noCompletion private function get_width():Int
	{
		return _displayMode.width;
	}

	@:noCompletion private var _displayMode:DisplayMode;

	@:noCompletion private function new(displayMode:DisplayMode)
	{
		_displayMode = displayMode;
	}
}
#end
