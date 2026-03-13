package openfl.system;

#if !flash
#if !openfljs
/**
	The SecurityPanel class provides values for specifying which Security
	Settings panel you want to display.

	This class contains static constants that are used with the
	`Security.showSettings()` method. You cannot create new instances of the
	SecurityPanel class.

	@see `openfl.system.Security.showSettings()`
**/
#if (haxe_ver >= 4.0) enum #else @:enum #end abstract SecurityPanel(Null<Int>)
{
	/**
		When passed to `Security.showSettings()`, displays the Camera panel in
		Flash Player Settings.

		@see `openfl.system.Security.showSettings()`
	**/
	public var CAMERA = 0;

	/**
		When passed to `Security.showSettings()`, displays the panel that was
		open the last time the user closed the Flash Player Settings.

		@see `openfl.system.Security.showSettings()`
	**/
	public var DEFAULT = 1;

	/**
		When passed to `Security.showSettings()`, displays the Display panel in
		Flash Player Settings.

		@see `openfl.system.Security.showSettings()`
	**/
	public var DISPLAY = 2;

	/**
		When passed to `Security.showSettings()`, displays the Local Storage
		Settings panel in Flash Player Settings.

		@see `openfl.system.Security.showSettings()`
	**/
	public var LOCAL_STORAGE = 3;

	/**
		When passed to `Security.showSettings()`, displays the Microphone panel
		in Flash Player Settings.

		@see `openfl.system.Security.showSettings()`
	**/
	public var MICROPHONE = 4;

	/**
		When passed to `Security.showSettings()`, displays the Privacy Settings
		panel in Flash Player Settings.

		@see `openfl.system.Security.showSettings()`
	**/
	public var PRIVACY = 5;

	/**
		When passed to `Security.showSettings()`, displays the Settings Manager
		(in a separate browser window).

		@see `openfl.system.Security.showSettings()`
	**/
	public var SETTINGS_MANAGER = 6;

	@:from private static function fromString(value:String):SecurityPanel
	{
		return switch (value)
		{
			case "camera": CAMERA;
			case "default": DEFAULT;
			case "display": DISPLAY;
			case "localStorage": LOCAL_STORAGE;
			case "microphone": MICROPHONE;
			case "privacy": PRIVACY;
			case "settingsManager": SETTINGS_MANAGER;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : SecurityPanel)
		{
			case SecurityPanel.CAMERA: "camera";
			case SecurityPanel.DEFAULT: "default";
			case SecurityPanel.DISPLAY: "display";
			case SecurityPanel.LOCAL_STORAGE: "localStorage";
			case SecurityPanel.MICROPHONE: "microphone";
			case SecurityPanel.PRIVACY: "privacy";
			case SecurityPanel.SETTINGS_MANAGER: "settingsManager";
			default: null;
		}
	}
}
#else
@SuppressWarnings("checkstyle:FieldDocComment") #if (haxe_ver >= 4.0) enum #else @:enum #end abstract SecurityPanel(String) from String to String
{
	public var CAMERA = "camera";
	public var DEFAULT = "default";
	public var DISPLAY = "display";
	public var LOCAL_STORAGE = "localStorage";
	public var MICROPHONE = "microphone";
	public var PRIVACY = "privacy";
	public var SETTINGS_MANAGER = "settingsManager";
}
#end
#else
typedef SecurityPanel = flash.system.SecurityPanel;
#end
