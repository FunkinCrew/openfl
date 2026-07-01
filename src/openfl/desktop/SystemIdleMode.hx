package openfl.desktop;

#if sys
/**
	The SystemIdleMode class provides constant values for system idle behaviors.
	These constants are used in the `systemIdleMode` property of the
	`NativeApplication` class.

	@see `openfl.desktop.NativeApplication.systemIdleMode`
**/
enum abstract SystemIdleMode(Null<Int>)
{
	/**
		Prevents the system from dropping into an idle mode.

		On Android, the application must specify the Android permissions for
		DISABLE_KEYGUARD and WAKE_LOCK in the application descriptor or the
		operating system will not honor this setting.
	**/
	public var KEEP_AWAKE = 0;

	/**
		The system follows the normal "idle user" behavior.
	**/
	public var NORMAL = 1;

	@:from private static function fromString(value:String):SystemIdleMode
	{
		return switch (value)
		{
			case "keepAwake": KEEP_AWAKE;
			case "normal": NORMAL;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : SystemIdleMode)
		{
			case SystemIdleMode.KEEP_AWAKE: "keepAwake";
			case SystemIdleMode.NORMAL: "normal";
			default: null;
		}
	}
}
#end
