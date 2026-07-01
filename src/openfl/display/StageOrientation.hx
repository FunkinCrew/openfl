package openfl.display;

#if !flash
/**
	The StageOrientation class defines constants enumerating the possible
	orientations of the stage and the device.
**/
enum abstract StageOrientation(Null<Int>)
{
	/**
		Specifies that the stage is currently in the default orientation of the
		device (right-side up).
	**/
	public var DEFAULT = 0;

	/**
		Specifies that the stage is currently rotated left relative to the
		default orientation.

		**Note:** When the orientation of the device is rotated left, the
		orientation of the stage must be rotated right in order to remain
		upright.
	**/
	public var ROTATED_LEFT = 1;

	/**
		Specifies that the stage is currently rotated right relative to the
		default orientation.

		**Note:** When the orientation of the device is rotated right, the
		orientation of the stage must be rotated left in order to remain
		upright.
	**/
	public var ROTATED_RIGHT = 2;

	/**
		Specifies that the device has not determined an orientation. This state
		can occur when the device is lying flat on a table and also while the
		application is initializing.
	**/
	public var UNKNOWN = 3;

	/**
		Specifies that the stage is currently upside down relative to the
		default orientation.
	**/
	public var UPSIDE_DOWN = 4;

	@:noCompletion private inline static function fromInt(value:Null<Int>):StageOrientation
	{
		return cast value;
	}

	@:from private static function fromString(value:String):StageOrientation
	{
		return switch (value)
		{
			case "default": DEFAULT;
			case "rotatedLeft": ROTATED_LEFT;
			case "rotatedRight": ROTATED_RIGHT;
			case "unknown": UNKNOWN;
			case "upsideDown": UPSIDE_DOWN;
			default: null;
		}
	}

	@:noCompletion private inline function toInt():Null<Int>
	{
		return this;
	}

	@:to private function toString():String
	{
		return switch (cast this : StageOrientation)
		{
			case StageOrientation.DEFAULT: "default";
			case StageOrientation.ROTATED_LEFT: "rotatedLeft";
			case StageOrientation.ROTATED_RIGHT: "rotatedRight";
			case StageOrientation.UNKNOWN: "unknown";
			case StageOrientation.UPSIDE_DOWN: "upsideDown";
			default: null;
		}
	}
}
#end
