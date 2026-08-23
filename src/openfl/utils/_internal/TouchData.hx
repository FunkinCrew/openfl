package openfl.utils._internal;

import openfl.display.DisplayObject;
import openfl.display.InteractiveObject;
import lime.ui.Touch;

@SuppressWarnings("checkstyle:FieldDocComment")
class TouchData
{
	public static var __pool:ObjectPool<TouchData> = new ObjectPool<TouchData>(function() return new TouchData(), function(data) data.reset());

	public var rollOutStack:Array<DisplayObject>;
	public var touch:Touch;
	public var touchDownTarget:InteractiveObject;
	public var touchOverTarget:InteractiveObject;

	public function new()
	{
		rollOutStack = [];
	}

	public function reset():Void
	{
		touch = null;
		touchDownTarget = null;
		touchOverTarget = null;

		rollOutStack.splice(0, rollOutStack.length);
	}
}
