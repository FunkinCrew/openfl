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

	private function get_height():Int
	{
		return _displayMode.height;
	}

	private function get_refreshRate():Int
	{
		return _displayMode.refreshRate;
	}

	private function get_width():Int
	{
		return _displayMode.width;
	}

	private var _displayMode:DisplayMode;

	private function new(displayMode:DisplayMode)
	{
		_displayMode = displayMode;
	}
}
#end
