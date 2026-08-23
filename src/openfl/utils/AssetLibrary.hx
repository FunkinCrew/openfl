package openfl.utils;

import lime.graphics.Image;
import lime.media.AudioBuffer;
import lime.text.Font;
import lime.utils.AssetLibrary as LimeAssetLibrary;
import lime.utils.AssetManifest;
import lime.utils.Bytes;
import openfl.display.MovieClip;

class AssetLibrary extends LimeAssetLibrary
{
	@:noCompletion private var __proxy:LimeAssetLibrary;

	public function new()
	{
		super();
	}

	public function bind(className:String, instance:Dynamic = null):Bool
	{
		return false;
	}

	public override function exists(id:String, type:String):Bool
	{
		if (__proxy != null)
		{
			return __proxy.exists(id, type);
		}
		else
		{
			return super.exists(id, type);
		}
	}

	public static function fromBundle(bundle:AssetBundle):AssetLibrary
	{
		var library = LimeAssetLibrary.fromBundle(bundle);

		if (library != null)
		{
			if ((library is AssetLibrary))
			{
				return cast library;
			}
			else
			{
				var _library = new AssetLibrary();
				_library.__proxy = library;
				return _library;
			}
		}
		else
		{
			return null;
		}
	}

	public static function fromBytes(bytes:ByteArray, rootPath:String = null):AssetLibrary
	{
		return cast fromManifest(AssetManifest.fromBytes(bytes, rootPath));
	}

	public static function fromFile(path:String, rootPath:String = null):AssetLibrary
	{
		return cast fromManifest(AssetManifest.fromFile(path, rootPath));
	}

	public static function fromManifest(manifest:AssetManifest):AssetLibrary
	{
		var library = LimeAssetLibrary.fromManifest(manifest);

		if (library != null)
		{
			if ((library is AssetLibrary))
			{
				return cast library;
			}
			else
			{
				var _library = new AssetLibrary();
				_library.__proxy = library;
				return _library;
			}
		}
		else
		{
			return null;
		}
	}

	public override function getAsset(id:String, type:String):Dynamic
	{
		if (__proxy != null)
		{
			return __proxy.getAsset(id, type);
		}
		else
		{
			return super.getAsset(id, type);
		}
	}

	public override function getAudioBuffer(id:String):AudioBuffer
	{
		if (__proxy != null)
		{
			return __proxy.getAudioBuffer(id);
		}
		else
		{
			return super.getAudioBuffer(id);
		}
	}

	public override function getBytes(id:String):Bytes
	{
		if (__proxy != null)
		{
			return __proxy.getBytes(id);
		}
		else
		{
			return super.getBytes(id);
		}
	}

	public override function getFont(id:String):Font
	{
		if (__proxy != null)
		{
			return __proxy.getFont(id);
		}
		else
		{
			return super.getFont(id);
		}
	}

	public override function getImage(id:String):Image
	{
		if (__proxy != null)
		{
			return __proxy.getImage(id);
		}
		else
		{
			return super.getImage(id);
		}
	}

	public function getMovieClip(id:String):MovieClip
	{
		return null;
	}

	public override function getPath(id:String):String
	{
		if (__proxy != null)
		{
			return __proxy.getPath(id);
		}
		else
		{
			return super.getPath(id);
		}
	}

	public override function getText(id:String):String
	{
		if (__proxy != null)
		{
			return __proxy.getText(id);
		}
		else
		{
			return super.getText(id);
		}
	}

	public override function isLocal(id:String, type:String):Bool
	{
		if (__proxy != null)
		{
			return __proxy.isLocal(id, type);
		}
		else
		{
			return super.isLocal(id, type);
		}
	}

	public override function list(type:String):Array<String>
	{
		if (__proxy != null)
		{
			return __proxy.list(type);
		}
		else
		{
			return super.list(type);
		}
	}

	public override function loadAsset(id:String, type:String):Future<Dynamic>
	{
		if (__proxy != null)
		{
			return __proxy.loadAsset(id, type);
		}
		else
		{
			return super.loadAsset(id, type);
		}
	}

	public override function load():Future<LimeAssetLibrary>
	{
		if (__proxy != null)
		{
			return __proxy.load();
		}
		else
		{
			return super.load();
		}
	}

	public override function loadAudioBuffer(id:String):Future<AudioBuffer>
	{
		if (__proxy != null)
		{
			return __proxy.loadAudioBuffer(id);
		}
		else
		{
			return super.loadAudioBuffer(id);
		}
	}

	public override function loadBytes(id:String):Future<Bytes>
	{
		if (__proxy != null)
		{
			return __proxy.loadBytes(id);
		}
		else
		{
			return super.loadBytes(id);
		}
	}

	public override function loadFont(id:String):Future<Font>
	{
		if (__proxy != null)
		{
			return __proxy.loadFont(id);
		}
		else
		{
			return super.loadFont(id);
		}
	}

	public static function loadFromBytes(bytes:ByteArray, rootPath:String = null):Future<AssetLibrary>
	{
		return AssetManifest.loadFromBytes(bytes, rootPath).then(function(manifest)
		{
			return loadFromManifest(manifest);
		});
	}

	public static function loadFromFile(path:String, rootPath:String = null):Future<AssetLibrary>
	{
		return AssetManifest.loadFromFile(path, rootPath).then(function(manifest)
		{
			return loadFromManifest(manifest);
		});
	}

	public static function loadFromManifest(manifest:AssetManifest):Future<AssetLibrary>
	{
		var library:AssetLibrary = cast fromManifest(manifest);

		if (library != null)
		{
			return library.load().then(function(library)
			{
				return Future.withValue(cast library);
			});
		}
		else
		{
			return cast Future.withError("Could not load asset manifest");
		}
	}

	public override function loadImage(id:String):Future<Image>
	{
		if (__proxy != null)
		{
			return __proxy.loadImage(id);
		}
		else
		{
			return super.loadImage(id);
		}
	}

	public function loadMovieClip(id:String):Future<MovieClip>
	{
		return Future.withValue(getMovieClip(id));
	}

	public override function loadText(id:String):Future<String>
	{
		if (__proxy != null)
		{
			return __proxy.loadText(id);
		}
		else
		{
			return super.loadText(id);
		}
	}

	public override function unload():Void
	{
		if (__proxy != null)
		{
			return __proxy.unload();
		}
		else
		{
			return super.unload();
		}
	}
}
