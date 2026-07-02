package openfl.utils._internal;

#if !lime
import haxe.PosInfos;

@SuppressWarnings([
	"checkstyle:FieldDocComment",
	"checkstyle:Dynamic",
	"checkstyle:NullableParameter"
])
class Log
{
	public static var level:LogLevel;
	public static var throwErrors:Bool = true;

	public static function debug(message:Dynamic, ?info:PosInfos):Void
	{
		if (level >= LogLevel.DEBUG)
		{
			#if js
			untyped js.Syntax.code("console").debug("[" + info.className + "] " + message);
			#else
			println("[" + info.className + "] " + Std.string(message));
			#end
		}
	}

	public static function error(message:Dynamic, ?info:PosInfos):Void
	{
		if (level >= LogLevel.ERROR)
		{
			var message = "[" + info.className + "] ERROR: " + message;

			if (throwErrors)
			{
				throw message;
			}
			else
			{
				#if js
				untyped js.Syntax.code("console").error(message);
				#else
				println(message);
				#end
			}
		}
	}

	public static function info(message:Dynamic, ?info:PosInfos):Void
	{
		if (level >= LogLevel.INFO)
		{
			#if js
			untyped js.Syntax.code("console").info("[" + info.className + "] " + message);
			#else
			println("[" + info.className + "] " + Std.string(message));
			#end
		}
	}

	public static inline function print(message:Dynamic):Void
	{
		#if sys
		Sys.print(Std.string(message));
		#elseif js
		untyped js.Syntax.code("console").log(message);
		#else
		@SuppressWarnings("checkstyle:Trace") trace(message);
		#end
	}

	public static inline function println(message:Dynamic):Void
	{
		#if sys
		Sys.println(Std.string(message));
		#elseif js
		untyped js.Syntax.code("console").log(message);
		#else
		@SuppressWarnings("checkstyle:Trace") trace(Std.string(message));
		#end
	}

	public static function verbose(message:Dynamic, ?info:PosInfos):Void
	{
		if (level >= LogLevel.VERBOSE)
		{
			println("[" + info.className + "] " + message);
		}
	}

	public static function warn(message:Dynamic, ?info:PosInfos):Void
	{
		if (level >= LogLevel.WARN)
		{
			#if js
			untyped js.Syntax.code("console").warn("[" + info.className + "] WARNING: " + message);
			#else
			println("[" + info.className + "] WARNING: " + Std.string(message));
			#end
		}
	}

	private static function __init__():Void
	{
		#if no_traces
		level = NONE;
		#elseif verbose
		level = VERBOSE;
		#else
		#if sys
		var args = Sys.args();
		if (args.indexOf("-v") > -1 || args.indexOf("-verbose") > -1)
		{
			level = VERBOSE;
		}
		else
		#end
		{
			#if debug
			level = DEBUG;
			#else
			level = INFO;
			#end
		}
		#end

		#if js
		if (untyped js.Syntax.code("typeof console") == "undefined")
		{
			untyped js.Syntax.code("console = {}");
		}
		var _console = untyped js.Syntax.code("console");
		if (_console.log == null)
		{
			_console.log = function() {};
		}
		#end
	}
}

enum abstract LogLevel(Int) from Int to Int from UInt to UInt
{
	public var NONE = 0;
	public var ERROR = 1;
	public var WARN = 2;
	public var INFO = 3;
	public var DEBUG = 4;
	public var VERBOSE = 5;

	@:op(A > B) private static inline function gt(a:LogLevel, b:LogLevel):Bool
	{
		return (a : Int) > (b : Int);
	}

	@:op(A >= B) private static inline function gte(a:LogLevel, b:LogLevel):Bool
	{
		return (a : Int) >= (b : Int);
	}

	@:op(A < B) private static inline function lt(a:LogLevel, b:LogLevel):Bool
	{
		return (a : Int) < (b : Int);
	}

	@:op(A <= B) private static inline function lte(a:LogLevel, b:LogLevel):Bool
	{
		return (a : Int) <= (b : Int);
	}
}
#else
typedef Log = lime.utils.Log;
typedef LogLevel = lime.utils.LogLevel;
#end
