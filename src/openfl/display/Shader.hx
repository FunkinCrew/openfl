package openfl.display;

import openfl.display3D.Context3DWrapMode;
import openfl.display3D.Context3DMipFilter;
import openfl.display3D.Context3DTextureFilter;
#if !flash
import openfl.display3D._internal.GLProgram;
import openfl.display3D._internal.GLShader;
import openfl.display._internal.ShaderBuffer;
import openfl.utils._internal.Float32Array;
import openfl.utils._internal.Log;
import openfl.display3D.Context3D;
import openfl.display3D.Program3D;
import openfl.utils.Assets;
import openfl.utils.ByteArray;
import openfl.utils.GLSLSourceAssembler;
import openfl.Lib;
#if lime
import lime.graphics.opengl.GL;
#end

/**
	// TODO: Document GLSL Shaders
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.Program3D)
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display.ShaderInput)
@:access(openfl.display.ShaderParameter)
@:access(openfl.display.Stage)
@:access(openfl.events.UncaughtErrorEvents)
#if !macro
@:autoBuild(openfl.utils._internal.ShaderMacro.build())
#end
class Shader
{
	public static function getParameterTypeFromGLEnum(type:Int, isArray:Bool):Null<ShaderParameterType>
	{
		return switch (type)
		{
			case GL.BOOL: isArray ? BOOLV : BOOL;
			case GL.FLOAT: isArray ? FLOATV : FLOAT;
			case GL.INT, GL.UNSIGNED_INT: isArray ? INTV : INT;
			case GL.BOOL_VEC2: isArray ? BOOL2V : BOOL2;
			case GL.BOOL_VEC3: isArray ? BOOL3V : BOOL3;
			case GL.BOOL_VEC4: isArray ? BOOL4V : BOOL4;
			case GL.INT_VEC2, GL.UNSIGNED_INT_VEC2: isArray ? INT2V : INT2;
			case GL.INT_VEC3, GL.UNSIGNED_INT_VEC3: isArray ? INT3V : INT3;
			case GL.INT_VEC4, GL.UNSIGNED_INT_VEC4: isArray ? INT4V : INT4;
			case GL.FLOAT_VEC2: isArray ? FLOAT2V : FLOAT2;
			case GL.FLOAT_VEC3: isArray ? FLOAT3V : FLOAT3;
			case GL.FLOAT_VEC4: isArray ? FLOAT4V : FLOAT4;
			case GL.FLOAT_MAT2: isArray ? MATRIX2X2V : MATRIX2X2;
			case GL.FLOAT_MAT2x3: isArray ? MATRIX2X3V : MATRIX2X3;
			case GL.FLOAT_MAT2x4: isArray ? MATRIX2X4V : MATRIX2X4;
			case GL.FLOAT_MAT3x2: isArray ? MATRIX3X2V : MATRIX3X2;
			case GL.FLOAT_MAT3: isArray ? MATRIX3X3V : MATRIX3X3;
			case GL.FLOAT_MAT3x4: isArray ? MATRIX3X4V : MATRIX3X4;
			case GL.FLOAT_MAT4x2: isArray ? MATRIX4X2V : MATRIX4X2;
			case GL.FLOAT_MAT4x3: isArray ? MATRIX4X3V : MATRIX4X3;
			case GL.FLOAT_MAT4: isArray ? MATRIX4X4V : MATRIX4X4;
			default: null;
		}
	}

	public static function getParameterTypeFromGLSL(string:String, isArray:Bool):Null<ShaderParameterType>
	{
		return switch (string)
		{
			case "bool": isArray ? BOOLV : BOOL;
			case "double", "float": isArray ? FLOATV : FLOAT;
			case "int", "uint": isArray ? INTV : INT;
			case "bvec2": isArray ? BOOL2V : BOOL2;
			case "bvec3": isArray ? BOOL3V : BOOL3;
			case "bvec4": isArray ? BOOL4V : BOOL4;
			case "ivec2", "uvec2": isArray ? INT2V : INT2;
			case "ivec3", "uvec3": isArray ? INT3V : INT3;
			case "ivec4", "uvec4": isArray ? INT4V : INT4;
			case "vec2", "dvec2": isArray ? FLOAT2V : FLOAT2;
			case "vec3", "dvec3": isArray ? FLOAT3V : FLOAT3;
			case "vec4", "dvec4": isArray ? FLOAT4V : FLOAT4;
			case "mat2", "mat2x2": isArray ? MATRIX2X2V : MATRIX2X2;
			case "mat2x3": isArray ? MATRIX2X3V : MATRIX2X3;
			case "mat2x4": isArray ? MATRIX2X4V : MATRIX2X4;
			case "mat3x2": isArray ? MATRIX3X2V : MATRIX3X2;
			case "mat3", "mat3x3": isArray ? MATRIX3X3V : MATRIX3X3;
			case "mat3x4": isArray ? MATRIX3X4V : MATRIX3X4;
			case "mat4x2": isArray ? MATRIX4X2V : MATRIX4X2;
			case "mat4x3": isArray ? MATRIX4X3V : MATRIX4X3;
			case "mat4", "mat4x4": isArray ? MATRIX4X4V : MATRIX4X4;
			default: null;
		}
	}

	public static function processGLSLParameter(source:String, storageType:String, callback:ShaderProcessParameterCallback):String
	{
		var isVertex = storageType != "uniform", regex:EReg = switch (storageType)
		{
			case "uniform": ~/uniform\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?\s*(?:=)?\s*(.+?(?=;))?/gu;
			case "in": ~/in\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?/gu;
			case "attribute": ~/attribute\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?/gu;
			default: throw "Unknown storageType for Shader.processGLSLParameter " + storageType;
		}

		var arrayLength:Null<Int>, p;
		return regex.map(source, (_) ->
		{
			if (regex.matched(3) == null) arrayLength = 0;
			else if ((arrayLength = Std.parseInt(regex.matched(3))) == null) arrayLength = 1;

			callback(isVertex, regex.matched(1), regex.matched(2), arrayLength, isVertex ? null : regex.matched(4));

			if (isVertex)
			{
				p = regex.matchedPos();
				return source.substr(p.pos, p.len);
			}
			else
			{
				return 'uniform ${regex.matched(1)} ${regex.matched(2)}${arrayLength == 0 ? "" : "[" + regex.matched(3) + "]"}';
			}
		});
	}

	/**
		The raw Pixel Bender shader bytecode for this Shader
		instance.

		This property is used only on the Flash target.
	**/
	public var byteCode(null, default):ByteArray;

	/**
		Provides access to parameters, input images, and metadata for the
		Shader instance. ShaderParameter objects representing parameters for
		the shader, ShaderInput objects representing the input images for the
		shader, and other values representing the shader's metadata are
		dynamically added as properties of the `data` property object when the
		Shader instance is created. Those properties can be used to introspect
		the shader and to set parameter and input values.
		For information about accessing and manipulating the dynamic
		properties of the `data` object, see the ShaderData class description.
	**/
	public var data(get, set):ShaderData;

	/**
		Get or set the GLSL version used in the header when compiling with GLSL.
		When set to null, it will sets to the default GLSL version from either
		the source or GLSLSourceAssembler.getDefaultVersion when it gets
		compiled later.

		@default The default value is determined at compile time, or whatever assembly this shader is using.
	**/
	public var glVersion(get, set):Null<String>;

	/**
		The raw of this GLSL Version used before being applied to compile with GLSL.
	**/
	public var glVersionRaw(get, never):Null<String>;

	/**
		Provides additional `#extension` directives to insert in the vertex shaders.

		Example:
		```
		@:glVertexExtensions("OES_standard_derivatives", "require")
		// or @:glExtensions("OES_standard_derivatives", "require")
		```
	**/
	public var glVertexExtensions(get, set):Map<String, String>;

	/**
		Provides additional `#extension` directives to insert in the fragment shaders.

		Example:
		```
		@:glFragmentExtensions("OES_standard_derivatives", "require")
		// or @:glExtensions("OES_standard_derivatives", "require")
		```
	**/
	public var glFragmentExtensions(get, set):Map<String, String>;

	/**
		Provides an additional pragmas to use in (child class of) vertex shaders.

		Example:
		```
		@:glVertexHeader(...)
		@:glVertexBody(...)
		```
	**/
	public var glVertexPragmas(get, set):Map<String, String>;

	/**
		Provides an additional pragmas to use in (child class of) fragment shaders.

		Example:
		```
		@:glFragmentHeader(...)
		@:glFragmentBody(...)
		```
	**/
	public var glFragmentPragmas(get, set):Map<String, String>;

	/**
		The default GLSL vertex header, before being applied to the vertex source.
	**/
	public var glFragmentHeaderRaw(get, never):String;

	/**
		The default GLSL vertex body, before being applied to the vertex source.
	**/
	public var glFragmentBodyRaw(get, never):String;

	/**
		The default GLSL fragment source, before `#pragma` values are replaced.
	**/
	public var glFragmentSourceRaw(get, never):String;

	/**
		Get or set the fragment source used when targeting OpenGL.

		This property is not available on the Flash target.
	**/
	public var glFragmentSource(get, set):String;

	/**
		The compiled GLProgram if available.

		This property is not available on the Flash target.
	**/
	@SuppressWarnings("checkstyle:Dynamic") public var glProgram(default, null):GLProgram;
	/**
		The default GLSL vertex header, before being applied to the vertex source.
	**/
	public var glVertexHeaderRaw(get, never):String;

	/**
		The default GLSL vertex body, before being applied to the vertex source.
	**/
	public var glVertexBodyRaw(get, never):String;

	/**
		The default GLSL vertex source, before `#pragma` values are replaced.
	**/
	public var glVertexSourceRaw(get, never):String;

	/**
		Get or set the vertex source used when targeting OpenGL.

		This property is not available on the Flash target.
	**/
	public var glVertexSource(get, set):String;

	/**
		The precision of math operations performed by the shader.
		The set of possible values for the `precisionHint` property is defined
		by the constants in the ShaderPrecision class.

		The default value is `ShaderPrecision.FULL`. Setting the precision to
		`ShaderPrecision.FAST` can speed up math operations at the expense of
		precision.

		Full precision mode (`ShaderPrecision.FULL`) computes all math
		operations to the full width of the IEEE 32-bit floating standard and
		provides consistent behavior on all platforms. In this mode, some math
		operations such as trigonometric and exponential functions can be
		slow.

		Fast precision mode (`ShaderPrecision.FAST`) is designed for maximum
		performance but does not work consistently on different platforms and
		individual CPU configurations. In many cases, this level of precision
		is sufficient to create graphic effects without visible artifacts.

		The precision mode selection affects the following shader operations.
		These operations are faster on an Intel processor with the SSE
		instruction set:

		* `sin(x)`
		* `cos(x)`
		* `tan(x)`
		* `asin(x)`
		* `acos(x)`
		* `atan(x)`
		* `atan(x, y)`
		* `exp(x)`
		* `exp2(x)`
		* `log(x)`
		* `log2(x)`
		* `pow(x, y)`
		* `reciprocal(x)`
		* `sqrt(x)`
	**/
	public var precisionHint(get, set):ShaderPrecision;

	/**
		The compiled Program3D if available.

		This property is not available on the Flash target.
	**/
	public var program:Program3D;

	@:noCompletion private var __alpha:ShaderParameter<Float>;
	@:noCompletion private var __bitmap:ShaderInput<BitmapData>;
	@:noCompletion private var __cacheProgramId:String;
	@:noCompletion private var __colorMultiplier:ShaderParameter<Float>;
	@:noCompletion private var __colorOffset:ShaderParameter<Float>;
	@:noCompletion private var __context:Context3D;
	@:noCompletion private var __data:ShaderData;
	@:noCompletion private var __fieldList:Array<String>;
	@:noCompletion private var __glVertexExtensions:Map<String, String>;
	@:noCompletion private var __glFragmentExtensions:Map<String, String>;
	@:noCompletion private var __glVertexPragmas:Map<String, String>;
	@:noCompletion private var __glFragmentPragmas:Map<String, String>;
	@:noCompletion private var __glVersionRaw:Null<String>;
	@:noCompletion private var __glVersion:String;
	@:noCompletion private var __glFragmentSourceRaw:String;
	@:noCompletion private var __glFragmentSource:String;
	@:noCompletion private var __glSourceAssembler:GLSLSourceAssembler;
	@:noCompletion private var __glSourceDirty:Bool;
	@:noCompletion private var __glVertexSourceRaw:String;
	@:noCompletion private var __glVertexSource:String;
	@:noCompletion private var __hasColorTransform:ShaderParameter<Bool>;
	@:noCompletion private var __inputBitmapData:Array<ShaderInput<BitmapData>>;
	@:noCompletion private var __isGenerated:Bool;
	@:noCompletion private var __matrix:ShaderParameter<Float>;
	@:noCompletion private var __numPasses:Int;
	@:noCompletion private var __paramBool:Array<ShaderParameter<Bool>>;
	@:noCompletion private var __paramFloat:Array<ShaderParameter<Float>>;
	@:noCompletion private var __paramInt:Array<ShaderParameter<Int>>;
	@:noCompletion private var __position:ShaderParameter<Float>;
	@:noCompletion private var __precisionHint:ShaderPrecision;
	@:noCompletion private var __textureCoord:ShaderParameter<Float>;
	@:noCompletion private var __texture:ShaderInput<BitmapData>;
	@:noCompletion private var __textureSize:ShaderParameter<Float>;

	#if openfljs
	@:noCompletion private static function __init__()
	{
		untyped Object.defineProperties(Shader.prototype, {
			"data": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_data (); }"),
				set: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function (v) { return this.set_data (v); }")
			},
			"glVersion": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glVersion (); }"),
				set: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function (v) { return this.set_glVersion (v); }")
			},
			"glVersionRaw": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glVersionRaw (); }")
			},
			"glVertexExtensions": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glVertexExtensions (); }"),
				set: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function (v) { return this.set_glVertexExtensions (v); }")
			},
			"glFragmentExtensions": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glFragmentExtensions (); }"),
				set: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function (v) { return this.set_glFragmentExtensions (v); }")
			},
			"glVertexPragmas": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glVertexPragmas (); }"),
				set: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function (v) { return this.set_glVertexPragmas (v); }")
			},
			"glFragmentPragmas": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glFragmentPragmas (); }"),
				set: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function (v) { return this.set_glFragmentPragmas (v); }")
			},
			"glFragmentHeaderRaw": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glFragmentHeaderRaw (); }"),
			},
			"glFragmentBodyRaw": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glFragmentBodyRaw (); }"),
			},
			"glFragmentSourceRaw": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glFragmentSourceRaw (); }"),
			},
			"glFragmentSource": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glFragmentSource (); }"),
				set: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function (v) { return this.set_glFragmentSource (v); }")
			},
			"glVertexHeaderRaw": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glVertexHeaderRaw (); }"),
			},
			"glVertexBodyRaw": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glVertexBodyRaw (); }"),
			},
			"glVertexSourceRaw": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glVertexSourceRaw (); }"),
			},
			"glVertexSource": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_glVertexSource (); }"),
				set: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function (v) { return this.set_glVertexSource (v); }")
			},
			"precisionHint": {
				get: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function () { return this.get_precisionHint (); }"),
				set: untyped #if haxe4 js.Syntax.code #else __js__ #end ("function (v) { return this.set_precisionHint (v); }")
			},
		});
	}
	#end

	/**
		Creates a new Shader instance.

		@param code The raw shader bytecode to link to the Shader.
	**/
	public function new(code:ByteArray = null)
	{
		byteCode = code;

		// this variable is set in macro instead to avoid the runtime shader stuff accidentally bypassing it
		//__cacheProgramId = Type.getClassName(Type.getClass(this));
		__glSourceDirty = true;
		__numPasses = 1;
		__precisionHint = FULL;

		__createAssembler();
		//__data = new ShaderData(code);
	}

	@:noCompletion private function __createAssembler():Void
	{
		if (__glSourceAssembler == null)
		{
			__glSourceAssembler = new GLSLSourceAssembler();
		}
	}

	@:noCompletion private function __clearUseArray():Void
	{
		for (parameter in __paramBool)
		{
			parameter.__useArray = false;
		}

		for (parameter in __paramFloat)
		{
			parameter.__useArray = false;
		}

		for (parameter in __paramInt)
		{
			parameter.__useArray = false;
		}
	}

	@:noCompletion private function __disable():Void
	{
		if (program != null)
		{
			__disableGL();
		}
	}

	@:noCompletion private function __disableGL():Void
	{
		var gl = __context.gl;

		var textureCount = 0;

		for (input in __inputBitmapData)
		{
			input.__disableGL(__context, textureCount);
			textureCount++;
		}

		for (parameter in __paramBool)
		{
			parameter.__disableGL(__context);
		}

		for (parameter in __paramFloat)
		{
			parameter.__disableGL(__context);
		}

		for (parameter in __paramInt)
		{
			parameter.__disableGL(__context);
		}

		__context.__bindGLArrayBuffer(null);

		#if lime
		if (__context.__context.type == OPENGL)
		{
			gl.disable(gl.TEXTURE_2D);
		}
		#end
	}

	@:noCompletion private function __enable():Void
	{
		__init();

		if (program != null)
		{
			__enableGL();
		}
	}

	@:noCompletion private function __enableGL():Void
	{
		var textureCount = 0;

		var gl = __context.gl;

		for (input in __inputBitmapData)
		{
			gl.uniform1i(input.index, textureCount);

			textureCount++;
			//if (textureCount == gl.MAX_TEXTURE_IMAGE_UNITS) break;
		}

		#if lime
		if (__context.__context.type == OPENGL && textureCount > 0)
		{
			gl.enable(gl.TEXTURE_2D);
		}
		#end
	}

	@:noCompletion private function __resetParams():Void
	{
		#if haxe4
		if (__inputBitmapData == null) __inputBitmapData = new Array(); else __inputBitmapData.resize(0);
		if (__paramBool == null) __paramBool = new Array(); else __paramBool.resize(0);
		if (__paramFloat == null) __paramFloat = new Array(); else __paramFloat.resize(0);
		if (__paramInt == null) __paramInt = new Array(); else __paramInt.resize(0);
		#else
		__inputBitmapData = new Array();
		__paramBool = new Array();
		__paramFloat = new Array();
		__paramInt = new Array();
		#end
	}

	@:noCompletion private function __init():Void
	{
		if (__data == null)
		{
			__data = cast new ShaderData(null);
		}

		if (__glFragmentSourceRaw != null && __glVertexSourceRaw != null && (program == null || __glSourceDirty))
		{
			__initGL();
		}
	}

	@:noCompletion private function __initGL():Void
	{
		var id = __cacheProgramId != null ? __cacheProgramId + (__precisionHint == FAST ? "FAST" : "") : null;

		if (__glSourceDirty)
		{
			program = null;
			glProgram = null;

			__resetParams();

			if (id != null)
			{
				if (__context != null)
				{
					program = __context.__programs.get(id);
				}
				else if (Lib.current.stage != null)
				{
					__context = Lib.current.stage.context3D;
					if (__context != null)
					{
						program = __context.__programs.get(id);
					}
				}
			}

			if (program != null)
			{
				glProgram = program.__glProgram;
				__glVertexSource = program.__glVertexSource;
				__glFragmentSource = program.__glFragmentSource;
				__glVersion = program.__glFragmentVersion != null ? program.__glFragmentVersion : program.__glVertexVersion;

				__buildParamData();
			}
			else
			{
				__refreshGLSource();

				if (id == null)
				{
					__cacheProgramId = __glVertexSource + __glFragmentSource;
					id = __cacheProgramId + (__precisionHint == FAST ? "FAST" : "");
				}

				if (__context != null)
				{
					program = __context.__programs.get(id);
					if (program != null) glProgram = program.__glProgram;
					else __initProgram(id);

					__buildParamData();
				}
				else
				{
					processGLSLParameter(__glVertexSource, "attribute", __processGLSLParameterCallback);
					processGLSLParameter(__glVertexSource, "in", __processGLSLParameterCallback);
					processGLSLParameter(__glVertexSource, "uniform", __processGLSLParameterCallback);
					processGLSLParameter(__glFragmentSource, "uniform", __processGLSLParameterCallback);
				}
			}

			__glSourceDirty = false;
		}
		else if (__context != null && program == null)
		{
			if (id != null)
			{
				program = __context.__programs.get(id);
				if (program != null) glProgram = program.__glProgram;
				else __initProgram(id);
			}
			else
			{
				__initProgram(null);
			}
			__buildParamData();
		}
	}

	@:noCompletion private function __initProgram(id:String):Void
	{
		program = __context.createProgram(GLSL);

		if (openfl.Lib.current.stage.__uncaughtErrorEvents.__enabled)
		{
			try
			{
				program.uploadSources(__glVertexSource, __glFragmentSource);
				if (id != null) __context.__programs.set(id, program);
			}
			catch (e:Dynamic)
			{
				openfl.Lib.current.stage.__handleError(e);
			}
		}
		else
		{
			program.uploadSources(__glVertexSource, __glFragmentSource);
			if (id != null) __context.__programs.set(id, program);
		}

		glProgram = program.__glProgram;
	}

	@:noCompletion private function __refreshGLSource():Void
	{
		__glVertexSource = __glSourceAssembler.assembleSource(__glVertexSourceRaw, __glVertexPragmas,
			__glVertexExtensions, __glVersionRaw, true, true, __precisionHint);

		__glFragmentSource = __glSourceAssembler.assembleSource(__glFragmentSourceRaw, __glFragmentPragmas,
			__glFragmentExtensions, __glVersionRaw, false, true, __precisionHint);

		__glVersion = GLSLSourceAssembler.getVersionFromSource(__glFragmentSource,
			GLSLSourceAssembler.getVersionFromSource(__glVertexSource, GLSLSourceAssembler.getDefaultVersion()));
	}

	@:noCompletion private function __processGLSLParameterCallback(isVertex:Bool, typeName:String, name:String, arrayLength:Int,
			defaultAssign:Null<String>):Void
	{
		if (StringTools.startsWith(name, "gl_"))
		{
			return;
		}

		var type = getParameterTypeFromGLSL(typeName, arrayLength != 0), isSampler = StringTools.startsWith(typeName, "sampler");
		__registerParameter(name, type, arrayLength == 0 ? 1 : arrayLength, null, !isVertex, isSampler,
			__getParameterDefault(defaultAssign, type, isSampler));
	}

	@:noCompletion private function __getParameterDefault(assign:Null<String>, type:ShaderParameterType, isSampler:Bool):Dynamic
	{
		// isSampler may not be logically possible.
		if (assign == null || isSampler) return null;

		assign = StringTools.trim(assign);

		if (assign.charCodeAt(0) == '['.code && assign.charCodeAt(assign.length - 1) == ']'.code)
		{
			final array = [];

			var index = 1, endIndex:Int, value;
			while (index != 0)
			{
				value = __parseParameterValue(StringTools.trim(assign.substr(index, endIndex = assign.indexOf(',', index))), type);
				if (value is Array) for (v in cast(value, Array<Dynamic>)) array.push(v);
				else array.push(value);
				index = endIndex + 1;
			}

			return array;
		}
		else
		{
			var value = __parseParameterValue(assign, type);
			if (value is Array) return value;
			else return [value];
		}
	}

	@:noCompletion private function __parseParameterValue(assign:Null<String>, type:ShaderParameterType):Dynamic
	{
		// Poorly implemented but this is okay for now.
		var typeMatch = ~/([A-Za-z0-9_]+)\s*\((\w+)\)/;
		if (typeMatch.match(assign))
		{
			var func = typeMatch.matched(1), value = typeMatch.matched(2);
			switch (func)
			{
				case 'sin': return Math.sin(Std.parseFloat(value));
				case 'cos': return Math.cos(Std.parseFloat(value));
				case 'tan': return Math.tan(Std.parseFloat(value));
				case 'asin': return Math.asin(Std.parseFloat(value));
				case 'acos': return Math.acos(Std.parseFloat(value));
				default:
					var matchedType = getParameterTypeFromGLSL(func, false);
					if (matchedType == null/* || matchedType != type*/) return null;
					else return [for (v in value.split(',')) __parseValue(StringTools.trim(v), type)];
			}
		}
		else
		{
			return __parseValue(assign, type);
		}
	}

	@:noCompletion private function __parseValue(value:Null<String>, type:ShaderParameterType):Dynamic
	{
		switch (type)
		{
			case BOOL, BOOL2, BOOL3, BOOL4, BOOLV, BOOL2V, BOOL3V, BOOL4V: return value == "true";
			case FLOAT, FLOAT2, FLOAT3, FLOAT4, FLOATV, FLOAT2V, FLOAT3V, FLOAT4V: return Std.parseFloat(value);
			case INT, INT2, INT3, INT4, INTV, INT2V, INT3V, INT4V: return Std.parseInt(value);
			default: return null;
		}
	}

	@:noCompletion private function __buildParamData():Void
	{
		var name:String;
		for (i in 0...program.__glslAttribNames.length)
		{
			name = program.__glslAttribNames[i];
			if (StringTools.startsWith(name, "gl_"))
			{
				continue;
			}

			__registerParameter(name, program.__glslAttribTypes[i], program.__glslAttribSizes[i], program.__glslAttribLocations[i], false, false, null);
		}

		for (i in 0...program.__glslSamplerNames.length)
		{
			__registerParameter(program.__glslSamplerNames[i], null, 1, program.__glslSamplerLocations[i],
				true, true, __getParameterDefault(program.__glslUniformDefaults[i], null, true));
		}

		for (i in 0...program.__glslUniformNames.length)
		{
			name = program.__glslUniformNames[i];
			if (StringTools.startsWith(name, "gl_"))
			{
				continue;
			}

			__registerParameter(name, program.__glslUniformTypes[i], program.__glslUniformSizes[i], program.__glslUniformLocations[i],
				true, false, __getParameterDefault(program.__glslUniformDefaults[i], program.__glslUniformTypes[i], false));
		}
	}

	@:noCompletion private function __registerParameter(name:String, type:ShaderParameterType, size:Int, location:Dynamic/*GLUniformLocation*/,
			isUniform:Bool, isSampler:Bool, defaultValue:Dynamic)
	{
		var arrayLength = switch (type)
		{
			case MATRIX2X2, MATRIX2X3, MATRIX2X4: 2;
			case MATRIX3X3, MATRIX3X2, MATRIX3X4: 3;
			case MATRIX4X4, MATRIX4X2, MATRIX4X3: 4;
			default: size;
		}

		var length = switch (type)
		{
			case BOOL2, BOOL2V, INT2, INT2V, FLOAT2, FLOAT2V, MATRIX2X2: 2;
			case BOOL3, BOOL3V, INT3, INT3V, FLOAT3, FLOAT3V, MATRIX3X3: 3;
			case BOOL4, BOOL4V, INT4, INT4V, FLOAT4, FLOAT4V, MATRIX4X4, MATRIX2X2V: 4;

			case MATRIX2X3, MATRIX4X3: 3;
			case MATRIX2X4, MATRIX3X4: 4;
			case MATRIX3X2, MATRIX4X2: 2;

			case MATRIX3X3V: 9;
			case MATRIX4X4V: 16;
			case MATRIX2X3V, MATRIX3X2V: 6;
			case MATRIX2X4V, MATRIX4X2V: 8;
			case MATRIX3X4V, MATRIX4X3V: 12;
			default: 1;
		}
		length *= arrayLength;

		if (location == null) location = -1;

		inline function register(x:Any)
		{
			Reflect.setField(__data, name, x);
			if (__isGenerated && __thisHasField(name))
			{
				try
				{
					Reflect.setField(this, name, x);
					//Reflect.setProperty(this, name, x);
				}
				catch (e)
				{
					Log.debug('Failed to set field $name: $e');
				}
			}
		}

		if (Reflect.hasField(__data, name) && Reflect.field(__data, name) != null)
		{
			var dyn = Reflect.field(__data, name);
			if (isSampler)
			{
				var input:ShaderInput<BitmapData> = cast dyn;
				if (input != null)
				{
					if (input.input == null) input.input = cast defaultValue;
					if ((input.index = location) == -1) __inputBitmapData.remove(input);
					else if (!__inputBitmapData.contains(input)) __inputBitmapData.push(input);
					return;// register(input);
				}
			}
			else
			{
				switch (type)
				{
					case BOOL, BOOL2, BOOL3, BOOL4, BOOLV, BOOL2V, BOOL3V, BOOL4V:
						var parameter:ShaderParameter<Bool> = cast dyn;
						if (parameter != null)
						{
							if (parameter.value == null) parameter.value = cast defaultValue;
							parameter.__arrayLength = arrayLength;
							parameter.__isUniform = isUniform;
							parameter.__length = length;

							if ((parameter.index = location) == -1) __paramBool.remove(parameter);
							else if (!__paramBool.contains(parameter)) __paramBool.push(parameter);
							return;// register(parameter);
						}
					case INT, INT2, INT3, INT4, INTV, INT2V, INT3V, INT4V:
						var parameter:ShaderParameter<Int> = cast dyn;
						if (parameter != null)
						{
							if (parameter.value == null) parameter.value = cast defaultValue;
							parameter.__arrayLength = arrayLength;
							parameter.__isUniform = isUniform;
							parameter.__length = length;

							if ((parameter.index = location) == -1) __paramInt.remove(parameter);
							else if (!__paramInt.contains(parameter)) __paramInt.push(parameter);
							return;// register(parameter);
						}
					default:
						var parameter:ShaderParameter<Float> = cast dyn;
						if (parameter != null)
						{
							if (parameter.value == null) parameter.value = cast defaultValue;
							parameter.__arrayLength = arrayLength;
							parameter.__isUniform = isUniform;
							parameter.__length = length;

							if ((parameter.index = location) == -1) __paramFloat.remove(parameter);
							else if (!__paramFloat.contains(parameter)) __paramFloat.push(parameter);
							return;// register(parameter);
						}
				}
			}
		}

		if (isSampler)
		{
			var input = new ShaderInput<BitmapData>();
			input.input = cast defaultValue;
			input.name = name;
			input.__isUniform = true;

			switch (name) {
				case "openfl_Texture": __texture = input;
				case "bitmap": __bitmap = input;
				default:
			}

			if ((input.index = location) == -1) __inputBitmapData.remove(input);
			else if (!__inputBitmapData.contains(input)) __inputBitmapData.push(input);
			register(input);
		}
		else
		{
			switch (type)
			{
				case BOOL, BOOL2, BOOL3, BOOL4, BOOLV, BOOL2V, BOOL3V, BOOL4V:
					var parameter = new ShaderParameter<Bool>();
					parameter.name = name;
					parameter.type = type;
					parameter.value = cast defaultValue;
					parameter.__arrayLength = arrayLength;
					parameter.__isBool = true;
					parameter.__isUniform = isUniform;
					parameter.__length = length;

					if (name == "openfl_HasColorTransform")
					{
						__hasColorTransform = parameter;
					}

					if ((parameter.index = location) == -1) __paramBool.remove(parameter);
					else if (!__paramBool.contains(parameter)) __paramBool.push(parameter);
					register(parameter);

				case INT, INT2, INT3, INT4, INTV, INT2V, INT3V, INT4V:
					var parameter = new ShaderParameter<Int>();
					parameter.name = name;
					parameter.type = type;
					parameter.value = cast defaultValue;
					parameter.__arrayLength = arrayLength;
					parameter.__isInt = true;
					parameter.__isUniform = isUniform;
					parameter.__length = length;

					if ((parameter.index = location) == -1) __paramInt.remove(parameter);
					else if (!__paramInt.contains(parameter)) __paramInt.push(parameter);
					register(parameter);

				default:
					var parameter = new ShaderParameter<Float>();
					parameter.name = name;
					parameter.type = type;
					parameter.value = cast defaultValue;
					parameter.__arrayLength = arrayLength;
					#if lime
					if (arrayLength > 0) parameter.__uniformMatrix = new Float32Array(length);
					#end
					parameter.__isFloat = true;
					parameter.__isUniform = isUniform;
					parameter.__length = length;
						
					switch (name)
					{
						case "openfl_Alpha": __alpha = parameter;
						case "openfl_ColorMultiplier": __colorMultiplier = parameter;
						case "openfl_ColorOffset": __colorOffset = parameter;
						case "openfl_Matrix": __matrix = parameter;
						case "openfl_Position": __position = parameter;
						case "openfl_TextureCoord": __textureCoord = parameter;
						case "openfl_TextureSize": __textureSize = parameter;
						default:
					}

					if ((parameter.index = location) == -1) __paramFloat.remove(parameter);
					else if (!__paramFloat.contains(parameter)) __paramFloat.push(parameter);
					register(parameter);
			}
		}
	}

	@:noCompletion private function __thisHasField(name:String)
	{
		// Reflect.hasField(this, name) is REALLY expensive so we cache the result.
		if (__fieldList == null)
		{
			__fieldList = Reflect.fields(this).concat(Type.getInstanceFields(Type.getClass(this)));
		}
		return __fieldList.indexOf(name) != -1;
	}

	@:noCompletion private function __update():Void
	{
		if (program != null)
		{
			__updateGL();
		}
	}

	@:noCompletion private function __updateFromBuffer(shaderBuffer:ShaderBuffer, bufferOffset:Int):Void
	{
		if (program != null)
		{
			__updateGLFromBuffer(shaderBuffer, bufferOffset);
		}
	}

	@:noCompletion private function __updateGL():Void
	{
		var textureCount = 0;

		var gl = __context.gl;

		for (input in __inputBitmapData)
		{
			input.__updateGL(__context, textureCount);
			textureCount++;

			//if (textureCount == gl.MAX_TEXTURE_IMAGE_UNITS) break;
		}

		for (parameter in __paramBool)
		{
			parameter.__updateGL(__context);
		}

		for (parameter in __paramFloat)
		{
			parameter.__updateGL(__context);
		}

		for (parameter in __paramInt)
		{
			parameter.__updateGL(__context);
		}
	}

	@:noCompletion private function __updateGLFromBuffer(shaderBuffer:ShaderBuffer, bufferOffset:Int):Void {
		var textureCount = 0;
		var input:ShaderInput<BitmapData>;
		var inputData:BitmapData;
		var inputFilter:Context3DTextureFilter;
		var inputMipFilter:Context3DMipFilter;
		var inputWrap:Context3DWrapMode;

		// not this
		for (i in 0...shaderBuffer.inputCount) {
			input = shaderBuffer.inputRefs[i];
			inputData = shaderBuffer.inputs[i];
			inputFilter = shaderBuffer.inputFilter[i];
			inputMipFilter = shaderBuffer.inputMipFilter[i];
			inputWrap = shaderBuffer.inputWrap[i];

			if (inputData != null) {
				input.__updateGL(__context, textureCount, inputData, inputFilter, inputMipFilter, inputWrap);
				textureCount++;
			}
		}

		var gl = __context.gl;

		if (shaderBuffer.paramDataLength > 0) {
			if (shaderBuffer.paramDataBuffer == null) {
				shaderBuffer.paramDataBuffer = gl.createBuffer();
			}

			// Log.verbose ("bind param data buffer (length: " + shaderBuffer.paramData.length + ") (" + shaderBuffer.paramCount + ")");

			__context.__bindGLArrayBuffer(shaderBuffer.paramDataBuffer);
			gl.bufferData(gl.ARRAY_BUFFER, shaderBuffer.paramData, gl.DYNAMIC_DRAW);
		} else {
			// Log.verbose ("bind buffer null");

			__context.__bindGLArrayBuffer(null);
		}

		var boolIndex = 0;
		var floatIndex = 0;
		var intIndex = 0;

		var boolCount = shaderBuffer.paramBoolCount;
		var floatCount = shaderBuffer.paramFloatCount;
		var paramData = shaderBuffer.paramData;

		var boolRef:ShaderParameter<Bool>;
		var floatRef:ShaderParameter<Float>;
		var intRef:ShaderParameter<Int>;
		var hasOverride:Bool;
		var overrideBoolValue:Array<Bool> = null;
		var overrideFloatValue:Array<Float> = null;
		var overrideIntValue:Array<Int> = null;

		for (i in 0...shaderBuffer.paramCount) {
			hasOverride = false;

			if (i < boolCount) {
				boolRef = shaderBuffer.paramRefs_Bool[boolIndex];

				for (j in 0...shaderBuffer.overrideBoolCount) {
					if (boolRef.name == shaderBuffer.overrideBoolNames[j]) {
						overrideBoolValue = shaderBuffer.overrideBoolValues[j];
						hasOverride = true;
						break;
					}
				}

				if (hasOverride)
				{
					boolRef.__updateGL(__context, overrideBoolValue);
				}
				else
				{
					boolRef.__updateGLFromBuffer(__context, paramData, shaderBuffer.paramPositions[i], shaderBuffer.paramLengths[i], bufferOffset);
				}

				boolIndex++;
			} else if (i < boolCount + floatCount) {
				floatRef = shaderBuffer.paramRefs_Float[floatIndex];

				for (j in 0...shaderBuffer.overrideFloatCount) {
					if (floatRef.name == shaderBuffer.overrideFloatNames[j]) {
						overrideFloatValue = shaderBuffer.overrideFloatValues[j];
						hasOverride = true;
						break;
					}
				}

				if (hasOverride)
				{
					floatRef.__updateGL(__context, overrideFloatValue);
				}
				else
				{
					floatRef.__updateGLFromBuffer(__context, paramData, shaderBuffer.paramPositions[i], shaderBuffer.paramLengths[i], bufferOffset);
				}

				floatIndex++;
			} else {
				intRef = shaderBuffer.paramRefs_Int[intIndex];

				for (j in 0...shaderBuffer.overrideIntCount) {
					if (intRef.name == shaderBuffer.overrideIntNames[j]) {
						overrideIntValue = cast shaderBuffer.overrideIntValues[j];
						hasOverride = true;
						break;
					}
				}

				if (hasOverride)
				{
					intRef.__updateGL(__context, overrideIntValue);
				}
				else
				{
					intRef.__updateGLFromBuffer(__context, paramData, shaderBuffer.paramPositions[i], shaderBuffer.paramLengths[i], bufferOffset);
				}

				intIndex++;
			}
		}
	}

	@:noCompletion private function __setDirty():Void
	{
		//if (!__glSourceDirty)
		//{
		__cacheProgramId = null;
		__glSourceDirty = true;
		//}
	}

	// Get & Set Methods
	@:noCompletion private function get_data():ShaderData
	{
		if (__glSourceDirty || __data == null)
		{
			__init();
		}

		return __data;
	}

	@:noCompletion private function set_data(value:ShaderData):ShaderData
	{
		return __data = value;
	}

	@:noCompletion private function get_glVersionRaw():Null<String>
	{
		return __glVersionRaw;
	}

	@:noCompletion private function get_glVersion():Null<String>
	{
		if (__glSourceDirty)
		{
			__init();
		}

		return __glVersion;
	}

	@:noCompletion private function set_glVersion(value:Null<String>):Null<String>
	{
		if (__glSourceDirty ? value != __glVersionRaw : value != __glVersion)
		{
			__setDirty();
		}

		return __glVersionRaw = value;
	}

	@:noCompletion private function get_glVertexExtensions():Map<String, String>
	{
		return __glVertexExtensions;
	}

	@:noCompletion private function get_glFragmentExtensions():Map<String, String>
	{
		return __glFragmentExtensions;
	}

	@:noCompletion private function set_glVertexExtensions(value:Map<String, String>):Map<String, String>
	{
		__setDirty();
		return __glVertexExtensions = value;
	}

	@:noCompletion private function set_glFragmentExtensions(value:Map<String, String>):Map<String, String>
	{
		__setDirty();
		return __glFragmentExtensions = value;
	}

	@:noCompletion private function get_glVertexPragmas():Map<String, String>
	{
		return __glVertexPragmas;
	}

	@:noCompletion private function get_glFragmentPragmas():Map<String, String>
	{
		return __glFragmentPragmas;
	}

	@:noCompletion private function set_glVertexPragmas(value:Map<String, String>):Map<String, String>
	{
		__setDirty();
		return __glVertexPragmas = value;
	}

	@:noCompletion private function set_glFragmentPragmas(value:Map<String, String>):Map<String, String>
	{
		__setDirty();
		return __glFragmentPragmas = value;
	}

	@:noCompletion private function get_glFragmentHeaderRaw():String
	{
		return __glFragmentPragmas.get("header");
	}

	@:noCompletion private function get_glFragmentBodyRaw():String
	{
		return __glFragmentPragmas.get("body");
	}

	@:noCompletion private function get_glFragmentSourceRaw():String
	{
		return __glFragmentSourceRaw;
	}

	@:noCompletion private function get_glFragmentSource():String
	{
		if (__glSourceDirty)
		{
			__init();
		}

		return __glFragmentSource;
	}

	@:noCompletion private function set_glFragmentSource(value:String):String
	{
		__setDirty();
		return __glFragmentSourceRaw = value;
	}

	@:noCompletion private function get_glVertexHeaderRaw():String
	{
		return __glVertexPragmas.get("header");
	}

	@:noCompletion private function get_glVertexBodyRaw():String
	{
		return __glVertexPragmas.get("body");
	}

	@:noCompletion private function get_glVertexSourceRaw():String
	{
		return __glVertexSourceRaw;
	}

	@:noCompletion private function get_glVertexSource():String
	{
		if (__glSourceDirty)
		{
			__init();
		}

		return __glVertexSource;
	}

	@:noCompletion private function set_glVertexSource(value:String):String
	{
		__setDirty();
		return __glVertexSourceRaw = value;
	}

	@:noCompletion private function get_precisionHint():ShaderPrecision
	{
		return __precisionHint;
	}

	@:noCompletion private function set_precisionHint(value:ShaderPrecision):ShaderPrecision
	{
		if (__precisionHint != value && program != null && !__glSourceDirty)
		{
			var id = __cacheProgramId != null ? __cacheProgramId + (value == FAST ? "FAST" : "") : null;

			if (id != null && __context != null && __context.__programs.exists(id))
			{
				program = __context.__programs.get(id);
				__glVertexSource = program.__glVertexSource;
				__glFragmentSource = program.__glFragmentSource;
			}
			else
			{
				program = null;
				__refreshGLSource();
			}
		}
		return __precisionHint = value;
	}
}

//typedef ShaderProcessParameterCallback = (isVertex:Bool, typeName:String, name:String, arrayLength:Int, defaultAssign:Null<String>) -> Void;
typedef ShaderProcessParameterCallback = Bool->String->String->Int->Null<String>->Void;
#else
typedef Shader = flash.display.Shader;
#end
