package openfl.utils;

import openfl.utils._internal.Log;
import openfl.display.Shader;
import openfl.display.ShaderPrecision;

class GLSLSourceAssembler
{
	/**
		Gets this platform default GLSL version
	**/
	public static function getDefaultVersion():String
	{
		// Specify the default glVersion.
		// We can use compile defines to guess the value that prevents crashes in the majority of cases.
		//return #if (android) "100" #elseif (web) "100" #elseif (mac) "120" #elseif (desktop) "150" #else "100" #end;
		#if web
		return "100";
		#elseif mac
		return "410";
		#else
		return "330 core";
		#end
	}

	/**
		Gets the GLSL Version from the source
	**/
	public static function getVersionFromSource(source:String, ?defaultVersion:Null<String>):Null<String>
	{
		var glVersionFinder:EReg = __getVersionFinder();
		if (!glVersionFinder.match(source)) return defaultVersion;

		var profile:String = glVersionFinder.matched(2);
		return profile == null ? glVersionFinder.matched(1) : glVersionFinder.matched(1) + " " + profile;
	}

	/**

	**/
	public var fragmentExtensions:Map<String, String>;

	/**

	**/
	public var fragmentPragmas:Map<String, String>;

	/**

	**/
	public var fragmentSource:String;

	/**

	**/
	public var version:String;

	/**

	**/
	public var vertexExtensions:Map<String, String>;

	/**

	**/
	public var vertexPragmas:Map<String, String>;

	/**

	**/
	public var vertexSource:String;

	/**
		Creates a new GLSLSourceAssembler instance
	**/
	public function new()
	{
		fragmentExtensions = new Map();
		fragmentPragmas = new Map();
		vertexExtensions = new Map();
		vertexPragmas = new Map();
	}

	/**
		Reset all values on this object
	**/
	public function clear():Void
	{
		fragmentPragmas = new Map();
		fragmentExtensions = new Map();
		fragmentSource = null;
		vertexPragmas = new Map();
		vertexExtensions = new Map();
		vertexSource = null;
		version = null;
	}

	/**
		Merge another GLSLSourceAssembler with `this`
		Modifies `this` GLSLSourceAssembler
	**/
	public function concat(other:GLSLSourceAssembler):GLSLSourceAssembler
	{
		addFragmentPragmas(other.fragmentPragmas);
		addFragmentExtensions(other.fragmentExtensions);
		if (other.fragmentSource != null) fragmentSource = other.fragmentSource;
		addVertexPragmas(other.vertexPragmas);
		addVertexExtensions(other.vertexExtensions);
		if (other.vertexSource != null) vertexSource = other.vertexSource;
		if (other.version != null) version = other.version;
		return this;
	}

	/**
		Add a GL extension for both vertex and fragment source
	**/
	public function addExtension(extension:String, behavior:String = "require"):Void
	{
		addVertexExtension(extension, behavior);
		addFragmentExtension(extension, behavior);
	}

	/**
		Adds GL extensions at once for both vertex and fragment source
	**/
	public function addExtensions(extensions:Map<String, String>):Void
	{
		addVertexExtensions(extensions);
		addFragmentExtensions(extensions);
	}

	/**
		Add a GL extension for the fragment source
	**/
	public function addFragmentExtension(extension:String, behavior:String = "require"):Void
	{
		fragmentExtensions.set(extension, behavior);
	}

	/**
		Adds GL extensions at once for the fragment source
	**/
	public function addFragmentExtensions(extensions:Map<String, String>):Void
	{
		for (key in extensions) fragmentExtensions[key] = extensions[key];
	}

	/**
		Add a GL extension for the vertex shader
	**/
	public function addVertexExtension(extension:String, behavior:String = "require"):Void
	{
		vertexExtensions.set(extension, behavior);
	}

	/**
		Adds GL extensions at once for the vertex source
	**/
	public function addVertexExtensions(extensions:Map<String, String>):Void
	{
		for (key in extensions) vertexExtensions[key] = extensions[key];
	}

	/**
		Append a pragma that will be used for assembling the fragment source
	**/
	public function addFragmentPragma(pragma:String, source:String):Void
	{
		fragmentPragmas.set(pragma, source);
	}

	/**
		Append a pragma that will be used for assembling the vertex source
	**/
	public function addVertexPragma(pragma:String, source:String):Void
	{
		vertexPragmas.set(pragma, source);
	}

	/**
		Append pragmas at once that will be used for assembling the fragment source
	**/
	public function addFragmentPragmas(pragmas:Map<String, String>):Void
	{
		for (pragma in pragmas) addFragmentPragma(pragma, pragmas[pragma]);
	}

	/**
		Append pragmas at once that will be used for assembling the fragment source
	**/
	public function addVertexPragmas(pragmas:Map<String, String>):Void
	{
		for (pragma in pragmas) addVertexPragma(pragma, pragmas[pragma]);
	}

	/**
		Append source to the pragma body of the GLSL fragment source
		A shortcut for `addFragmentPragma("body", source)`
	**/
	public inline function addFragmentBody(source:String):Void
	{
		addFragmentPragma("body", source);
	}

	/**
		Append source to the pragma header of the GLSL fragment source
		A shortcut for `addFragmentPragma("header", source)`
	**/
	public inline function addFragmentHeader(source:String):Void
	{
		addFragmentPragma("header", source);
	}

	/**
		Append source to the pragma body of the GLSL vertex source
		A shortcut for `addVertexPragma("body", source)`
	**/
	public inline function addVertexBody(source:String):Void
	{
		addVertexPragma("body", source);
	}

	/**
		Append source to the pragma header of the GLSL vertex source
		A shortcut for `addVertexPragma("header", source)`
	**/
	public inline function addVertexHeader(source:String):Void
	{
		addVertexPragma("header", source);
	}

	/**
		Build necessary extensions for a GLSL source
	**/
	public function buildExtensions(extensions:Map<String, String>, version:String, isVertex:Bool):Map<String, String>
	{
		var dataVersion = __getVersion(version);
		return __buildExtensions(extensions, dataVersion.versionNumber, dataVersion.versionProfile, isVertex);
	}

	/**
		Apply compatibility transforms to the specified GLSL shader sources to convert for the specified newer version.

		@param	source	The GLSL source to convert.
		@param	targetVersion	Optional; The target GLSL version.
		@param	isVertex	Whether the GLSL source is a component of a vertex shader. False if it is a fragment shader.
		@return	The converted GLSL source.
	**/
	public function applyCompatibility(source:String, ?targetVersion:String, isVertex:Bool):String
	{
		var dataVersion = __getVersion(targetVersion ?? getDefaultVersion());
		return __applyCompatibility(source, dataVersion.versionNumber, dataVersion.versionProfile, isVertex);
	}

	/**
		Assembles and finalize this GLSL fragment source code with optional compatibility.

		@param	useCompatibility	Whether to use a version conversion for finalizing.
		@return	The finalized GLSL fragment source code.
	**/
	public function assembleFragmentSource(useCompatibility:Bool = true):String
	{
		return assembleSource(fragmentSource, fragmentPragmas, fragmentExtensions, version, false, useCompatibility);
	}

	/**
		Assembles and finalize this GLSL vertex source code with optional compatibility.

		@param	useCompatibility	Whether to use a version conversion for finalizing.
		@return	The finalized GLSL vertex source code.
	**/
	public function assembleVertexSource(useCompatibility:Bool = true):String
	{
		return assembleSource(vertexSource, vertexPragmas, vertexExtensions, version, true, useCompatibility);
	}

	/**
		Assembles and finalize a GLSL source code with optional compatibility version conversion, extensions, and pragmas.

		@param	source	The GLSL source to be assembled.
		@param	pragmas	Optional; The pragmas to be used for finalizing the source that have requested pragmas.
		@param	extensions	Optional; The extensions to be used for finalizing.
		@param	version	Optional; The target GLSL version to be used for finalizing.
		@param	isVertex	Whether the GLSL source is a component of a vertex shader. False if it is a fragment shader.
		@param	useCompatibility	Whether to use a version conversion for finalizing.
		@return	The finalized GLSL source.
	**/
	public function assembleSource(source:String, ?pragmas:Map<String, String>, ?extensions:Map<String, String>,
		?version:String, isVertex:Bool, useCompatibility:Bool = true, precisionHint:ShaderPrecision = FULL):String
	{
		if (version == null) version = getDefaultVersion();

		if (source == null)
		{
			// There's nothing to assemble with, but just return it with a prefix instead anyway.
			var dataVersion = __getVersion(version);
			return __appendPrefix(null, dataVersion.versionNumber, dataVersion.versionProfile, extensions, isVertex, precisionHint);
		}

		if (pragmas != null)
		{
			source = __getPragmaFinder().map(source, (glPragmaFinder:EReg) ->
			{
				var pragma = glPragmaFinder.matched(1);
				return pragmas.exists(pragma) ? pragmas.get(pragma) + "\n" : '#pragma $pragma';
			});
		}

		var data = __getSource(source, version);
		extensions = __buildExtensions(__getExtensions(source, extensions == null ? new Map() : extensions.copy()),
			data.versionNumber, data.versionProfile, isVertex);

		if (useCompatibility)
		{
			data.source = __applyCompatibility(data.source, data.versionNumber, data.versionProfile, isVertex);
		}

		return __appendPrefix(data.source, data.versionNumber, data.versionProfile, extensions, isVertex, precisionHint);
	}

	private function __appendPrefix(source:String, versionNumber:Int, versionProfile:String, extensions:Map<String, String>, isVertex:Bool,
			precisionHint:Null<ShaderPrecision>):String
	{
		var output = new StringBuf();
		output.add('#version $versionNumber ${versionProfile}\n');

		if (extensions != null)
		{
			for (key in extensions.keys()) output.add('#extension $key : ${extensions[key]}\n');
		}

		if (precisionHint == FAST)
		{
			output.add("precision lowp float;\n");
		}
		else
		{
			output.add("#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\n#else\nprecision mediump float;\n#endif\n");
		}

		if (source != null)
		{
			if (versionNumber >= 300 && versionProfile != "compatibility" && !isVertex && !StringTools.contains(source, "out vec4"))
			{
				output.add("out vec4 openfl_FragColor;\n");
			}
			output.add(source);
		}

		return output.toString();
	}

	private function __applyCompatibility(source:String, versionNumber:Int, versionProfile:String, isVertex:Bool):String
	{
		// No processing needed on "compatibility" profile
		if (versionProfile == "compatibility") return source;

		// Recall: Attribute values are per-vertex, varying values are per-fragment
		// Thus, an `out` value in the vertex shader is an `in` value in the fragment shader
		var attributeKeyword:EReg = ~/\battribute\s+([A-Za-z0-9_]+)\s+([^\s]+)/gu;
		var varyingKeyword:EReg = ~/\bvarying\s+(?:lowp\s+|mediump\s+|highp\s+)?([A-Za-z0-9_]+)\s+([^\s]+)/gu;

		var texture2DKeyword:EReg = ~/texture2D/g;
		var glFragColorKeyword:EReg = ~/gl_FragColor/g;

		if (versionNumber >= 300)
		{
			if (isVertex)
			{
				source = attributeKeyword.replace(source, "in $1 $2");
				source = varyingKeyword.replace(source, "out $1 $2");
			}
			else
			{
				source = varyingKeyword.replace(source, "in $1 $2");
			}

			source = texture2DKeyword.replace(source, "texture");
			source = glFragColorKeyword.replace(source, "openfl_FragColor");

			return source;
		}
		else
		{
			return source;
		}
	}

	private function __buildExtensions(extensions:Map<String, String>, versionNumber:Int, versionProfile:String, isVertex:Bool):Map<String, String>
	{
		if (versionNumber >= 300 && versionNumber < 400)
		{
			// In 300, 310, 320, 330; it is required to include this extension.
			if (!extensions.exists("GL_ARB_separate_shader_objects") && !extensions.exists("GL_EXT_separate_shader_objects"))
			{
				#if linux
				extensions.set("GL_EXT_separate_shader_objects", "require");
				#else
				extensions.set("GL_ARB_separate_shader_objects", "require");
				#end
			}
		}

		// Enable complex blend modes if supported.
		@:privateAccess
		if (!isVertex && openfl.display.OpenGLRenderer.__complexBlendsSupported && versionNumber >= 150)
		{
			extensions.set("GL_KHR_blend_equation_advanced", "enable");

			// This is for getting complex blend modes to work with AMD Card quirks.
			// 'gl_SampleID' : required extension not requested: GL_ARB_sample_shading
			if (openfl.display.OpenGLRenderer.__complexBlendsSupported
				&& !extensions.exists("GL_ARB_sample_shading") && !extensions.exists("GL_OES_sample_shading"))
			{
				if (versionProfile == "es") extensions.set("GL_OES_sample_shading", "enable");
				else extensions.set("GL_ARB_sample_shading", "enable");
			}
		}

		return extensions;
	}

	private static function __getSource(source:String, defaultVersion:String):{source:String, versionNumber:Int, versionProfile:String}
	{
		var glVersionFinder:EReg = __getVersionFinder();
		if (glVersionFinder.match(source))
		{
			return {
				source: glVersionFinder.matchedLeft() + glVersionFinder.matchedRight(),
				versionNumber: Std.parseInt(glVersionFinder.matched(1)),
				versionProfile: glVersionFinder.matched(2)
			};
		}
		else
		{
			var glVersionSeperator:EReg = __getVersionSeperator();
			if (glVersionSeperator.match(defaultVersion))
			{
				return {
					source: source,
					versionNumber: Std.parseInt(glVersionSeperator.matched(1)),
					versionProfile: glVersionSeperator.matched(2)
				};
			}
			else
			{
				Log.error('Unable to find an unknown GLSL version "$defaultVersion"');
				return null;
			}
		}
	}

	private static function __getExtensions(source:String, extensions:Map<String, String>):Map<String, String>
	{
		if (extensions == null) extensions = new Map();

		var glExtensionFinder:EReg = __getExtensionFinder(), lastMatch = 0, position;
		while (glExtensionFinder.matchSub(source, lastMatch))
		{
			extensions.set(glExtensionFinder.matched(1), glExtensionFinder.matched(2));

			position = glExtensionFinder.matchedPos();
			lastMatch = position.pos + position.len;
		}

		return extensions;
	}

	private static function __getVersion(version:String):{versionNumber:Int, versionProfile:String}
	{
		var glVersionSeperator:EReg = __getVersionSeperator();
		if (glVersionSeperator.match(version))
		{
			return {
				versionNumber: Std.parseInt(glVersionSeperator.matched(1)),
				versionProfile: glVersionSeperator.matched(2)
			};
		}
		else
		{
			Log.error('Unable to find an unknown GLSL version "${version}"');
			return null;
		}
	}

	/*
	private static function __getVersionNumber(version:String):Int
	{
		var glVersionSeperator:EReg = __getVersionSeperator();
		if (glVersionSeperator.match(version)) return Std.parseInt(glVersionSeperator.matched(1));
		else
		{
			Log.error('Unable to get a GLSL version number from an unknown GLSL version "${version}"');
			return null;
		}
	}

	private static function __getVersionProfile(version:String):String
	{
		var glVersionSeperator:EReg = __getVersionSeperator();
		if (glVersionSeperator.match(version))
		{
			version = glVersionSeperator.matched(2);
			return version == null ? "" : version;
		}
		else
		{
			return "";
		}
	}
	*/

	private static inline function __getExtensionFinder():EReg
	{
		return ~/#extension\s+([A-Za-z0-9_]+)\s+:\s+(enable|require|warn|disable|all)\b/g;
	}

	private static inline function __getPragmaFinder():EReg
	{
		return ~/#pragma\s+(\w+)/g;
	}

	private static inline function __getVersionFinder():EReg
	{
		return ~/#version\s+(\d+)\s+(core|es|compatibility)?\b/;
	}

	private static inline function __getVersionSeperator():EReg
	{
		return ~/\b(\d+)\s+(core|es|compatibility)?\b/;
	}
}