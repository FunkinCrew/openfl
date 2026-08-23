package openfl.text;

import lime.text.Font as LimeFont;
import openfl.utils.Assets;
import openfl.utils.ByteArray;
import openfl.utils.Future;

/**
	The Font class is used to manage embedded fonts in SWF files. Embedded
	fonts are represented as a subclass of the Font class. The Font class is
	currently useful only to find out information about embedded fonts; you
	cannot alter a font by using this class. You cannot use the Font class to
	load external fonts, or to create an instance of a Font object by itself.
	Use the Font class as an abstract base class.
**/
class Font extends LimeFont
{
	/**
		The name of an embedded font.
	**/
	public var fontName(get, set):String;

	/**
		The style of the font. This value can be any of the values defined in the
		FontStyle class.
	**/
	public var fontStyle:FontStyle;

	/**
		The type of the font. This value can be any of the constants defined in
		the FontType class.
	**/
	public var fontType:FontType;

	@:noCompletion private static var __fontByName:Map<String, Font> = new Map();
	@:noCompletion private static var __registeredFonts:Array<Font> = new Array();

	@:noCompletion private var __initialized:Bool;

	public function new(name:String = null)
	{
		super(name);
	}

	/**
		Specifies whether to provide a list of the currently available embedded
		fonts.

		@param enumerateDeviceFonts Indicates whether you want to limit the list
									to only the currently available embedded
									fonts. If this is set to `true`
									then a list of all fonts, both device fonts
									and embedded fonts, is returned. If this is
									set to `false` then only a list of
									embedded fonts is returned.
		@return A list of available fonts as an array of Font objects.
	**/
	public static function enumerateFonts(enumerateDeviceFonts:Bool = false):Array<Font>
	{
		#if native
		if (enumerateDeviceFonts)
		{
			var _allFonts = __registeredFonts.copy();
			var files = sys.FileSystem.readDirectory(lime.system.System.fontsDirectory);
			for (file in files)
			{
				if (file.toLowerCase().indexOf('.ttf') != -1) _allFonts.push(fromFile(lime.system.System.fontsDirectory + file));
			}

			// Automatically installed fonts are stored per user basis in an alternative location found
			// in the local appData path on Windows. In this case, we check if the path exists and add these
			// device fonts to the array.
			#if windows
			var alternateFontsDirectory = '${Sys.getEnv("LocalAppData")}\\Microsoft\\Windows\\Fonts';
			if (sys.FileSystem.exists(alternateFontsDirectory))
			{
				files = sys.FileSystem.readDirectory(alternateFontsDirectory);
				for (file in files)
				{
					if (file.toLowerCase().indexOf('.ttf') != -1) _allFonts.push(fromFile(alternateFontsDirectory + file));
				}
			}
			#end

			return _allFonts;
		}
		#end
		return __registeredFonts;
	}

	/**
		Creates a new Font from bytes (a haxe.io.Bytes or openfl.utils.ByteArray)
		synchronously. This means that the Font will be returned immediately (if
		supported).

		@param	bytes	A haxe.io.Bytes or openfl.utils.ByteArray instance
		@returns	A new Font if successful, or `null` if unsuccessful
	**/
	public static function fromBytes(bytes:ByteArray):Font
	{
		var font = new Font();

		font.__fromBytes(bytes);

		return #if lime_cffi (font.src != null) ? font : null #else font #end;
	}

	/**
		Creates a new Font from a file path synchronously. This means that the
		Font will be returned immediately (if supported).

		@param	path	A local file path containing a font
		@returns	A new Font if successful, or `null` if unsuccessful
	**/
	public static function fromFile(path:String):Font
	{
		if (path == null) return null;

		var font = new Font();

		font.__fromFile(path);

		return #if lime_cffi (font.src != null) ? font : null #else font #end;
	}

	/**
		Creates a new Font from haxe.io.Bytes or openfl.utils.ByteArray data
		asynchronously. The font decoding will occur in the background.
		Progress, completion and error callbacks will be dispatched in the current
		thread using callbacks attached to a returned Future object.

		@param	bytes	A haxe.io.Bytes or openfl.utils.ByteArray instance
		@returns	A Future Font
	**/
	public static function loadFromBytes(bytes:ByteArray):Future<Font>
	{
		return LimeFont.loadFromBytes(bytes).then(function(limeFont)
		{
			var font = new Font();
			font.__fromLimeFont(limeFont);

			return Future.withValue(font);
		});
	}

	/**
		Creates a new Font from a file path or web address asynchronously. The file
		load and font decoding will occur in the background.
		Progress, completion and error callbacks will be dispatched in the current
		thread using callbacks attached to a returned Future object.

		@param	path	A local file path or web address containing a font
		@returns	A Future Font
	**/
	public static function loadFromFile(path:String):Future<Font>
	{
		return LimeFont.loadFromFile(path).then(function(limeFont)
		{
			var font = new Font();
			font.__fromLimeFont(limeFont);

			return Future.withValue(font);
		});
	}

	/**
		Creates a new Font from a font name asynchronously. This feature should work
		for embedded CSS fonts on the HTML5 target, but is not implemented for
		registered OS fonts on native targets currently. The file
		load and font decoding will occur in the background.
		Progress, completion and error callbacks will be dispatched in the current
		thread using callbacks attached to a returned Future object.

		@param	path	A font name
		@returns	A Future Font
	**/
	public static function loadFromName(path:String):Future<Font>
	{
		return LimeFont.loadFromName(path).then(function(limeFont)
		{
			var font = new Font();
			font.__fromLimeFont(limeFont);

			return Future.withValue(font);
		});
	}

	/**
		Registers a font in the global font list.

	**/
	public static function registerFont(font:Dynamic):Void
	{
		var instance:Font = null;

		if (Type.getClass(font) == null)
		{
			instance = cast(Type.createInstance(font, []), Font);
		}
		else
		{
			instance = cast(font, Font);
		}

		if (instance != null)
		{
			/*if (Reflect.hasField (font, "resourceName")) {

				instance.fontName = __ofResource (Reflect.field (font, "resourceName"));

			}*/

			__registeredFonts.push(instance);
			__fontByName[instance.fontName] = instance;
		}
	}

	@:noCompletion private function __fromLimeFont(font:LimeFont):Void
	{
		__copyFrom(font);
	}

	@:noCompletion private function __initialize():Bool
	{
		#if native
		if (!__initialized)
		{
			if (src != null)
			{
				// TODO: How does src get defined without being initialized in Lime?
				if (unitsPerEM == 0) __initializeSource();
				__initialized = true;
			}
			else if (src == null && __fontID != null && Assets.isLocal(__fontID))
			{
				__fromBytes(Assets.getBytes(__fontID));
				__initialized = true;
			}
		}
		#end

		return __initialized;
	}

	// Get & Set Methods
	@:noCompletion private inline function get_fontName():String
	{
		return name;
	}

	@:noCompletion private inline function set_fontName(value:String):String
	{
		return name = value;
	}
}
