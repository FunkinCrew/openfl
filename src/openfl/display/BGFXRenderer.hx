package openfl.display;

import openfl.display3D.Context3D;
import openfl.utils._internal.Float32Array;

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(openfl.display.Context3DRenderer)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.Program3D)
@:access(openfl.display.Graphics)
@:access(openfl.display.Shader)
@:access(openfl.display.ShaderParameter)
@:allow(openfl.display._internal)
@:allow(openfl.display3D.textures)
@:allow(openfl.display3D)
@:allow(openfl.display)
@:allow(openfl.text)
class BGFXRenderer implements IContext3DRenderer
{
	@:noCompletion private var parent:Context3DRenderer;

	@:noCompletion public var originBottomLeft(get, never):Bool;

	@:noCompletion private var __useArrayData:Float32Array;

	@:noCompletion private function new(parent:Context3DRenderer)
	{
		this.parent = parent;
		parent.gl = null;
		parent.__gl = null;

		if (Graphics.maxTextureWidth == null)
		{
			// TODO: query bgfx caps instead of hardcoding
			Graphics.maxTextureWidth = Graphics.maxTextureHeight = 4096;
		}

		if (Context3DRenderer.__sRGBWriteControlSupported == null) Context3DRenderer.__sRGBWriteControlSupported = false;
		if (Context3DRenderer.__blendMinMaxSupported == null) Context3DRenderer.__blendMinMaxSupported = false;
		if (Context3DRenderer.__complexBlendsSupported == null) Context3DRenderer.__complexBlendsSupported = false;
		if (Context3DRenderer.__coherentBlendsSupported == null) Context3DRenderer.__coherentBlendsSupported = false;
		if (Context3DRenderer.__standardDerivativesSupported == null) Context3DRenderer.__standardDerivativesSupported = false;

		#if lime
		parent.__type = BGFX;
		#end
	}

	public function updateShader():Void
	{
		var __currentShader = parent.__currentShader;
		if (__currentShader != null)
		{
			if (__currentShader.__position != null) __currentShader.__position.__useArray = true;
			if (__currentShader.__textureCoord != null) __currentShader.__textureCoord.__useArray = true;
			parent.__context3D.setProgram(__currentShader.program);
			parent.__context3D.__flushProgram();
			__currentShader.__update();
			parent.__context3D.__flushTextures();
			__flushUseArray(__currentShader);
		}
	}

	@:noCompletion public function __flushUseArray(shader:Shader):Void
	{
		var program = shader.program;
		if (program == null || program.__bgfxUniforms == null) return;

		var u = program.__bgfxUniforms.get("openfl_UseArray");
		if (u == null) return;

		if (__useArrayData == null) __useArrayData = new Float32Array(4);
		__useArrayData[0] = (shader.__alpha != null && shader.__alpha.__useArray) ? 1.0 : 0.0;
		__useArrayData[1] = (shader.__colorMultiplier != null && shader.__colorMultiplier.__useArray) ? 1.0 : 0.0;
		__useArrayData[2] = (shader.__colorOffset != null && shader.__colorOffset.__useArray) ? 1.0 : 0.0;
		__useArrayData[3] = 0.0;

		parent.__context3D.bgfx.setUniform(u.uniform, __useArrayData, u.info.num);
	}

	@:noCompletion private function __clearBackBufferGutter():Void
	{
		return;
	}

	@:noCompletion private function get_originBottomLeft():Bool
	{
		return parent.__context3D.bgfx.getCaps().originBottomLeft;
	}
}
