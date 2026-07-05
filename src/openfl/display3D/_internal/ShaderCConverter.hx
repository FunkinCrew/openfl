package openfl.display3D._internal;

import openfl.display3D._internal.GLSLTokenizer;

using StringTools;

/**
 * Utility class to convert GLSL shaders into BGFX ShaderC shaders.
 */
@:noDebug
@:nullSafety
class ShaderCConverter
{
	static final ATTRIBUTE_SEMANTICS:Map<String, String> = [
		"openfl_Position" => "POSITION",
		"openfl_TextureCoord" => "TEXCOORD0",
		"openfl_ColorMultiplier" => "COLOR0",
		"openfl_ColorOffset" => "COLOR1",
		"openfl_Alpha" => "COLOR2"
	];

	static final ATTRIBUTE_FIELD:Map<String, String> = [
		"openfl_Alpha" => "x",
		"openfl_ColorMultiplier" => "y",
		"openfl_ColorOffset" => "z"
	];

	static final VARYING_TYPES:Array<String> = ["float", "vec2", "vec3", "vec4"];
	static final PASSTHROUGH_UNIFORMS:Array<String> = ["vec4", "mat3", "mat4"];

	static final VECTOR_SIZES:Map<String, Int> = ["vec2" => 2, "vec3" => 3, "vec4" => 4];
	static final UVECTOR_SIZES:Map<String, Int> = ["uvec2" => 2, "uvec3" => 3, "uvec4" => 4];
	static final MATRIX_SIZES:Map<String, Int> = ["mat2" => 2, "mat3" => 3, "mat4" => 4];

	public var mappedUniforms:Map<String, String>;
	public var samplersIDs:Map<String, Int>;

	var roles:Map<String, DeclarationRole>;
	var types:Map<String, String>;
	var dynamicSemantics:Map<String, String>;
	var nextTexcoordSlot:Int;

	var inputs:Array<String> = [];
	var outputs:Array<String> = [];
	var fragmentVaryings:Array<{name:String, type:String}> = [];
	var constructorHelpers:Map<String, Bool> = new Map<String, Bool>();
	var samplerCount:Int = 0;
	var sharedUseArrayEmitted:Bool = false;
	var usedConstMacro:Bool = false;
	var usedGlobalMacro:Bool = false;
	var uniformRemaps:Array<String> = [];

	public function new()
	{
		mappedUniforms = new Map<String, String>();
		samplersIDs = new Map<String, Int>();
		roles = new Map<String, DeclarationRole>();
		types = new Map<String, String>();
		dynamicSemantics = new Map<String, String>();
		nextTexcoordSlot = 1;
	}

	public function generateVaryingDef(vertexSource:String, fragmentSource:String):String
	{
		collectDeclarations(vertexSource, true);
		collectDeclarations(fragmentSource, false);

		var results:String = '';

		final varyingNames:Array<String> = filterNames(Varying);
		final attributeNames:Array<String> = [for (name in roles.keys()) if (roles[name] != Varying) name];
		attributeNames.sort(Reflect.compare);

		var slot:Int = 0;
		for (name in varyingNames)
		{
			final type:Null<String> = types[name];
			if (type == null) continue;

			results += '$type $name : TEXCOORD$slot = ${defaultValue(type)};\n';
			slot++;
		}

		if (varyingNames.length > 0 && attributeNames.length > 0) results += '\n';

		for (name in attributeNames)
		{
			final semantic:Null<String> = getAttribSemantic(name);
			final type:Null<String> = types[name];
			if (semantic == null || type == null) continue;

			results += '$type ${getAttribBGFXName(name)} : $semantic;\n';
		}

		return results;
	}

	public function convertShaderSource(source:String, isVertex:Bool):String
	{
		inputs = [];
		outputs = [];
		fragmentVaryings = [];
		constructorHelpers = new Map<String, Bool>();
		samplerCount = 0;
		sharedUseArrayEmitted = false;
		usedConstMacro = false;
		usedGlobalMacro = false;
		uniformRemaps = [];

		source = normalize(source);
		source = rewriteMethodsCalls(source);
		source = remapDeclarations(source, isVertex);
		source = checkMacroRedefinitions(source);
		source = fixConstInitializers(source);
		source = applyGlobalConsts(source);

		if (!isVertex)
		{
			source = promoteFragmentVaryings(source);
			source = promoteFragmentCoord(source);
		}

		final header:String = buildHeader(source);
		source = collapseBlankLines(source);

		return header + source;
	}

	public function getAttribIndex(name:String):Int
	{
		final semantic:Null<String> = getAttribSemantic(name);
		if (semantic == null) return -1;

		if (semantic.startsWith("TEXCOORD"))
		{
			final slot:Null<Int> = Std.parseInt(semantic.substr(8));
			return slot == null ? -1 : 10 + (slot : Int);
		}

		return switch (semantic)
		{
			case "POSITION": 0;
			case "COLOR0": 4;
			case "COLOR1": 5;
			case "COLOR2": 6;
			default: -1;
		}
	}

	public function dispose():Void
	{
		mappedUniforms.clear();
		samplersIDs.clear();
		roles.clear();
		types.clear();
		dynamicSemantics.clear();

		inputs = [];
		outputs = [];
		fragmentVaryings = [];
		constructorHelpers.clear();
		uniformRemaps = [];
	}

	function collectDeclarations(source:String, isVertex:Bool):Void
	{
		for (declaration in findDeclarations(source))
		{
			if (!VARYING_TYPES.contains(declaration.type)) continue;

			for (name in declaration.names)
			{
				types.set(name, declaration.type);

				if (isVertex && declaration.qualifier == ATTRIBUTE) roles.set(name, classifyAttribute(name));
				else if (declaration.qualifier != UNIFORM) roles.set(name, Varying);
			}
		}
	}

	function classifyAttribute(name:String):DeclarationRole
	{
		if (ATTRIBUTE_FIELD.exists(name)) return DualAttribute;

		if (ATTRIBUTE_SEMANTICS.exists(name)) return Attribute;

		if (!dynamicSemantics.exists(name)) dynamicSemantics.set(name, 'TEXCOORD${nextTexcoordSlot++}');

		return DynamicAttribute;
	}

	function findDeclarations(source:String):Array<Declaration>
	{
		final tokens:Array<Token> = tokenize(source);
		final declarations:Array<Declaration> = [];

		var depth:Int = 0;
		var i:Int = 0;

		while (i < tokens.length)
		{
			final token:Token = tokens[i];

			switch (token.type)
			{
				case LEFT_BRACE:
					depth++;
				case RIGHT_BRACE:
					depth--;
				default:
			}

			if (depth > 0 || !isQualifier(token.type))
			{
				i++;
				continue;
			}

			final end:Int = findStatementEnd(tokens, i);
			if (end == -1 || end < i + 3)
			{
				i++;
				continue;
			}

			final names:Array<String> = [];
			for (j in i + 2...end)
			{
				if (tokens[j].type == IDENTIFIER && (j == i + 2 || tokens[j - 1].type == COMMA)) names.push(tokens[j].data);
			}

			if (names.length == 0)
			{
				i++;
				continue;
			}

			declarations.push({
				qualifier: token.type,
				type: tokens[i + 1].data,
				names: names,
				start: tokenStart(token),
				end: tokenEnd(tokens[end])
			});

			i = end + 1;
		}

		return declarations;
	}

	inline function isQualifier(type:TokenType):Bool
	{
		return switch (type)
		{
			case ATTRIBUTE, VARYING, UNIFORM, IN, OUT: true;
			default: false;
		}
	}

	function findStatementEnd(tokens:Array<Token>, start:Int):Int
	{
		for (i in start...tokens.length)
		{
			switch (tokens[i].type)
			{
				case SEMICOLON:
					return i;
				case LEFT_BRACE, LEFT_PAREN:
					return -1;
				default:
			}
		}

		return -1;
	}

	function remapDeclarations(source:String, isVertex:Bool):String
	{
		final edits:Array<SourceEdit> = [];

		for (declaration in findDeclarations(source))
		{
			final text:String = switch (declaration.qualifier)
			{
				case UNIFORM: remapUniforms(declaration);
				case ATTRIBUTE: isVertex ? remapAttributes(declaration) : '';
				default: remapVaryings(declaration, isVertex);
			}

			edits.push({start: declaration.start, end: declaration.end, text: text});
		}

		return applyEdits(source, edits);
	}

	function remapUniforms(declaration:Declaration):String
	{
		for (name in declaration.names)
			uniformRemaps.push(remapUniform(name, declaration.type));

		return '';
	}

	function remapUniform(name:String, type:String):String
	{
		if (PASSTHROUGH_UNIFORMS.contains(type)) return 'uniform $type $name;';

		if (type == "sampler2D")
		{
			samplersIDs.set(name, samplerCount);
			return 'SAMPLER2D($name, ${samplerCount++});';
		}

		final internal:String = '${name}_internal';
		final unpacked:String = unpackUniform(internal, type);

		if (unpacked == null) return 'uniform $type $name;';

		mappedUniforms.set(name, type);

		return 'uniform vec4 $internal;\n#define $name $unpacked';
	}

	function unpackUniform(internal:String, type:String):String
	{
		return switch (type)
		{
			case "bool": '($internal.x != 0.0)';
			case "bvec2": 'bvec2($internal.x != 0.0, $internal.y != 0.0)';
			case "bvec3": 'bvec3($internal.x != 0.0, $internal.y != 0.0, $internal.z != 0.0)';
			case "bvec4": 'bvec4($internal.x != 0.0, $internal.y != 0.0, $internal.z != 0.0, $internal.w != 0.0)';
			case "float": '$internal.x';
			case "vec2": '$internal.xy';
			case "vec3": '$internal.xyz';
			case "int": 'int($internal.x)';
			case "ivec2": 'ivec2(int($internal.x), int($internal.y))';
			case "ivec3": 'ivec3(int($internal.x), int($internal.y), int($internal.z))';
			case "ivec4": 'ivec4(int($internal.x), int($internal.y), int($internal.z), int($internal.w))';
			case "mat2": 'mat2($internal.x, $internal.y, $internal.z, $internal.w)';
			default: null;
		}
	}

	function remapAttributes(declaration:Declaration):String
	{
		var results:String = '';

		for (name in declaration.names)
			results += remapAttribute(name, declaration.type);

		return results;
	}

	function remapAttribute(name:String, type:String):String
	{
		final role:Null<DeclarationRole> = roles[name];

		if (role == null) return 'uniform $type $name;';

		final bgfxName:Null<String> = getAttribBGFXName(name);
		if (bgfxName == null) return 'uniform $type $name;';

		inputs.push(bgfxName);

		if (role == Attribute) return '#define $name $bgfxName';

		var results:String = '';
		var selector:String;

		if (role == DualAttribute)
		{
			if (!sharedUseArrayEmitted)
			{
				results += 'uniform vec4 openfl_UseArray;\n';
				sharedUseArrayEmitted = true;
			}

			selector = 'openfl_UseArray.${ATTRIBUTE_FIELD[name]}';
		}
		else
		{
			results += 'uniform vec4 ${name}_useArray;\n';
			selector = '${name}_useArray.x';
		}

		final fallback:String = type == "float" ? '${name}_internal.x' : '${name}_internal';

		results += 'uniform vec4 ${name}_internal;\n';
		results += '#define $name ($selector != 0.0 ? $bgfxName : $fallback)';

		return results;
	}

	function remapVaryings(declaration:Declaration, isVertex:Bool):String
	{
		for (name in declaration.names)
		{
			if (roles[name] != Varying) continue;

			if (isVertex) outputs.push(name);
			else
			{
				inputs.push(name);
				fragmentVaryings.push({name: name, type: declaration.type});
			}
		}

		return '';
	}

	function rewriteMethodsCalls(source:String):String
	{
		final tokens:Array<Token> = tokenize(source);
		final edits:Array<SourceEdit> = [];

		var i:Int = 0;

		while (i < tokens.length)
		{
			if (i + 1 >= tokens.length || !isCallable(tokens[i]) || tokens[i + 1].type != LEFT_PAREN)
			{
				i++;
				continue;
			}

			final close:Int = findClosing(tokens, i + 1);
			if (close == -1)
			{
				i++;
				continue;
			}

			final name:Null<String> = rewriteCall(tokens[i].data, countArguments(tokens, i + 1, close));

			if (name != null)
			{
				final text:String = name;
				edits.push({start: tokenStart(tokens[i]), end: tokenEnd(tokens[i]), text: text});
			}

			i++;
		}

		return applyEdits(source, edits);
	}

	function rewriteCall(name:String, arguments:Int):Null<String>
	{
		if (name == "atan") return arguments == 2 ? "atan2" : null;

		if (MATRIX_SIZES.exists(name))
		{
			final size:Int = MATRIX_SIZES[name] ?? 0;

			if (arguments != 1 && arguments != size && arguments != size * size) return null;

			constructorHelpers.set(name, true);
			return 'openfl_$name';
		}

		if (arguments != 1) return null;

		if (UVECTOR_SIZES.exists(name)) return '${name}_splat';

		if (VECTOR_SIZES.exists(name))
		{
			constructorHelpers.set(name, true);
			return 'openfl_$name';
		}

		return null;
	}

	function countArguments(tokens:Array<Token>, open:Int, close:Int):Int
	{
		if (close <= open + 1) return 0;

		var count:Int = 1;
		var depth:Int = 0;

		for (i in open + 1...close)
		{
			switch (tokens[i].type)
			{
				case LEFT_PAREN, LEFT_BRACKET, LEFT_BRACE:
					depth++;
				case RIGHT_PAREN, RIGHT_BRACKET, RIGHT_BRACE:
					depth--;
				case COMMA if (depth == 0):
					count++;
				default:
			}
		}

		return count;
	}

	function constructorHelperDefs():String
	{
		var results:String = '';

		for (name in constructorHelpers.keys())
		{
			if (VECTOR_SIZES.exists(name)) results += vectorConstructorHelper(name);
			else
				results += matrixConstructorHelper(name);
		}

		return results;
	}

	function vectorConstructorHelper(name:String):String
	{
		final size:Int = VECTOR_SIZES[name] ?? 0;
		final swizzle:String = ".xyzw".substr(0, size + 1);

		var results:String = '$name openfl_$name(float v) { return ${name}_splat(v); }
' + '$name openfl_$name(int v) { return ${name}_splat(float(v)); }
';

		for (source in size...5)
			results += '$name openfl_$name(vec$source v) { return ${source == size ? "v" : 'v$swizzle'}; }\n';

		return results;
	}

	function matrixConstructorHelper(name:String):String
	{
		final size:Int = MATRIX_SIZES[name] ?? 0;
		final vector:String = 'vec$size';
		final diagonal:Array<String> = [];

		for (row in 0...size)
		{
			for (column in 0...size)
				diagonal.push(row == column ? "v" : "0.0");
		}

		var results:String = '$name openfl_$name(float v) { return $name(${diagonal.join(", ")}); }\n'
			+ '$name openfl_$name(int v) { return openfl_$name(float(v)); }\n'
			+ '$name openfl_$name($name v) { return v; }\n';

		final columns:Array<String> = [for (i in 0...size) 'c$i'];
		final columnArgs:Array<String> = [for (c in columns) '$vector $c'];

		results += '$name openfl_$name(${columnArgs.join(", ")}) { return mtxFromCols(${columns.join(", ")}); }\n';

		final scalarArgs:Array<String> = [];
		final scalarColumns:Array<String> = [];

		for (column in 0...size)
		{
			final parts:Array<String> = [];

			for (row in 0...size)
			{
				final arg:String = 'm$column$row';
				scalarArgs.push('float $arg');
				parts.push(arg);
			}

			scalarColumns.push('$vector(${parts.join(", ")})');
		}

		results += '$name openfl_$name(${scalarArgs.join(", ")}) { return mtxFromCols(${scalarColumns.join(", ")}); }\n';

		return results;
	}

	function normalize(source:String):String
	{
		source = source.split("\r\n").join("\n");
		source = ~/void\s+main\s*\(\s*void\s*\)/g.replace(source, "void main()");

		return source;
	}

	function collapseBlankLines(source:String):String
	{
		while (~/\n[ \t]*\n/.match(source))
			source = ~/\n[ \t]*\n/g.replace(source, "\n");

		return source;
	}

	function checkMacroRedefinitions(source:String):String
	{
		final edits:Array<SourceEdit> = [];

		for (token in tokenize(source))
		{
			if (token.type != PREPROCESSOR_DIRECTIVE) continue;

			final name:Null<String> = definedMacroName(token.data);
			if (name == null) continue;

			final start:Int = tokenStart(token);
			edits.push({start: start, end: start, text: '#undef $name\n'});
		}

		return applyEdits(source, edits);
	}

	function definedMacroName(directive:String):Null<String>
	{
		final define:EReg = ~/^\s*#\s*define\s+([A-Za-z_][A-Za-z0-9_]*)/;

		return define.match(directive) ? define.matched(1) : null;
	}

	function fixConstInitializers(source:String):String
	{
		final tokens:Array<Token> = tokenize(source);
		final edits:Array<SourceEdit> = [];

		var depth:Int = 0;

		for (i in 0...tokens.length)
		{
			final token:Token = tokens[i];

			switch (token.type)
			{
				case LEFT_BRACE:
					depth++;
				case RIGHT_BRACE:
					depth--;

				case CONST if (depth > 0):
					if (checkConstInitializer(tokens, i)) edits.push({start: tokenStart(token), end: tokenEnd(token), text: ""});

				default:
			}
		}

		return applyEdits(source, edits);
	}

	function checkConstInitializer(tokens:Array<Token>, start:Int):Bool
	{
		for (i in start + 1...tokens.length)
		{
			final token:Token = tokens[i];

			if (token.type == SEMICOLON || token.type == RIGHT_BRACE) return false;

			if (token.type != IDENTIFIER || !token.data.startsWith("openfl_")) continue;
			if (i + 1 < tokens.length && tokens[i + 1].type == LEFT_PAREN) return true;
		}

		return false;
	}

	function applyGlobalConsts(source:String):String
	{
		final tokens:Array<Token> = tokenize(source);
		final edits:Array<SourceEdit> = [];

		var depth:Int = 0;
		var parens:Int = 0;

		for (token in tokens)
		{
			switch (token.type)
			{
				case LEFT_BRACE:
					depth++;
				case RIGHT_BRACE:
					depth--;
				case LEFT_PAREN:
					parens++;
				case RIGHT_PAREN:
					parens--;

				case CONST if (depth == 0 && parens == 0):
					usedConstMacro = true;
					edits.push({start: tokenStart(token), end: tokenEnd(token), text: "OPENFL_CONST"});

				default:
			}
		}

		return applyEdits(source, edits);
	}

	function promoteFragmentVaryings(source:String):String
	{
		if (fragmentVaryings.length == 0 || source.indexOf("void main()") == -1) return source;

		usedGlobalMacro = true;

		var globals:String = '';
		var copies:String = '';

		for (varying in fragmentVaryings)
		{
			source = new EReg('\\b${varying.name}\\b', 'g').replace(source, '${varying.name}_g');
			globals += 'OPENFL_G ${varying.type} ${varying.name}_g;\n';
			copies += '${varying.name}_g = ${varying.name};\n';
		}

		source = new EReg('void\\s+main\\s*\\(\\s*\\)\\s*\\{', '').replace(source, 'void main() {\n' + copies);

		return globals + source;
	}

	function promoteFragmentCoord(source:String):String
	{
		if (source.indexOf("gl_FragCoord") == -1 || source.indexOf("void main()") == -1) return source;

		usedGlobalMacro = true;

		source = new EReg('\\bgl_FragCoord\\b', 'g').replace(source, 'openfl_FragCoord_g');
		source = new EReg('void\\s+main\\s*\\(\\s*\\)\\s*\\{', '').replace(source, 'void main() {\nopenfl_FragCoord_g = gl_FragCoord;\n');

		return 'OPENFL_G vec4 openfl_FragCoord_g;\n' + source;
	}

	function buildHeader(source:String):String
	{
		inputs.sort(Reflect.compare);
		outputs.sort(Reflect.compare);

		var header:String = '';

		if (inputs.length > 0) header += '$$input ${inputs.join(", ")}\n';

		if (outputs.length > 0) header += '$$output ${outputs.join(", ")}\n';

		if (source.indexOf("bgfx_shader.sh") == -1) header += '#include "bgfx_shader.sh"\n';

		for (declaration in uniformRemaps)
			header += declaration + "\n";

		if (usedConstMacro) header += '#if BGFX_SHADER_LANGUAGE_HLSL\n#define OPENFL_CONST static const\n#else\n#define OPENFL_CONST const\n#endif\n';

		if (usedGlobalMacro)
			header += '#if BGFX_SHADER_LANGUAGE_HLSL || BGFX_SHADER_LANGUAGE_PSSL || BGFX_SHADER_LANGUAGE_SPIRV || BGFX_SHADER_LANGUAGE_METAL\n#define OPENFL_G static\n#else\n#define OPENFL_G\n#endif\n';

		header += constructorHelperDefs();

		return header;
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

	function isCallable(token:Token):Bool
	{
		return switch (token.type)
		{
			case IDENTIFIER, VEC2, VEC3, VEC4, MAT2, MAT3, MAT4, BVEC2, BVEC3, BVEC4, IVEC2, IVEC3, IVEC4: true;
			default: false;
		}
	}

	function findClosing(tokens:Array<Token>, open:Int):Int
	{
		var depth:Int = 0;

		for (i in open...tokens.length)
		{
			switch (tokens[i].type)
			{
				case LEFT_PAREN:
					depth++;
				case RIGHT_PAREN:
					depth--;
					if (depth == 0) return i;
				default:
			}
		}

		return -1;
	}

	function filterNames(role:DeclarationRole):Array<String>
	{
		final names:Array<String> = [for (name in roles.keys()) if (roles[name] == role) name];
		names.sort(Reflect.compare);

		return names;
	}

	function getAttribSemantic(name:String):Null<String>
	{
		final semantic:Null<String> = ATTRIBUTE_SEMANTICS[name];

		return semantic != null ? semantic : dynamicSemantics[name];
	}

	function getAttribBGFXName(name:String):Null<String>
	{
		final semantic:Null<String> = getAttribSemantic(name);

		return semantic == null ? null : 'a_${semantic.toLowerCase()}';
	}

	function defaultValue(type:String):String
	{
		return switch (type)
		{
			case "vec4": "vec4(0.0, 0.0, 0.0, 1.0)";
			case "vec3": "vec3(0.0, 0.0, 0.0)";
			case "vec2": "vec2(0.0, 0.0)";
			default: "0.0";
		}
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

enum DeclarationRole
{
	Attribute;
	DualAttribute;
	DynamicAttribute;
	Varying;
}

typedef Declaration =
{
	var qualifier:TokenType;
	var type:String;
	var names:Array<String>;
	var start:Int;
	var end:Int;
}

typedef SourceEdit =
{
	var start:Int;
	var end:Int;
	var text:String;
}
