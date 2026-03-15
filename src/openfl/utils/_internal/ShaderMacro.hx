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
			}

			fragmentDontOverride = nextFragmentDontOverride;
			vertexDontOverride = nextVertexDontOverride;

			parent = parent.superClass != null ? parent.superClass.t.get() : null;
		}

		if (glVertexSource != null || glFragmentSource != null) {
			var shaderDataFields = new Array<Field>();
			var uniqueFields = [];

			processFields(glVertexSource, "attribute", shaderDataFields, pos);
			processFields(glVertexSource, "in", shaderDataFields, pos); // For higher GLSL versions
			processFields(glVertexSource, "uniform", shaderDataFields, pos);
			processFields(glFragmentSource, "uniform", shaderDataFields, pos);

			var position, pragmaSource, regex = ~/#pragma (\w+)/, lastMatch = 0;
			while (regex.matchSub(glVertexSource, lastMatch)) {
				if ((pragmaSource = glVertexPragmas.get(regex.matched(1))) != null) {
					processFields(pragmaSource, "attribute", shaderDataFields, pos);
					processFields(pragmaSource, "in", shaderDataFields, pos); // For higher GLSL versions
					processFields(pragmaSource, "uniform", shaderDataFields, pos);
				}

				position = regex.matchedPos();
				lastMatch = position.pos + position.len;
			}

			lastMatch = 0;
			while (regex.matchSub(glFragmentSource, lastMatch)) {
				if ((pragmaSource = glFragmentPragmas.get(regex.matched(1))) != null) {
					processFields(pragmaSource, "uniform", shaderDataFields, pos);
				}

				position = regex.matchedPos();
				lastMatch = position.pos + position.len;
			}

			if (shaderDataFields.length > 0) {
				var fieldNames = new Map<String, Bool>();

				for (field in shaderDataFields) {
					parent = superClass;

					while (parent != null) {
						for (parentField in parent.fields.get()) {
							if (parentField.name == field.name)
								fieldNames.set(field.name, true);
						}

						parent = parent.superClass != null ? parent.superClass.t.get() : null;
					}

					if (!fieldNames.exists(field.name)) uniqueFields.push(field);
					fieldNames[field.name] = true;
				}
			}

			// #if !display
			for (field in fields) {
				switch (field.name) {
					case "new":
						var block = switch (field.kind) {
							case FFun(f):
								if (f.expr == null) null;

								switch (f.expr.expr) {
									case EBlock(e): e;
									default: null;
								}

							default: null;
						}

						var generateBlock:Array<Expr> = [];
						generateBlock.push(macro __isGenerated = true);
						generateBlock.push(macro __cacheProgramId = $v{localClass.pack.join(".") + "." + localClass.name});
						generateBlock.push(macro __glFragmentPragmas = $v{glFragmentPragmas});
						generateBlock.push(macro __glVertexPragmas = $v{glVertexPragmas});
						generateBlock.push(macro __glVersionRaw = $v{glVersion});
						generateBlock.push(macro __glVertexExtensions = $v{glVertexExtensions});
						generateBlock.push(macro __glFragmentExtensions = $v{glFragmentExtensions});
						if (glVertexSource != null) generateBlock.push(macro __glVertexSourceRaw = $v{glVertexSource});
						if (glFragmentSource != null) generateBlock.push(macro __glFragmentSourceRaw = $v{glFragmentSource});

						block.unshift(macro if (!__isGenerated) $b{generateBlock});
						block.push(macro __init());

					default:
				}
			}

			fields = fields.concat(uniqueFields);
		}

		return fields;
	}

	private static function processFields(source:String, storageType:String, fields:Array<Field>, pos:Position) {
		if (source == null) return;

		var position, name, type, regex, isArray:Bool, fieldMeta:Metadata, fieldType:ComplexType, field:Field;

		if (storageType == "uniform")
		{
			regex = ~/\buniform\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?/gu;
		}
		else if (storageType == "in")
		{
			regex = ~/\bin\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?/gu;
		}
		else
		{
			regex = ~/\battribute\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)(?:\s*)?(?:\[(\w+)\])?/gu;
		}

		var lastMatch = 0, fieldAccess;

		while (regex.matchSub(source, lastMatch))
		{
			type = regex.matched(1);
			name = regex.matched(2);
			isArray = regex.matched(3) != null;

			if (StringTools.startsWith(name, "gl_"))
			{
				continue;
			}

			if (StringTools.startsWith(type, "sampler"))
			{
				fieldType = macro :openfl.display.ShaderInput<openfl.display.BitmapData>;
			}
			else
			{
				var parameterType:openfl.display.ShaderParameterType = switch (type)
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

				switch (parameterType)
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

			fields.push({
				name: "get_" + name,
				meta: fieldMeta,
				access: [APrivate],
				kind: FFun({
					args: [], ret: fieldType,
					expr: macro
					{
						if (__glSourceDirty)
						{
							__init();
						}
						return $i{name};
					}
				}),
				pos: pos
			});

			fields.push({
				name: name,
				meta: fieldMeta,
				access: [fieldAccess],
				kind: FProp("get", "null", fieldType),
				pos: pos
			});

			position = regex.matchedPos();
			lastMatch = position.pos + position.len;
		}
	}
}
#end