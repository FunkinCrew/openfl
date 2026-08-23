package openfl.utils;

import haxe.io.Bytes;
import lime.utils.AssetManifest as LimeAssetManifest;

class AssetManifest extends LimeAssetManifest
{
	public function new()
	{
		super();
	}

	public function addBitmapData(path:String, id:String = null):Void
	{
		assets.push({
			path: path,
			id: (id != null ? id : path),
			type: AssetType.IMAGE,
			preload: true
		});
	}

	public function addBytes(path:String, id:String = null):Void
	{
		assets.push({
			path: path,
			id: (id != null ? id : path),
			type: AssetType.BINARY,
			preload: true
		});
	}

	public function addFont(name:String, id:String = null):Void
	{
		assets.push({
			path: name,
			id: (id != null ? id : name),
			type: AssetType.FONT,
			preload: true
		});
	}

	public function addSound(paths:Array<String>, id:String = null):Void
	{
		assets.push({
			pathGroup: paths,
			id: (id != null ? id : paths[0]),
			type: AssetType.SOUND,
			preload: true
		});
	}

	public function addText(path:String, id:String = null):Void
	{
		assets.push({
			path: path,
			id: (id != null ? id : path),
			type: AssetType.TEXT,
			preload: true
		});
	}

	public static function fromBytes(bytes:Bytes, rootPath:String = null):AssetManifest
	{
		return __fromLimeManifest(LimeAssetManifest.fromBytes(bytes, rootPath));
	}

	public static function fromFile(path:String, rootPath:String = null):AssetManifest
	{
		return __fromLimeManifest(LimeAssetManifest.fromFile(path, rootPath));
	}

	public static function loadFromBytes(bytes:Bytes, rootPath:String = null):Future<AssetManifest>
	{
		return LimeAssetManifest.loadFromBytes(bytes, rootPath).then(function(manifest)
		{
			return Future.withValue(__fromLimeManifest(manifest));
		});
	}

	public static function loadFromFile(path:String, rootPath:String = null):Future<AssetManifest>
	{
		return LimeAssetManifest.loadFromFile(path, rootPath).then(function(manifest)
		{
			return Future.withValue(__fromLimeManifest(manifest));
		});
	}

	public static function parse(data:String, rootPath:String = null):AssetManifest
	{
		return __fromLimeManifest(LimeAssetManifest.parse(data, rootPath));
	}

	@:noCompletion private static function __fromLimeManifest(limeManifest:LimeAssetManifest):AssetManifest
	{
		var manifest:AssetManifest = null;
		if (limeManifest != null)
		{
			manifest = new AssetManifest();
			manifest.assets = limeManifest.assets;
			manifest.libraryArgs = limeManifest.libraryArgs;
			manifest.libraryType = limeManifest.libraryType;
			manifest.name = limeManifest.name;
			manifest.rootPath = limeManifest.rootPath;
			manifest.version = limeManifest.version;
		}
		return manifest;
	}
}
