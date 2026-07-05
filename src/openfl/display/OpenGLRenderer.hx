package openfl.display;

import openfl.display3D.Context3D;
#if lime
import lime.graphics.opengl.ext.KHR_debug;
import lime.graphics.WebGLRenderContext;
#end

@:access(lime.graphics.GLRenderContext)
@:access(openfl.display.Context3DRenderer)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.display3D.Context3D)
@:access(openfl.display.Graphics)
@:access(openfl.display.Shader)
@:access(openfl.display.ShaderParameter)
@:allow(openfl.display._internal)
@:allow(openfl.display3D.textures)
@:allow(openfl.display3D)
@:allow(openfl.display)
@:allow(openfl.text)
class OpenGLRenderer implements IContext3DRenderer
{
	@:noCompletion private var parent:Context3DRenderer;

	@:noCompletion public var originBottomLeft(get, never):Bool;

	@:noCompletion private function new(parent:Context3DRenderer)
	{
		this.parent = parent;
		parent.gl = parent.__context.webgl;
		parent.__gl = parent.gl;

		if (Graphics.maxTextureWidth == null)
		{
			Graphics.maxTextureWidth = Graphics.maxTextureHeight = parent.__gl.getParameter(parent.__gl.MAX_TEXTURE_SIZE);
		}

		#if gl_debug
		var ext:KHR_debug = parent.__gl.getExtension("KHR_debug");
		if (ext != null)
		{
			parent.gl.enable(ext.DEBUG_OUTPUT);
			parent.gl.enable(ext.DEBUG_OUTPUT_SYNCHRONOUS);
		}
		#end

		final exts = parent.__gl.getSupportedExtensions();

		if (parent.__context.type == OPENGLES)
		{
			if (Context3DRenderer.__sRGBWriteControlSupported == null)
			{
				Context3DRenderer.__sRGBWriteControlSupported = exts.contains("EXT_sRGB_write_control");
			}

			if (Context3DRenderer.__sRGBWriteControlSupported)
			{
				parent.gl.disable(0x8DB9); // GL_FRAMEBUFFER_SRGB_EXT
			}
		}

		if (Context3DRenderer.__blendMinMaxSupported == null)
		{
			Context3DRenderer.__blendMinMaxSupported = exts.contains("EXT_blend_minmax");
		}
		if (Context3DRenderer.__complexBlendsSupported == null)
		{
			Context3DRenderer.__complexBlendsSupported = exts.contains("KHR_blend_equation_advanced");
		}
		if (Context3DRenderer.__coherentBlendsSupported == null)
		{
			Context3DRenderer.__coherentBlendsSupported = exts.contains("KHR_blend_equation_advanced_coherent");
		}
		if (Context3DRenderer.__standardDerivativesSupported == null)
		{
			Context3DRenderer.__standardDerivativesSupported = exts.contains("OES_standard_derivatives");
		}

		#if lime
		parent.__type = OPENGL;
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
			parent.__context3D.__flushTextures();
			__currentShader.__update();
		}
	}

	@:noCompletion private function __clearBackBufferGutter():Void
	{
		parent.__gl.clearColor(0, 0, 0, 1);
		parent.__gl.clear(parent.__gl.COLOR_BUFFER_BIT);
	}

	public function __flushUseArray(shader:Shader):Void
	{
		return;
	}

	@:noCompletion private function get_originBottomLeft():Bool
	{
		return true;
	}
}
