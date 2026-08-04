package openfl.utils._internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;
using haxe.macro.Tools;
using haxe.macro.TypeTools;

@SuppressWarnings("checkstyle:FieldDocComment")
class ShaderMacro
{
	//#if 0
	//private static var __suppressWarning:Array<Class<Dynamic>> = [Expr];
	//#end

	public static function build():Array<Field> {
		var fields = Context.getBuildFields();

		var glFragmentPragmas:Map<String, String> = [], glVertexPragmas:Map<String, String> = [];
		function addPragma(pragmas:Map<String, String>, key:String, value:String) {
			if (pragmas.exists(key)) pragmas.set(key, value + '\n' + pragmas.get(key));
			else pragmas.set(key, value);
		}

		var glFragmentExtensions:Map<String, String> = [], glVertexExtensions:Map<String, String> = [];
		function addExtension(extensions:Map<String, String>, meta:MetadataEntry) {
			var name = meta.params[0].getValue();
			if (!extensions.exists(name)) {
				var v = meta.params[1].getValue();
				if (v is Bool) extensions.set(name, v == true ? "require" : "disable");
				else if (v is String) extensions.set(name, cast v);
			}
		}

		var glFragmentSource:String = null, glVertexSource:String = null, glVersion:String = null;
		var nextFragmentDontOverride = false, nextVertexDontOverride = false;
		var prefixFragment = "glFragment", prefixVertex = "glVertex", name:String;
		var fieldNames = new Map<String, Bool>();

		for (field in fields) {
			for (meta in field.meta) {
				switch (name = meta.name.charAt(0) == ":" ? meta.name.substr(1) : meta.name) {
					case "glFragmentDontOverride": nextFragmentDontOverride = true;
					case "glVertexDontOverride": nextVertexDontOverride = true;
					case "glVersion":
						glVersion = meta.params[0].getValue();

					case "glFragmentExtension":
						addExtension(glFragmentExtensions, meta);

					case "glVertexExtension":
						addExtension(glVertexExtensions, meta);

					case "glFragmentSource":
						glFragmentSource = meta.params[0].getValue();

					case "glVertexSource":
						glVertexSource = meta.params[0].getValue();

					case "glExtension":
						addExtension(glFragmentExtensions, meta);
						addExtension(glVertexExtensions, meta);

					case "glFragmentPragma":
						addPragma(glFragmentPragmas, meta.params[0].getValue(), meta.params[1].getValue());

					case "glVertexPragma":
						addPragma(glVertexPragmas, meta.params[0].getValue(), meta.params[1].getValue());

					default:
						if (name.substr(0, prefixFragment.length) == prefixFragment)
							addPragma(glFragmentPragmas, name.substr(prefixFragment.length).toLowerCase(), meta.params[0].getValue());

						if (name.substr(0, prefixVertex.length) == prefixVertex)
							addPragma(glVertexPragmas, name.substr(prefixVertex.length).toLowerCase(), meta.params[0].getValue());
				}
			}

			fieldNames.set(field.name, true);
		}

		var fragmentDontOverride = nextFragmentDontOverride, vertexDontOverride = nextVertexDontOverride;

		var pos = Context.currentPos(), localClass = Context.getLocalClass().get();
		var superClass = localClass.superClass != null ? localClass.superClass.t.get() : null;
		var parent = superClass, parentFields;

		while (parent != null) {
			parentFields = [parent.constructor.get()].concat(parent.fields.get());
			for (field in parentFields) {
				for (meta in field.meta.get()) {
					switch (name = meta.name.charAt(0) == ":" ? meta.name.substr(1) : meta.name) {
						case "glFragmentDontOverride": nextFragmentDontOverride = true;
						case "glVertexDontOverride": nextVertexDontOverride = true;
						case "glVersion":
							if (glVersion == null) glVersion = meta.params[0].getValue();

						case "glFragmentExtension":
							if (!fragmentDontOverride) addExtension(glFragmentExtensions, meta);

						case "glVertexExtension":
							if (!vertexDontOverride) addExtension(glVertexExtensions, meta);

						case "glExtension":
							if (!fragmentDontOverride) addExtension(glFragmentExtensions, meta);
							if (!vertexDontOverride) addExtension(glVertexExtensions, meta);

						case "glFragmentSource":
							if (glFragmentSource == null) glFragmentSource = meta.params[0].getValue();

						case "glVertexSource":
							if (glVertexSource == null) glVertexSource = meta.params[0].getValue();

						case "glFragmentPragma":
							if (!fragmentDontOverride) addPragma(glFragmentPragmas, meta.params[0].getValue(), meta.params[1].getValue());

						case "glVertexPragma":
							if (!vertexDontOverride) addPragma(glVertexPragmas, meta.params[0].getValue(), meta.params[1].getValue());

						default:
							if (!fragmentDontOverride && name.substr(0, prefixFragment.length) == prefixFragment)
								addPragma(glFragmentPragmas, name.substr(prefixFragment.length).toLowerCase(), meta.params[0].getValue());

							if (!vertexDontOverride && name.substr(0, prefixVertex.length) == prefixVertex)
								addPragma(glVertexPragmas, name.substr(prefixVertex.length).toLowerCase(), meta.params[0].getValue());
					}
				}

				fieldNames.set(field.name, true);
			}

			fragmentDontOverride = nextFragmentDontOverride;
			vertexDontOverride = nextVertexDontOverride;

			parent = parent.superClass != null ? parent.superClass.t.get() : null;
		}

		if (glVertexSource != null || glFragmentSource != null) {
			var paramBlock:Array<Expr> = [];

			processFields(glVertexSource, "attribute", fieldNames, fields, paramBlock, pos);
			processFields(glVertexSource, "in", fieldNames, fields, paramBlock, pos); // For higher GLSL versions
			processFields(glVertexSource, "uniform", fieldNames, fields, paramBlock, pos);
			processFields(glFragmentSource, "uniform", fieldNames, fields, paramBlock, pos);

			var position, pragmaSource, regex = ~/(?:^|\s)#pragma\s+(?|"([^"]+)"|'([^']+)'|([^\s]+))/g, lastMatch = 0;
			while (regex.matchSub(glVertexSource, lastMatch)) {
				if ((pragmaSource = glVertexPragmas.get(regex.matched(1))) != null) {
					processFields(pragmaSource, "attribute", fieldNames, fields, paramBlock, pos);
					processFields(pragmaSource, "in", fieldNames, fields, paramBlock, pos); // For higher GLSL versions
					processFields(pragmaSource, "uniform", fieldNames, fields, paramBlock, pos);
				}

				position = regex.matchedPos();
				lastMatch = position.pos + position.len;
			}

			lastMatch = 0;
			while (regex.matchSub(glFragmentSource, lastMatch)) {
				if ((pragmaSource = glFragmentPragmas.get(regex.matched(1))) != null) {
					processFields(pragmaSource, "uniform", fieldNames, fields, paramBlock, pos);
				}

				position = regex.matchedPos();
				lastMatch = position.pos + position.len;
			}

			var generateBlock:Array<Expr> = [macro __isGenerated = true];

			generateBlock.push(macro __cacheProgramId = $v{localClass.pack.join(".") + "." + localClass.name});
			generateBlock.push(macro __glFragmentPragmas = $v{glFragmentPragmas});
			generateBlock.push(macro __glVertexPragmas = $v{glVertexPragmas});
			generateBlock.push(macro __glVersionRaw = $v{glVersion});
			generateBlock.push(macro __glVertexExtensions = $v{glVertexExtensions});
			generateBlock.push(macro __glFragmentExtensions = $v{glFragmentExtensions});
			if (glVertexSource != null) generateBlock.push(macro __glVertexSourceRaw = $v{glVertexSource});
			if (glFragmentSource != null) generateBlock.push(macro __glFragmentSourceRaw = $v{glFragmentSource});

			var newBlock:Array<Expr>;
			for (field in fields) {
				switch (field.name) {
					case "new":
						newBlock = switch (field.kind) {
							case FFun(f):
								if (f.expr == null) null;

								switch (f.expr.expr) {
									case EBlock(e): e;
									default: null;
								}

							default: null;
						}

						break;
					default:
				}
			}

			if (newBlock == null) {
				fields.push({
					name: "new",
					access: [],
					kind: FFun({args: [], expr: {pos: pos, expr: EBlock(newBlock = [macro super()])}}),
					pos: pos
				});
			}

			for (e in paramBlock) newBlock.unshift(e);
			newBlock.unshift(macro if (__data == null) __data = cast new openfl.display.ShaderData(null));
			newBlock.unshift(macro if (!__isGenerated) $b{generateBlock});
		}

		return fields;
	}

	private static function processFields(source:String, storageType:String, fieldNames:Map<String, Bool>, fields:Array<Field>,
			paramBlock:Array<Expr>, pos:Position)
	{
		if (source == null) return;

		var isUniform = storageType == "uniform";
		var regex:EReg = switch (storageType)
		{
			case "uniform": ~/\buniform\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?\s*(?:=)?\s*(.+?(?=;))?/gu;
			case "in": ~/\bin\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?/gu;
			case "attribute": ~/\battribute\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?/gu;
			default: throw "Unknown storageType " + storageType;
		}

		var name, type:openfl.display.ShaderParameterType, isSampler:Bool, arrayLength:Null<Int>, size:Int, defaultAssign:Null<String>;
		var field:Field, fieldAccess:Access, fieldMeta:Metadata, fieldType:ComplexType;
		var lastMatch = 0, position;

		while (regex.matchSub(source, lastMatch))
		{
			name = regex.matched(2);
			if (fieldNames.exists(name) || StringTools.startsWith(name, "gl_"))
			{
				position = regex.matchedPos();
				lastMatch = position.pos + position.len;
				continue;
			}

			if (regex.matched(3) == null) arrayLength = 0;
			else if ((arrayLength = Std.parseInt(regex.matched(3))) == null) arrayLength = 1;

			if (StringTools.startsWith(regex.matched(1), "sampler"))
			{
				isSampler = true;
				type = null;
				fieldType = macro :openfl.display.ShaderInput<openfl.display.BitmapData>;
			}
			else
			{
				isSampler = false;
				type = switch (regex.matched(1))
				{
					case "bool": arrayLength != 0 ? BOOLV : BOOL;
					case "double", "float": arrayLength != 0 ? FLOATV : FLOAT;
					case "int", "uint": arrayLength != 0 ? INTV : INT;
					case "bvec2": arrayLength != 0 ? BOOL2V : BOOL2;
					case "bvec3": arrayLength != 0 ? BOOL3V : BOOL3;
					case "bvec4": arrayLength != 0 ? BOOL4V : BOOL4;
					case "ivec2", "uvec2": arrayLength != 0 ? INT2V : INT2;
					case "ivec3", "uvec3": arrayLength != 0 ? INT3V : INT3;
					case "ivec4", "uvec4": arrayLength != 0 ? INT4V : INT4;
					case "vec2", "dvec2": arrayLength != 0 ? FLOAT2V : FLOAT2;
					case "vec3", "dvec3": arrayLength != 0 ? FLOAT3V : FLOAT3;
					case "vec4", "dvec4": arrayLength != 0 ? FLOAT4V : FLOAT4;
					case "mat2", "mat2x2": arrayLength != 0 ? MATRIX2X2V : MATRIX2X2;
					case "mat2x3": arrayLength != 0 ? MATRIX2X3V : MATRIX2X3;
					case "mat2x4": arrayLength != 0 ? MATRIX2X4V : MATRIX2X4;
					case "mat3x2": arrayLength != 0 ? MATRIX3X2V : MATRIX3X2;
					case "mat3", "mat3x3": arrayLength != 0 ? MATRIX3X3V : MATRIX3X3;
					case "mat3x4": arrayLength != 0 ? MATRIX3X4V : MATRIX3X4;
					case "mat4x2": arrayLength != 0 ? MATRIX4X2V : MATRIX4X2;
					case "mat4x3": arrayLength != 0 ? MATRIX4X3V : MATRIX4X3;
					case "mat4", "mat4x4": arrayLength != 0 ? MATRIX4X4V : MATRIX4X4;
					default: null;
				}

				switch (type)
				{
					case BOOL, BOOL2, BOOL3, BOOL4, BOOLV, BOOL2V, BOOL3V, BOOL4V:
						fieldType = macro :openfl.display.ShaderParameter<Bool>;

					case INT, INT2, INT3, INT4, INTV, INT2V, INT3V, INT4V:
						fieldType = macro :openfl.display.ShaderParameter<Int>;

					default:
						fieldType = macro :openfl.display.ShaderParameter<Float>;
				}
			}

			if (StringTools.startsWith(name, "openfl_"))
			{
				fieldMeta = [
					{name: ":keep", pos: pos},
					{name: ":dox", params: [macro hide], pos: pos},
					{name: ":noCompletion", pos: pos},
					{name: ":allow", params: [macro openfl.display._internal], pos: pos}
				];
				fieldAccess = APrivate;
			}
			else
			{
				fieldMeta = [{name: ":keep", pos: pos}];
				fieldAccess = APublic;
			}

			field = {
				name: name,
				meta: fieldMeta,
				access: [fieldAccess],
				kind: FVar(fieldType),
				pos: pos
			};

			fields.push(field);
			fieldNames.set(name, true);

			size = arrayLength == 0 ? 1 : arrayLength;
			defaultAssign = isUniform ? regex.matched(4) : null;
			if (defaultAssign != null) {
				paramBlock.push(macro __registerParameter($v{name}, cast $v{type}, $v{isSampler}, $v{size}, null, $v{isUniform},
					__getParameterDefault($v{defaultAssign}, cast $v{type}, $v{isSampler})));
			}
			else {
				paramBlock.push(macro __registerParameter($v{name}, cast $v{type}, $v{isSampler}, $v{size}, null, $v{isUniform}, null));
			}

			position = regex.matchedPos();
			lastMatch = position.pos + position.len;
		}
	}
}
#end