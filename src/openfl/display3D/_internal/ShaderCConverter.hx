package openfl.display3D._internal;

using StringTools;

/**
 * Utility class to convert GLSL shaders into BGFX ShaderC shaders.
 */
class ShaderCConverter
{
	private static final ATTRIBUTE_SEMANTICS = [
		"openfl_Position" => "POSITION",
		"openfl_TextureCoord" => "TEXCOORD0",
		"openfl_ColorMultiplier" => "COLOR0",
		"openfl_ColorOffset" => "COLOR1",
		"openfl_Alpha" => "COLOR2",
	];

	private static final ATTRIBUTE_FIELD = [
		"openfl_Alpha" => "x",
		"openfl_ColorMultiplier" => "y",
		"openfl_ColorOffset" => "z",
	];

	public var mappedUniforms:Map<String, String>;
	public var samplersIDs:Map<String, Int>;

	private var mappedDeclarations:Map<String, String>;

	public function new()
	{
		mappedUniforms = new Map<String, String>();
		samplersIDs = new Map<String, Int>();
		mappedDeclarations = new Map<String, String>();
	}

	public function generateVaryingDef(vertexSource:String, fragmentSource:String):String
	{
		final varyings = new Map<String, String>();
		final attributes = new Map<String, String>();

		collectVaryingDecls(vertexSource, true, attributes, varyings);
		collectVaryingDecls(fragmentSource, false, attributes, varyings);

		inline function defaultFor(type:String):String
		{
			return switch (type)
			{
				case "vec4": "vec4(0.0, 0.0, 0.0, 1.0)";
				case "vec3": "vec3(0.0, 0.0, 0.0)";
				case "vec2": "vec2(0.0, 0.0)";
				default: "0.0";
			}
		}

		var results = '';
		final varyNames = [for (k in varyings.keys()) k];
		varyNames.sort(Reflect.compare);

		var texcoordSlot = 0;
		for (name in varyNames)
		{
			final type = varyings.get(name);
			results += '$type $name : TEXCOORD$texcoordSlot = ${defaultFor(type)};\n';
			texcoordSlot++;
		}

		final attrNames = [for (k in attributes.keys()) k];
		attrNames.sort(Reflect.compare);

		if (varyNames.length > 0 && attrNames.length > 0) results += '\n';

		for (name in attrNames)
		{
			final sem = ATTRIBUTE_SEMANTICS[name];
			if (sem == null) continue;

			final type = attributes.get(name);
			results += '$type ${getAttribBGFXName(name)} : $sem;\n';
		}

		return results;
	}

	public function convertShaderSource(source:String, isVertex:Bool):String
	{
		// This mostly works with only few key limitations as of now that have to be fixed manually at the source.
		// When multiplying a matrix by a vector (ex: openfl_Matrix * openfl_Position)
		// It must instead use the mul function exposed by bgfx_shader.sh
		// ex: mul(openfl_Matrix, openfl_Position)
		// (note to self: add a mul function for normal GL so it doesn't shit itself)
		// When creating variables/constants all arguments must filled.
		// ex: mat4 colorMultiplier = mat4 (0.0);
		// must become: mat4 colorMultiplier = mat4 (0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
		// And there are other typical things like more strict typing between int and float & such but we're used to that

		var results = '';
		var samplers = 0;

		final inputs:Array<String> = [];
		final outputs:Array<String> = [];
		final fragVaryings:Array<{name:String, type:String}> = [];

		final whitespaceLnReg = ~/(\r?\n)\s*(\r?\n)/g;
		final whitespaceReg = ~/\s+/g;
		final validUniformReg = ~/\b(vec4|mat3|mat4)\b/i;
		final noRemapReg = ~/\b(sampler2D)\b/i;

		source = whitespaceLnReg.replace(source, "$1");
		source = source.split("\r\n").join("\n");

		final mainFunReg = ~/void\s+main\s*\(\s*void\s*\)/g;
		source = mainFunReg.replace(source, "void main()");

		if (isVertex)
		{
			final attrReg = ~/attribute\s+(\w+)\s+(\w+)\s*;/g;
			source = attrReg.map(source, function(r):String
			{
				final name = r.matched(2);
				if (ATTRIBUTE_SEMANTICS.exists(name)) return r.matched(0);
				return 'uniform ${r.matched(1)} ${name};';
			});
		}

		var dualEmitted = false;

		for (line in source.split('\n'))
		{
			final trimmed = line.trim();
			final words = whitespaceReg.split(trimmed);

			if (words.length >= 3)
			{
				final qualifier = words[0];
				if (qualifier == "attribute" || qualifier == "varying" || qualifier == "in" || qualifier == "out")
				{
					final name = words[2].substr(0, words[2].length - 1);
					final role = mappedDeclarations.get(name);
					if (role != null)
					{
						if (role == "attribute")
						{
							final bgfxName = getAttribBGFXName(name);
							inputs.push(bgfxName);
							results += '#define $name $bgfxName\n';
						}
						else if (role == "dualAttribute")
						{
							final bgfxName = getAttribBGFXName(name);
							inputs.push(bgfxName);

							if (!dualEmitted)
							{
								results += 'uniform vec4 openfl_UseArray;\n';
								dualEmitted = true;
							}

							final comp = ATTRIBUTE_FIELD[name];
							final uniformExpr = words[1] == "float" ? '${name}_internal.x' : '${name}_internal';
							results += 'uniform vec4 ${name}_internal;\n';
							results += '#define $name (openfl_UseArray.$comp != 0.0 ? $bgfxName : $uniformExpr)\n';
						}
						else if (isVertex) outputs.push(name);
						else
						{
							inputs.push(name);
							if (role == "varying") fragVaryings.push({name: name, type: words[1]});
						}
						continue;
					}
				}
			}

			if (!trimmed.startsWith("uniform"))
			{
				results += line + '\n';
				continue;
			}

			final uniformType = words[1];
			final uniformName = words[2].substr(0, words[2].length - 1);
			final internalName = '${uniformName}_internal';

			if (validUniformReg.match(uniformType))
			{
				results += line + '\n';
				continue;
			}

			if (!noRemapReg.match(uniformType))
			{
				results += '// remap to $uniformType\n';
				results += 'uniform vec4 $internalName;\n';
			}

			switch (uniformType)
			{
				case "bool":
					results += '#define $uniformName ($internalName.x != 0.0)\n';
					mappedUniforms.set(uniformName, uniformType);
				case "bvec2":
					results += '#define $uniformName bvec2($internalName.x != 0.0, $internalName.y != 0.0)\n';
					mappedUniforms.set(uniformName, uniformType);
				case "bvec3":
					results += '#define $uniformName bvec3($internalName.x != 0.0, $internalName.y != 0.0, $internalName.z != 0.0)\n';
					mappedUniforms.set(uniformName, uniformType);
				case "bvec4":
					results += '#define $uniformName bvec4($internalName.x != 0.0, $internalName.y != 0.0, $internalName.z != 0.0, $internalName.w != 0.0)\n';
					mappedUniforms.set(uniformName, uniformType);
				case "vec2":
					results += '#define $uniformName $internalName.xy\n';
					mappedUniforms.set(uniformName, uniformType);
				case "vec3":
					results += '#define $uniformName $internalName.xyz\n';
					mappedUniforms.set(uniformName, uniformType);
				case "float":
					results += '#define $uniformName $internalName.x\n';
					mappedUniforms.set(uniformName, uniformType);
				case "int":
					results += '#define $uniformName int($internalName.x)\n';
					mappedUniforms.set(uniformName, uniformType);
				case "ivec2":
					results += '#define $uniformName ivec2(int($internalName.x), int($internalName.y))\n';
					mappedUniforms.set(uniformName, uniformType);
				case "ivec3":
					results += '#define $uniformName ivec3(int($internalName.x), int($internalName.y), int($internalName.z))\n';
					mappedUniforms.set(uniformName, uniformType);
				case "ivec4":
					results += '#define $uniformName ivec4(int($internalName.x), int($internalName.y), int($internalName.z), int($internalName.w))\n';
					mappedUniforms.set(uniformName, uniformType);
				case "mat2":
					results += '#define $uniformName mat2($internalName.x, $internalName.y, $internalName.z, $internalName.w)\n';
					mappedUniforms.set(uniformName, uniformType);
				case "sampler2D":
					results += 'SAMPLER2D($uniformName, $samplers);\n';
					samplersIDs.set(uniformName, samplers);
					samplers++;
				default:
					results += line + '\n';
			}
		}

		inputs.sort(Reflect.compare);
		outputs.sort(Reflect.compare);

		var header = '';
		if (inputs.length > 0) header += "$input " + inputs.join(', ') + '\n';
		if (outputs.length > 0) header += "$output " + outputs.join(', ') + '\n';

		if (results.indexOf("bgfx_shader.sh") == -1) header += '#include "bgfx_shader.sh"\n';

		if (!isVertex && fragVaryings.length > 0 && results.indexOf("void main()") != -1)
		{
			var globals = '#if BGFX_SHADER_LANGUAGE_HLSL || BGFX_SHADER_LANGUAGE_PSSL || BGFX_SHADER_LANGUAGE_SPIRV || BGFX_SHADER_LANGUAGE_METAL\n#define _OFL_G static\n#else\n#define _OFL_G\n#endif\n';
			var copies = '';
			for (v in fragVaryings)
			{
				results = new EReg('\\b${v.name}\\b', 'g').replace(results, '${v.name}_g');
				globals += '_OFL_G ${v.type} ${v.name}_g;\n';
				copies += '${v.name}_g = ${v.name};\n';
			}
			results = new EReg('void\\s+main\\s*\\(\\s*\\)\\s*\\{', '').replace(results, 'void main() {\n' + copies);
			results = globals + results;
		}

		return header + results;
	}

	public function dispose()
	{
		mappedUniforms.clear();
		mappedUniforms = null;

		samplersIDs.clear();
		samplersIDs = null;

		mappedDeclarations.clear();
		mappedDeclarations = null;
	}

	private function collectVaryingDecls(source:String, isVertex:Bool, attributes:Map<String, String>, varyings:Map<String, String>):Void
	{
		final whitespaceReg = ~/\s+/g;

		for (line in source.split('\n'))
		{
			final trimmed = line.trim();
			final words = whitespaceReg.split(trimmed);
			if (words.length < 3) continue;

			final qualifier = words[0];
			final type = words[1];
			final name = words[2].substr(0, words[2].length - 1);

			switch (type)
			{
				case "float", "vec2", "vec3", "vec4":
				default:
					continue;
			}

			if (isVertex)
			{
				if (qualifier == "attribute" || qualifier == "in")
				{
					final sem = ATTRIBUTE_SEMANTICS[name];
					if (sem != null)
					{
						attributes.set(name, type);
						mappedDeclarations.set(name, sem.startsWith("COLOR") ? "dualAttribute" : "attribute");
					}
				}
				else if (qualifier == "varying" || qualifier == "out")
				{
					varyings.set(name, type);
					mappedDeclarations.set(name, "varying");
				}
			}
			else
			{
				if (qualifier == "varying" || qualifier == "in")
				{
					varyings.set(name, type);
					mappedDeclarations.set(name, "varying");
				}
			}
		}
	}

	private static function getAttribBGFXName(name:String):String
	{
		final sem = ATTRIBUTE_SEMANTICS[name];
		return sem == null ? null : "a_" + sem.toLowerCase();
	}

	public static function getAttribIndex(name:String):Int
	{
		return switch (ATTRIBUTE_SEMANTICS[name])
		{
			case "POSITION": 0;
			case "TEXCOORD0": 10;
			case "COLOR0": 4;
			case "COLOR1": 5;
			case "COLOR2": 6;
			default: -1;
		}
	}
}
