package openfl.desktop;

#if sys
/**
	The NotificationType class defines constants for use in the priority
	parameter of the DockIcon `bounce()` method and the type parameter of the
	NativeWindow `notifyUser()` method.

	@see `openfl.desktop.DockIcon.bounce()`
	@see `openfl.display.NativeWindow.notifyUser()`
**/
enum abstract NotificationType(Null<Int>)
{
	/**
		Specifies that a notification alert is critical in nature and the user
		should attend to it promptly.
	**/
	public var CRITICAL = 0;

	/**
		Specifies that a notification alert is informational in nature and the
		user can safely ignore it.
	**/
	public var INFORMATIONAL = 1;

	@:from private static function fromString(value:String):NotificationType
	{
		return switch (value)
		{
			case "critical": CRITICAL;
			case "informational": INFORMATIONAL;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : NotificationType)
		{
			case NotificationType.CRITICAL: "critical";
			case NotificationType.INFORMATIONAL: "informational";
			default: null;
		}
	}
}
#end
