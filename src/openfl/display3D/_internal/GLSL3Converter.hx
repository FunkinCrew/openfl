package openfl.display3D._internal;

import openfl.display3D._internal.GLSLTokenizer;

using StringTools;

/**
 * Utility class to convert legacy GLSL shaders (GLSL ES 1.00 and GLSL 1.20) into GLSL 3.XX code
 *
 * Partially based off of https://github.com/Experience-Monks/glsl-100-to-300
 */
@:noDebug
@:nullSafety
class GLSL3Converter
{
	// 300es builtins/reserved words that were previously valid in v100
	// New reserved words
	static final TEXTURE_FUNCTIONS:Map<String, String> = [
		"texture2D" => "texture",
		"texture2DProj" => "textureProj",
		"texture2DLod" => "textureLod",
		"texture2DProjLod" => "textureProjLod",
		"textureCube" => "texture",
		"textureCubeLod" => "textureLod",
		"texture2DLodEXT" => "textureLod",
		"texture2DProjLodEXT" => "textureProjLod",
		"texture2DGradEXT" => "textureGrad",
		"texture2DProjGradEXT" => "textureProjGrad",
		"textureCubeLodEXT" => "textureLod",
		"textureCubeGradEXT" => "textureGrad"
	];

	// New builtin functions
	static final RESERVED_NAMES:Map<String, Bool> = [
		for (name in [
			"centroid",
			"smooth",
			"layout",
			"uint",
			"uvec2",
			"uvec3",
			"uvec4",
			"common",
			"partition",
			"active",
			"filter",
			"resource",
			"patch",
			"sample",
			"subroutine",
			"buffer",
			"shared",
			"coherent",
			"restrict",
			"readonly",
			"writeonly",
			"precise",
			"round",
			"roundEven",
			"trunc",
			"isnan",
			"isinf",
			"sinh",
			"cosh",
			"tanh",
			"asinh",
			"acosh",
			"atanh",
			"transpose",
			"determinant",
			"inverse",
			"outerProduct",
			"floatBitsToInt",
			"floatBitsToUint",
			"intBitsToFloat",
			"uintBitsToFloat",
			"packSnorm2x16",
			"unpackSnorm2x16",
			"packUnorm2x16",
			"unpackUnorm2x16",
			"packHalf2x16",
			"unpackHalf2x16",
			"textureSize",
			"texelFetch",
			"texture",
			"textureProj",
			"textureLod",
			"textureProjLod",
			"textureOffset",
			"textureProjOffset",
			"textureLodOffset",
			"textureProjLodOffset",
			"textureGrad",
			"textureGradOffset",
			"textureProjGrad",
			"textureProjGradOffset"
		])
			name => true
	];

	// Built-ins of GLSL 1.20
	static final DESKTOP_BUILTINS:Array<String> = ["transpose", "outerProduct"];

	// GLSL 3.XX does not allow macros/defines with the `GL_` prefix
	// This functions as a remap for some of them
	static final MACRO_REMAPS:Map<String, String> = ["GL_OES_standard_derivatives" => "OPENFL_STANDARD_DERIVATIVES"];

	/**
	 * The version to conevert the shaders into.
	 */
	public static final VERSION:String = #if desktop "330" #else "300 es" #end;

	var desktopSource:Bool = false;
	var remappedMacros:Map<String, Bool> = new Map<String, Bool>();
	var fragColorUsed:Bool = false;
	var fragDataCount:Int = 0;

	public function new() {}

	/**
	 * @param source The legacy source.
	 * @param isVertex Whether the source is a vertex shader, a fragment otherwise.
	 * @return The legacy source converted into version 3.XX.
	 */
	public function convertShaderSource(source:String, isVertex:Bool):String
	{
		desktopSource = false;
		remappedMacros.clear();
		fragColorUsed = false;
		fragDataCount = 0;

		source = normalize(source);

		if (!isLegacy(source)) return source;

		source = renameReservedNames(source);
		source = rewriteMethodsCalls(source);
		source = remapDeclarations(source, isVertex);
		source = remapOutputs(source, isVertex);
		source = remapDirectives(source, isVertex);

		source = collapseBlankLines(source);
		source = insertOutputs(source, isVertex);

		return buildHeader() + source;
	}

	function normalize(source:String):String
	{
		return source.split("\r\n").join("\n");
	}

	function collapseBlankLines(source:String):String
	{
		return ~/\n{3,}/g.replace(source, "\n\n").ltrim();
	}

	function isLegacy(source:String):Bool
	{
		final version:EReg = ~/^\s*#\s*version\s+(\d+)/;

		for (token in tokenize(source))
		{
			if (token.type != PREPROCESSOR_DIRECTIVE || !version.match(token.data)) continue;

			final number:Null<Int> = Std.parseInt(version.matched(1));

			desktopSource = number != 100;

			return number == 100 || number == 110 || number == 120;
		}

		return true;
	}

	function renameReservedNames(source:String):String
	{
		final interfaceNames:Map<String, Bool> = collectInterfaceNames(source);
		final edits:Array<SourceEdit> = [];

		for (token in tokenize(source))
		{
			if (token.type != IDENTIFIER && token.type != FIELD_SELECTION) continue;
			if (!RESERVED_NAMES.exists(token.data) || interfaceNames.exists(token.data)) continue;
			if (desktopSource && DESKTOP_BUILTINS.indexOf(token.data) != -1) continue;

			edits.push(createEdit(token, token.data + "_"));
		}

		return applyEdits(source, edits);
	}

	function collectInterfaceNames(source:String):Map<String, Bool>
	{
		final names:Map<String, Bool> = new Map<String, Bool>();
		final tokens:Array<Token> = tokenize(source);

		var depth:Int = 0;
		var i:Int = 0;

		while (i < tokens.length)
		{
			switch (tokens[i].type)
			{
				case LEFT_BRACE:
					depth++;
				case RIGHT_BRACE:
					depth--;
				case UNIFORM, ATTRIBUTE:
					if (depth == 0)
					{
						var j:Int = i + 1;

						while (j < tokens.length && tokens[j].type != SEMICOLON && tokens[j].type != LEFT_BRACE)
						{
							if (tokens[j].type == IDENTIFIER && j + 1 < tokens.length)
							{
								switch (tokens[j + 1].type)
								{
									case SEMICOLON, COMMA, LEFT_BRACKET, EQUAL: names.set(tokens[j].data, true);
									default:
								}
							}

							j++;
						}

						i = j;
					}
				default:
			}

			i++;
		}

		return names;
	}

	function rewriteMethodsCalls(source:String):String
	{
		final tokens:Array<Token> = tokenize(source);
		final edits:Array<SourceEdit> = [];

		for (i in 0...tokens.length - 1)
		{
			if (tokens[i].type != IDENTIFIER || tokens[i + 1].type != LEFT_PAREN) continue;

			final name:Null<String> = TEXTURE_FUNCTIONS[tokens[i].data];
			if (name == null) continue;

			edits.push(createEdit(tokens[i], name));
		}

		return applyEdits(source, edits);
	}

	function remapDeclarations(source:String, isVertex:Bool):String
	{
		final edits:Array<SourceEdit> = [];

		for (token in tokenize(source))
		{
			final text:Null<String> = switch (token.type)
			{
				case ATTRIBUTE: "in";
				case VARYING: isVertex ? "out" : "in";
				default: null;
			}

			if (text == null) continue;

			edits.push(createEdit(token, text));
		}

		return applyEdits(source, edits);
	}

	// switch into layout attachement system on 3.XX
	function remapOutputs(source:String, isVertex:Bool):String
	{
		if (isVertex) return source;

		final tokens:Array<Token> = tokenize(source);
		final edits:Array<SourceEdit> = [];

		for (i in 0...tokens.length)
		{
			if (tokens[i].type != IDENTIFIER) continue;

			final text:Null<String> = switch (tokens[i].data)
			{
				case "gl_FragColor":
					fragColorUsed = true;
					"openfl_FragColor";
				case "gl_FragData":
					countFragData(tokens, i);
					"openfl_FragData";
				case "gl_FragDepthEXT":
					"gl_FragDepth";
				default:
					null;
			}

			if (text == null) continue;

			edits.push(createEdit(tokens[i], text));
		}

		return applyEdits(source, edits);
	}

	// to track how many attachments the shader has
	function countFragData(tokens:Array<Token>, index:Int):Void
	{
		final constant:Bool = index + 3 < tokens.length
			&& tokens[index + 1].type == LEFT_BRACKET
			&& tokens[index + 2].type == INTCONSTANT
			&& tokens[index + 3].type == RIGHT_BRACKET;

		final value:Null<Int> = constant ? Std.parseInt(tokens[index + 2].data) : null;

		if (value == null) fragDataCount = -1;
		else if (fragDataCount != -1 && value >= fragDataCount) fragDataCount = value + 1;
	}

	function remapDirectives(source:String, isVertex:Bool):String
	{
		final edits:Array<SourceEdit> = [];

		for (token in tokenize(source))
		{
			if (token.type != PREPROCESSOR_DIRECTIVE) continue;

			final text:String = remapDirective(token.data, isVertex);
			if (text != token.data) edits.push(createEdit(token, text));
		}

		return applyEdits(source, edits);
	}

	function remapDirective(directive:String, isVertex:Bool):String
	{
		if (~/^\s*#\s*(version|extension)\b/.match(directive)) return "";

		var result:String = directive;

		for (name => replacement in MACRO_REMAPS)
		{
			final pattern:EReg = new EReg('\\b$name\\b', "g");

			if (!pattern.match(result)) continue;

			remappedMacros.set(replacement, true);
			result = pattern.replace(result, replacement);
		}

		if (!~/^\s*#\s*define\b/.match(result)) return result;

		return ~/\b(texture(?:2D|Cube)(?:ProjLod|ProjGrad|Proj|Lod|Grad)?(?:EXT)?|gl_FragColor|gl_FragData|gl_FragDepthEXT)\b/g.map(result,
			function(match:EReg):String
			{
				final name:String = match.matched(1);
				final texture:Null<String> = TEXTURE_FUNCTIONS[name];

				if (texture != null) return texture;
				if (name == "gl_FragDepthEXT") return isVertex ? name : "gl_FragDepth";
				if (isVertex) return name;

				if (name == "gl_FragColor")
				{
					fragColorUsed = true;
					return "openfl_FragColor";
				}

				fragDataCount = -1;
				return "openfl_FragData";
			});
	}

	function buildHeader():String
	{
		var header:String = '#version $VERSION\n';

		for (name in remappedMacros.keys())
		{
			header += '#define $name 1\n';
		}

		return header;
	}

	function insertOutputs(source:String, isVertex:Bool):String
	{
		if (isVertex) return source;

		var outputs:String = "";

		if (fragColorUsed) outputs += 'layout(location = 0) out vec4 openfl_FragColor;\n';

		if (fragDataCount != 0)
		{
			final size:String = fragDataCount == -1 ? "gl_MaxDrawBuffers" : Std.string(fragDataCount);

			outputs += 'layout(location = 0) out vec4 openfl_FragData[$size];\n';
		}

		if (outputs == "") return source;

		final tokens:Array<Token> = tokenize(source);

		var position:Int = source.length;
		var i:Int = 0;

		while (i < tokens.length)
		{
			switch (tokens[i].type)
			{
				case PREPROCESSOR_DIRECTIVE:
					i++;
					continue;
				case PRECISION:
					while (i < tokens.length && tokens[i].type != SEMICOLON)
						i++;
					i++;
					continue;
				default:
			}

			position = tokenStart(tokens[i]);
			break;
		}

		return source.substr(0, position) + outputs + source.substr(position);
	}

	function tokenize(source:String):Array<Token>
	{
		final tokens:Array<Token> = [];

		for (token in GLSLTokenizer.tokenize(source))
		{
			switch (token.type)
			{
				case WHITESPACE, LINE_COMMENT, BLOCK_COMMENT:
				default:
					tokens.push(token);
			}
		}

		return tokens;
	}

	inline function tokenStart(token:Token):Int
	{
		return token.position == null ? 0 : (token.position : Int);
	}

	inline function tokenEnd(token:Token):Int
	{
		return tokenStart(token) + token.data.length;
	}

	inline function createEdit(token:Token, text:String):SourceEdit
	{
		return {start: tokenStart(token), end: tokenEnd(token), text: text};
	}

	function applyEdits(source:String, edits:Array<SourceEdit>):String
	{
		if (edits.length == 0) return source;

		edits.sort((a, b) -> a.start - b.start);

		final results:StringBuf = new StringBuf();
		var position:Int = 0;

		for (edit in edits)
		{
			if (edit.start < position) continue;

			results.addSub(source, position, edit.start - position);
			results.add(edit.text);
			position = edit.end;
		}

		results.addSub(source, position, source.length - position);

		return results.toString();
	}
}

typedef SourceEdit =
{
	var start:Int;
	var end:Int;
	var text:String;
}
