package openfl.utils._internal;

import haxe.PosInfos;
import lime.utils.Log;
import openfl.display.MovieClip;
import openfl.display.Application;

@SuppressWarnings("checkstyle:FieldDocComment")
class Lib
{
	public static var application:Application;
	public static var current:MovieClip;
	@:noCompletion private static var __sentWarnings:Map<String, Bool> = new Map();

	@SuppressWarnings("checkstyle:NullableParameter")
	public static function notImplemented(?posInfo:PosInfos):Void
	{
		var api = posInfo.className + "." + posInfo.methodName;

		if (!__sentWarnings.exists(api))
		{
			__sentWarnings.set(api, true);

			Log.warn(posInfo.methodName + " is not implemented", posInfo);
		}
	}
}
