package openfl.display3D._internal;

import haxe.crypto.Md5;
import haxe.io.Bytes;
import lime.graphics.BGFXRenderContext;
import lime.graphics.bgfx.BGFXMemoryRef;
import lime.system.CFFIPointer;
import lime.system.System;
import lime.utils.Log;
import lime.utils.UInt8Array;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Manage saving and reading compiled shaders binary
 * For faster compilation times
 *
 * !!! ONLY WORKS WITH BGFX !!!
 */
class ShaderCache
{
	public static inline var CACHE_VERSION:Int = 5;

	public static var enabled:Bool = #if openfl_no_shader_cache false #else true #end;

	@:noCompletion private static var __directory:Null<String> = null;

	/**
	 * Generate a special hash key for a shader stage
	 * @param bgfx The bgfx context used to build this shader
	 * @param vertexSource The original vertex shader source
	 * @param fragmentSource The original fragment shader source
	 * @param isVertex Wether the key is for the vertex stage
	 * @return a hash key `String` for this stage
	 */
	public static function getKey(bgfx:BGFXRenderContext, vertexSource:String, fragmentSource:String, isVertex:Bool):String
	{
		var renderer:Int = bgfx.getCaps().rendererType;
		return Md5.encode('$renderer|${isVertex ? "v" : "f"}|$vertexSource|$fragmentSource');
	}

	/**
	 * Load a compiled shader memory from disk
	 * @param bgfx The bgfx context used to load this shader memory
	 * @param key The hash key for this shader
	 * @return a bgfx memory handel `BGFXMemoryRef` if a shader is found on the disk, otherwise `null`
	 */
	public static function load(bgfx:BGFXRenderContext, key:String):Null<BGFXMemoryRef>
	{
		#if sys
		if (!enabled) return null;

		var path = __getPath(key);
		if (path == null) return null;

		try
		{
			if (!FileSystem.exists(path)) return null;

			var bytes = File.getBytes(path);

			if (bytes == null || bytes.length < 4) return null;

			var magic = bytes.getString(0, 3);
			if (magic != "VSH" && magic != "FSH" && magic != "CSH") return null;

			return bgfx.copy(UInt8Array.fromBytes(bytes), bytes.length);
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	/**
	 * Load the sampler slots of a compiled shader from disk
	 * @param key The hash key for this shader
	 * @return a `Map` of sampler names to slots if found on the disk, otherwise `null`
	 */
	public static function loadSamplers(key:String):Null<Map<String, Int>>
	{
		#if sys
		if (!enabled) return null;

		var path = __getPath(key, "samplers");
		if (path == null) return null;

		try
		{
			if (!FileSystem.exists(path)) return null;

			var samplers = new Map<String, Int>();

			for (line in File.getContent(path).split("\n"))
			{
				var parts = line.split(" ");
				if (parts.length != 2) continue;

				var slot:Null<Int> = Std.parseInt(parts[1]);
				if (slot == null) return null;

				samplers.set(parts[0], slot);
			}

			return samplers;
		}
		catch (e:Dynamic)
		{
			return null;
		}
		#else
		return null;
		#end
	}

	public static function save(key:String, memory:BGFXMemoryRef, samplers:Map<String, Int>):Void
	{
		#if sys
		if (!enabled || memory == null) return;

		var bytes = __readMemory(memory);
		if (bytes == null || bytes.length == 0) return;

		var path = __getPath(key);
		var samplersPath = __getPath(key, "samplers");
		if (path == null || samplersPath == null) return;

		try
		{
			File.saveBytes(path, bytes);
			File.saveContent(samplersPath, [for (name in samplers.keys()) '$name ${samplers.get(name)}'].join("\n"));
		}
		catch (e:Dynamic)
		{
			Log.warn('Could not write shader cache to $path: $e');
		}
		#end
	}

	@:noCompletion private static function __readMemory(memory:BGFXMemoryRef):Null<Bytes>
	{
		#if cpp
		var address:Float = (memory : CFFIPointer).get();
		if (address == 0) return null;

		var size:Int = untyped __cpp__("(int)(*(unsigned int *)((char *)(size_t){0} + sizeof(void *)))", address);
		if (size <= 0) return null;

		var bytes = Bytes.alloc(size);

		for (i in 0...size)
		{
			bytes.set(i, untyped __cpp__("(int)((*(unsigned char **)(size_t){0})[{1}])", address, i));
		}

		return bytes;
		#else
		return null;
		#end
	}

	@:noCompletion private static function __getPath(key:String, extension:String = "bin"):Null<String>
	{
		#if sys
		if (__directory == null)
		{
			try
			{
				var root = System.applicationStorageDirectory;

				if (root != null)
				{
					var cacheRoot = haxe.io.Path.join([root, "shader-cache"]);
					var directory = haxe.io.Path.join([cacheRoot, 'v$CACHE_VERSION']);
					FileSystem.createDirectory(directory);
					__directory = directory;
				}
			}
			catch (e:Dynamic)
			{
				Log.warn('Could not open shader cache directory: $e');
				__directory = null;
				return null;
			}
		}

		if (__directory == null) return null;

		return haxe.io.Path.join([__directory, '$key.$extension']);
		#else
		return null;
		#end
	}
}
