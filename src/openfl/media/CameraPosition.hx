package openfl.media;

#if (!flash && sys && (!flash_doc_gen || air_doc_gen))
/**
	The CameraPosition class defines constants for the `position` property of
	the Camera class.

	@see `openfl.media.Camera`
**/
enum abstract CameraPosition(Null<Int>)
{
	/**
		The `Camera.position` property returns this value for a back camera.
	**/
	public var BACK = 0;

	/**
		The `Camera.position` property returns this value for a front camera.
	**/
	public var FRONT = 1;

	/**
		The `Camera.position` property returns this value when the position of
		the Camera cannot be determined. This is the default value.
	**/
	public var UNKNOWN = 2;

	@:from private static function fromString(value:String):CameraPosition
	{
		return switch (value)
		{
			case "back": BACK;
			case "front": FRONT;
			case "unknown": UNKNOWN;
			default: null;
		}
	}

	@:to private function toString():String
	{
		return switch (cast this : CameraPosition)
		{
			case CameraPosition.BACK: "back";
			case CameraPosition.FRONT: "front";
			case CameraPosition.UNKNOWN: "unknown";
			default: null;
		}
	}
}
#end
